import { Inject, Injectable } from '@nestjs/common';
import { ApprovalDecision, AssignmentStatus, CompanyMembership, EventSource, Prisma, Role, Task, TaskStatus, WorkEventType } from '@prisma/client';
import { randomUUID } from 'crypto';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { AppException, ErrorCode, badRequest, conflict, forbidden, notFound } from '../common/errors';
import { paginated } from '../common/dto/pagination.dto';
import { sha256 } from '../common/utils/crypto';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';
import { detectFileType, extensionMatches, sanitizeFilename } from '../evidence/file-validation';
import { CreateTaskDto, EvidenceFieldsDto, ListTasksQuery, ReviewTaskDto, SubmitTaskDto } from './dto/tasks.dto';

const WORKABLE: TaskStatus[] = [TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS, TaskStatus.CHANGES_REQUESTED];
const MAX_EVIDENCE_PER_TASK = 10;

const taskInclude = {
  assignee: { select: { id: true, fullName: true, phone: true } },
  site: { select: { id: true, name: true } },
  _count: { select: { evidence: { where: { deletedAt: null } } } },
} satisfies Prisma.TaskInclude;

export interface UploadedFileLike {
  buffer: Buffer;
  size: number;
  originalname?: string;
  mimetype?: string;
}

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly storage: StorageService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private taskEvent(tx: Prisma.TransactionClient, task: Task, actorUserId: string, type: WorkEventType, extra: Partial<Prisma.WorkEventUncheckedCreateInput> = {}) {
    return tx.workEvent.create({
      data: {
        companyId: task.companyId,
        siteId: task.siteId,
        subjectUserId: task.assigneeId,
        actorUserId,
        type,
        source: actorUserId === task.assigneeId ? EventSource.MOBILE_APP : EventSource.FOREMAN_APP,
        occurredAt: new Date(),
        entityType: 'Task',
        entityId: task.id,
        ...extra,
      },
    });
  }

  // ───── supervisor ─────

  async create(actor: CompanyMembership, dto: CreateTaskDto, meta: RequestMeta) {
    const site = await this.access.assertSiteAccess(actor, dto.siteId);
    const assigned = await this.prisma.siteAssignment.findFirst({
      where: { siteId: site.id, userId: dto.assigneeId, role: Role.WORKER, status: AssignmentStatus.ACTIVE },
    });
    if (!assigned) throw badRequest(ErrorCode.NOT_ASSIGNED_TO_SITE, 'The worker is not assigned to this site');
    if (dto.assigneeId === actor.userId) throw forbidden(ErrorCode.CANNOT_REVIEW_OWN_WORK, 'You cannot assign a task to yourself');

    const task = await this.prisma.$transaction(async (tx) => {
      const t = await tx.task.create({
        data: {
          companyId: actor.companyId,
          siteId: site.id,
          assigneeId: dto.assigneeId,
          createdById: actor.userId,
          title: dto.title,
          description: dto.description,
          quantity: dto.quantity,
          unit: dto.unit,
          dueDate: dto.dueDate ? new Date(`${dto.dueDate.slice(0, 10)}T00:00:00.000Z`) : undefined,
        },
      });
      await this.taskEvent(tx, t, actor.userId, WorkEventType.TASK_ASSIGNED);
      await this.audit.log({ action: AuditAction.TASK_CREATED, entityType: 'Task', entityId: t.id, companyId: actor.companyId, actorUserId: actor.userId, ip: meta.ip }, tx);
      return t;
    });
    await this.notifications.notify([dto.assigneeId], {
      type: 'TASK_ASSIGNED',
      category: 'tasks',
      companyId: actor.companyId,
      title: 'Yangi vazifa',
      body: `${task.title}${dto.quantity ? ` — ${dto.quantity} ${dto.unit ?? ''}` : ''} (${site.name})`,
      data: { taskId: task.id },
    });
    return task;
  }

  async list(actor: CompanyMembership, q: ListTasksQuery) {
    const scope = await this.access.siteScope(actor);
    if (q.siteId) await this.access.assertSiteAccess(actor, q.siteId);
    const where: Prisma.TaskWhereInput = {
      companyId: actor.companyId,
      ...scope,
      ...(q.siteId ? { siteId: q.siteId } : {}),
      ...(q.assigneeId ? { assigneeId: q.assigneeId } : {}),
      ...(q.status?.length ? { status: { in: q.status } } : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.task.findMany({ where, include: taskInclude, orderBy: [{ updatedAt: 'desc' }], skip: q.skip, take: q.limit }),
      this.prisma.task.count({ where }),
    ]);
    return paginated(items, total, q);
  }

  async getForSupervisor(actor: CompanyMembership, id: string) {
    const task = await this.prisma.task.findFirst({ where: { id, companyId: actor.companyId } });
    if (!task) throw notFound('Task');
    await this.access.assertSiteAccess(actor, task.siteId);
    return this.detail(id);
  }

  private async detail(id: string) {
    const task = await this.prisma.task.findUniqueOrThrow({
      where: { id },
      include: {
        ...taskInclude,
        approvals: { orderBy: { createdAt: 'asc' } },
        evidence: {
          where: { deletedAt: null },
          orderBy: { createdAt: 'asc' },
          select: { id: true, kind: true, mimeType: true, sizeBytes: true, comment: true, capturedAt: true, createdAt: true, originalName: true },
        },
      },
    });
    return task;
  }

  async review(actor: CompanyMembership, id: string, dto: ReviewTaskDto, meta: RequestMeta) {
    const task = await this.prisma.task.findFirst({ where: { id, companyId: actor.companyId } });
    if (!task) throw notFound('Task');
    await this.access.assertSiteAccess(actor, task.siteId);
    if (task.assigneeId === actor.userId) throw forbidden(ErrorCode.CANNOT_REVIEW_OWN_WORK, 'You cannot review your own task');
    if (task.status !== TaskStatus.SUBMITTED) throw conflict(ErrorCode.TASK_INVALID_STATE, 'Only submitted tasks can be reviewed');
    if (dto.decision !== ApprovalDecision.APPROVED && !dto.comment) {
      throw badRequest(ErrorCode.VALIDATION_FAILED, 'A comment is required when rejecting or requesting changes');
    }
    const next: Record<ApprovalDecision, TaskStatus> = {
      APPROVED: TaskStatus.APPROVED,
      REJECTED: TaskStatus.REJECTED,
      CHANGES_REQUESTED: TaskStatus.CHANGES_REQUESTED,
    };
    const eventType: Record<ApprovalDecision, WorkEventType> = {
      APPROVED: WorkEventType.TASK_APPROVED,
      REJECTED: WorkEventType.TASK_REJECTED,
      CHANGES_REQUESTED: WorkEventType.TASK_CHANGES_REQUESTED,
    };
    const auditAction = {
      APPROVED: AuditAction.TASK_APPROVED,
      REJECTED: AuditAction.TASK_REJECTED,
      CHANGES_REQUESTED: AuditAction.TASK_CHANGES_REQUESTED,
    }[dto.decision];

    await this.prisma.$transaction(async (tx) => {
      const r = await tx.task.updateMany({
        where: { id, status: TaskStatus.SUBMITTED },
        data: { status: next[dto.decision], reviewedAt: new Date(), reviewedById: actor.userId },
      });
      if (r.count === 0) throw conflict(ErrorCode.TASK_INVALID_STATE, 'Task was changed by someone else');
      await tx.taskApproval.create({ data: { taskId: id, reviewerId: actor.userId, decision: dto.decision, comment: dto.comment } });
      await this.taskEvent(tx, task, actor.userId, eventType[dto.decision], { reason: dto.comment ?? null });
      await this.audit.log(
        { action: auditAction, entityType: 'Task', entityId: id, companyId: actor.companyId, actorUserId: actor.userId, ip: meta.ip, metadata: { comment: dto.comment ?? null } },
        tx,
      );
    });
    const titles = { APPROVED: 'Vazifa tasdiqlandi', REJECTED: 'Vazifa rad etildi', CHANGES_REQUESTED: "Vazifani to'g'rilash kerak" };
    await this.notifications.notify([task.assigneeId], {
      type: `TASK_${dto.decision}`,
      category: 'tasks',
      companyId: task.companyId,
      title: titles[dto.decision],
      body: dto.comment ? `${task.title}: ${dto.comment}` : task.title,
      data: { taskId: id },
    });
    return this.detail(id);
  }

  async cancel(actor: CompanyMembership, id: string, meta: RequestMeta) {
    const task = await this.prisma.task.findFirst({ where: { id, companyId: actor.companyId } });
    if (!task) throw notFound('Task');
    await this.access.assertSiteAccess(actor, task.siteId);
    if (task.status === TaskStatus.APPROVED || task.status === TaskStatus.CANCELLED) throw conflict(ErrorCode.TASK_INVALID_STATE, `Task is ${task.status}`);
    await this.prisma.task.update({ where: { id }, data: { status: TaskStatus.CANCELLED } });
    await this.audit.log({ action: AuditAction.TASK_CANCELLED, entityType: 'Task', entityId: id, companyId: actor.companyId, actorUserId: actor.userId, ip: meta.ip });
  }

  // ───── worker ─────

  async myTasks(userId: string, q: ListTasksQuery) {
    const where: Prisma.TaskWhereInput = { assigneeId: userId, ...(q.status?.length ? { status: { in: q.status } } : {}) };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.task.findMany({
        where,
        include: { ...taskInclude, company: { select: { id: true, name: true } } },
        orderBy: [{ updatedAt: 'desc' }],
        skip: q.skip,
        take: q.limit,
      }),
      this.prisma.task.count({ where }),
    ]);
    return paginated(items, total, q);
  }

  private async ownTask(userId: string, id: string) {
    const task = await this.prisma.task.findFirst({ where: { id, assigneeId: userId } });
    if (!task) throw notFound('Task');
    return task;
  }

  async myTask(userId: string, id: string) {
    await this.ownTask(userId, id);
    return this.detail(id);
  }

  async start(userId: string, id: string) {
    const task = await this.ownTask(userId, id);
    if (task.status !== TaskStatus.ASSIGNED && task.status !== TaskStatus.CHANGES_REQUESTED) {
      throw conflict(ErrorCode.TASK_INVALID_STATE, `Task is ${task.status}`);
    }
    await this.prisma.$transaction(async (tx) => {
      await tx.task.update({ where: { id }, data: { status: TaskStatus.IN_PROGRESS, startedAt: task.startedAt ?? new Date() } });
      await this.taskEvent(tx, task, userId, WorkEventType.TASK_STARTED);
    });
    return this.detail(id);
  }

  async submit(userId: string, id: string, dto: SubmitTaskDto) {
    const task = await this.ownTask(userId, id);
    if (!WORKABLE.includes(task.status)) throw conflict(ErrorCode.TASK_INVALID_STATE, `Task is ${task.status}`);
    await this.prisma.$transaction(async (tx) => {
      await tx.task.update({
        where: { id },
        data: {
          status: TaskStatus.SUBMITTED,
          submittedAt: new Date(),
          submissionNote: dto.note ?? null,
          completedQuantity: dto.completedQuantity ?? task.quantity,
          startedAt: task.startedAt ?? new Date(),
        },
      });
      await this.taskEvent(tx, task, userId, WorkEventType.TASK_SUBMITTED, { reason: dto.note ?? null, metadata: { completedQuantity: dto.completedQuantity ?? null } });
    });
    const supervisors = await this.notifications.supervisorsOf(task.companyId, task.siteId);
    const worker = await this.prisma.user.findUnique({ where: { id: userId }, select: { fullName: true } });
    await this.notifications.notify(supervisors, {
      type: 'TASK_SUBMITTED',
      category: 'tasks',
      companyId: task.companyId,
      title: 'Vazifa tekshiruvga yuborildi',
      body: `${worker?.fullName ?? 'Ishchi'}: ${task.title}`,
      data: { taskId: id },
    });
    return this.detail(id);
  }

  async addEvidence(userId: string, taskId: string, file: UploadedFileLike | undefined, fields: EvidenceFieldsDto) {
    const task = await this.ownTask(userId, taskId);
    if (!WORKABLE.includes(task.status)) throw conflict(ErrorCode.TASK_INVALID_STATE, 'Evidence can only be added to active tasks');
    if (!file || !file.buffer?.length) throw badRequest(ErrorCode.FILE_REQUIRED, 'A photo or PDF file is required');
    if (file.size > this.config.uploadMaxBytes) throw new AppException(ErrorCode.FILE_TOO_LARGE, 'File is too large', 413);
    const detected = detectFileType(file.buffer);
    if (!detected || !extensionMatches(file.originalname, detected)) {
      throw new AppException(ErrorCode.FILE_TYPE_NOT_ALLOWED, 'Only JPEG, PNG, WEBP photos and PDF documents are allowed', 415);
    }
    const count = await this.prisma.evidence.count({ where: { taskId, deletedAt: null } });
    if (count >= MAX_EVIDENCE_PER_TASK) throw conflict(ErrorCode.CONFLICT, `At most ${MAX_EVIDENCE_PER_TASK} files per task`);

    // Tenant-isolated, unguessable key; user-supplied names never reach the storage path.
    const key = `companies/${task.companyId}/tasks/${task.id}/${randomUUID()}.${detected.ext}`;
    await this.storage.put(key, file.buffer, detected.mime);
    const evidence = await this.prisma.evidence.create({
      data: {
        companyId: task.companyId,
        taskId: task.id,
        uploadedById: userId,
        kind: detected.kind,
        storageKey: key,
        mimeType: detected.mime,
        sizeBytes: file.size,
        sha256: sha256(file.buffer),
        originalName: sanitizeFilename(file.originalname),
        comment: fields.comment,
        capturedAt: fields.capturedAt ? new Date(fields.capturedAt) : null,
        latitude: fields.latitude ?? null,
        longitude: fields.longitude ?? null,
      },
      select: { id: true, kind: true, mimeType: true, sizeBytes: true, comment: true, capturedAt: true, createdAt: true, originalName: true },
    });
    await this.audit.log({ action: AuditAction.EVIDENCE_UPLOADED, entityType: 'Evidence', entityId: evidence.id, companyId: task.companyId, actorUserId: userId, metadata: { taskId } });
    return evidence;
  }

  /** Access: the uploader, or a supervisor of the task's site in the same company. */
  async evidenceForDownload(userId: string, evidenceId: string) {
    const ev = await this.prisma.evidence.findFirst({ where: { id: evidenceId, deletedAt: null }, include: { task: { select: { siteId: true, assigneeId: true } } } });
    if (!ev) throw notFound('Evidence');
    if (ev.uploadedById !== userId && ev.task?.assigneeId !== userId) {
      const m = await this.prisma.companyMembership.findUnique({ where: { companyId_userId: { companyId: ev.companyId, userId } } });
      if (!m || m.status !== 'ACTIVE' || m.role === Role.WORKER) throw notFound('Evidence');
      if (ev.task) await this.access.assertSiteAccess(m, ev.task.siteId);
    }
    return { stream: await this.storage.get(ev.storageKey), mimeType: ev.mimeType, sizeBytes: ev.sizeBytes, id: ev.id };
  }
}
