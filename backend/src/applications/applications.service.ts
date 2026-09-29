import { Injectable } from '@nestjs/common';
import { ApplicationStatus, AssignmentStatus, CompanyMembership, MembershipStatus, Prisma, Role, VacancyStatus } from '@prisma/client';
import { ErrorCode, conflict, forbidden, notFound } from '../common/errors';
import { paginated } from '../common/dto/pagination.dto';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { WorkerIdentityService } from '../worker-identity/worker-identity.service';
import { VacanciesService } from '../vacancies/vacancies.service';
import { ApplicationsQuery, ApplicationStatusDto, ApplyDto } from '../vacancies/dto/vacancies.dto';

const TRANSITIONS: Record<ApplicationStatus, ApplicationStatus[]> = {
  SUBMITTED: [ApplicationStatus.SHORTLISTED, ApplicationStatus.ACCEPTED, ApplicationStatus.REJECTED],
  SHORTLISTED: [ApplicationStatus.ACCEPTED, ApplicationStatus.REJECTED],
  ACCEPTED: [],
  REJECTED: [],
  WITHDRAWN: [],
};

const STATUS_TEXT: Partial<Record<ApplicationStatus, string>> = {
  SHORTLISTED: "Arizangiz saralandi. Kompaniya siz bilan bog'lanadi.",
  ACCEPTED: 'Tabriklaymiz! Siz ishga qabul qilindingiz.',
  REJECTED: 'Afsuski, arizangiz rad etildi.',
};

@Injectable()
export class ApplicationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly identity: WorkerIdentityService,
    private readonly vacancies: VacanciesService,
  ) {}

  // ───── worker ─────

  async apply(userId: string, vacancyId: string, dto: ApplyDto, meta: RequestMeta) {
    const v = await this.prisma.vacancy.findFirst({ where: { id: vacancyId, deletedAt: null, company: { deletedAt: null } } });
    if (!v || v.status === VacancyStatus.DRAFT) throw notFound('Vacancy');
    if (v.status !== VacancyStatus.OPEN) throw conflict(ErrorCode.VACANCY_NOT_OPEN, 'This vacancy is no longer accepting applications');
    const [blocked, membership, existing] = await Promise.all([
      this.prisma.companyWorkerBlock.count({ where: { companyId: v.companyId, userId } }),
      this.prisma.companyMembership.findUnique({ where: { companyId_userId: { companyId: v.companyId, userId } } }),
      this.prisma.application.findUnique({ where: { vacancyId_workerId: { vacancyId, workerId: userId } } }),
    ]);
    if (blocked) throw forbidden(ErrorCode.BLOCKED_BY_COMPANY, 'You cannot apply to this company');
    if (membership?.status === MembershipStatus.ACTIVE) throw conflict(ErrorCode.ALREADY_MEMBER, 'You already work for this company');

    let application;
    if (existing) {
      if (existing.status !== ApplicationStatus.WITHDRAWN) throw conflict(ErrorCode.ALREADY_APPLIED, 'You have already applied', { status: existing.status });
      application = await this.prisma.application.update({
        where: { id: existing.id },
        data: { status: ApplicationStatus.SUBMITTED, coverNote: dto.coverNote ?? existing.coverNote, statusChangedAt: new Date(), statusChangedBy: userId, statusReason: null },
      });
    } else {
      application = await this.prisma.application.create({ data: { vacancyId, companyId: v.companyId, workerId: userId, coverNote: dto.coverNote } });
    }
    await this.audit.log({
      action: AuditAction.APPLICATION_SUBMITTED,
      entityType: 'Application',
      entityId: application.id,
      companyId: v.companyId,
      actorUserId: userId,
      ip: meta.ip,
      metadata: { vacancyId },
    });
    const recipients = new Set(await this.notifications.supervisorsOf(v.companyId));
    recipients.add(v.createdById);
    const worker = await this.prisma.user.findUnique({ where: { id: userId }, select: { fullName: true } });
    await this.notifications.notify([...recipients], {
      type: 'APPLICATION_RECEIVED',
      category: 'applications',
      companyId: v.companyId,
      title: 'Yangi ariza',
      body: `${worker?.fullName ?? 'Ishchi'} — "${v.title}"`,
      data: { applicationId: application.id, vacancyId },
    });
    return application;
  }

  async mine(userId: string, q: ApplicationsQuery) {
    const where: Prisma.ApplicationWhereInput = { workerId: userId, ...(q.status ? { status: q.status } : {}) };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.application.findMany({
        where,
        orderBy: { updatedAt: 'desc' },
        skip: q.skip,
        take: q.limit,
        include: {
          vacancy: {
            select: { id: true, title: true, status: true, rateAmount: true, currency: true, paymentPeriod: true, city: true, company: { select: { id: true, name: true, verificationStatus: true } } },
          },
        },
      }),
      this.prisma.application.count({ where }),
    ]);
    return paginated(items, total, q);
  }

  async withdraw(userId: string, id: string, meta: RequestMeta) {
    const a = await this.prisma.application.findFirst({ where: { id, workerId: userId } });
    if (!a) throw notFound('Application');
    if (a.status !== ApplicationStatus.SUBMITTED && a.status !== ApplicationStatus.SHORTLISTED) {
      throw conflict(ErrorCode.APPLICATION_INVALID_STATE, `Application is ${a.status}`);
    }
    const updated = await this.prisma.application.update({
      where: { id },
      data: { status: ApplicationStatus.WITHDRAWN, statusChangedAt: new Date(), statusChangedBy: userId },
    });
    await this.audit.log({ action: AuditAction.APPLICATION_WITHDRAWN, entityType: 'Application', entityId: id, companyId: a.companyId, actorUserId: userId, ip: meta.ip });
    return updated;
  }

  // ───── company ─────

  async listForVacancy(actor: CompanyMembership, vacancyId: string, q: ApplicationsQuery) {
    await this.vacancies.assertVacancyAccess(actor, vacancyId);
    const where: Prisma.ApplicationWhereInput = {
      vacancyId,
      companyId: actor.companyId,
      ...(q.status ? { status: q.status } : { status: { not: ApplicationStatus.WITHDRAWN } }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.application.findMany({
        where,
        orderBy: [{ status: 'asc' }, { createdAt: 'asc' }],
        skip: q.skip,
        take: q.limit,
        include: { worker: { select: { id: true, fullName: true, phone: true, workerProfile: { select: { primaryTrade: true, selfReportedExperienceYears: true, city: true } } } } },
      }),
      this.prisma.application.count({ where }),
    ]);
    const summaries = await this.identity.summaries(items.map((i) => i.workerId));
    return paginated(
      items.map((a) => ({ ...a, identity: summaries.get(a.workerId) ?? null })),
      total,
      q,
    );
  }

  async getForCompany(actor: CompanyMembership, id: string) {
    const a = await this.prisma.application.findFirst({
      where: { id, companyId: actor.companyId },
      include: {
        worker: { select: { id: true, fullName: true, phone: true } },
        vacancy: { select: { id: true, title: true, status: true, workersNeeded: true, siteId: true } },
      },
    });
    if (!a) throw notFound('Application');
    await this.vacancies.assertVacancyAccess(actor, a.vacancyId);
    const identity = await this.identity.identity(a.workerId);
    return { ...a, identity };
  }

  async changeStatus(actor: CompanyMembership, id: string, dto: ApplicationStatusDto, meta: RequestMeta) {
    const a = await this.prisma.application.findFirst({ where: { id, companyId: actor.companyId }, include: { vacancy: true } });
    if (!a) throw notFound('Application');
    await this.vacancies.assertVacancyAccess(actor, a.vacancyId);
    if (!TRANSITIONS[a.status].includes(dto.status)) {
      throw conflict(ErrorCode.APPLICATION_INVALID_STATE, `Cannot change application from ${a.status} to ${dto.status}`);
    }
    if (dto.status === ApplicationStatus.ACCEPTED && a.vacancy.status !== VacancyStatus.OPEN && a.vacancy.status !== VacancyStatus.PAUSED) {
      throw conflict(ErrorCode.VACANCY_NOT_OPEN, 'The vacancy is closed');
    }
    const siteId = dto.siteId ?? a.vacancy.siteId ?? undefined;
    if (dto.status === ApplicationStatus.ACCEPTED && siteId) await this.access.assertSiteAccess(actor, siteId);

    const result = await this.prisma.$transaction(async (tx) => {
      const r = await tx.application.updateMany({
        where: { id, status: a.status },
        data: { status: dto.status, statusReason: dto.reason ?? null, statusChangedAt: new Date(), statusChangedBy: actor.userId },
      });
      if (r.count === 0) throw conflict(ErrorCode.APPLICATION_INVALID_STATE, 'Application was changed by someone else');

      let hired = false;
      let vacancyFilled = false;
      if (dto.status === ApplicationStatus.ACCEPTED) {
        // Hire: the worker joins the company (history from now on is verified by this company).
        const existing = await tx.companyMembership.findUnique({ where: { companyId_userId: { companyId: actor.companyId, userId: a.workerId } } });
        if (existing?.status === MembershipStatus.ACTIVE && existing.role !== Role.WORKER) {
          throw conflict(ErrorCode.ALREADY_MEMBER, 'This person is already a member with another role');
        }
        if (!existing) {
          await tx.companyMembership.create({ data: { companyId: actor.companyId, userId: a.workerId, role: Role.WORKER, invitedById: actor.userId } });
        } else if (existing.status !== MembershipStatus.ACTIVE) {
          await tx.companyMembership.update({
            where: { id: existing.id },
            data: { status: MembershipStatus.ACTIVE, role: Role.WORKER, removedAt: null, joinedAt: new Date(), invitedById: actor.userId },
          });
        }
        if (siteId) {
          const assigned = await tx.siteAssignment.findFirst({ where: { siteId, userId: a.workerId, status: AssignmentStatus.ACTIVE } });
          if (!assigned) {
            await tx.siteAssignment.create({ data: { companyId: actor.companyId, siteId, userId: a.workerId, role: Role.WORKER, assignedById: actor.userId } });
          }
        }
        hired = true;
        const accepted = await tx.application.count({ where: { vacancyId: a.vacancyId, status: ApplicationStatus.ACCEPTED } });
        if (accepted >= a.vacancy.workersNeeded) {
          await tx.vacancy.update({ where: { id: a.vacancyId }, data: { status: VacancyStatus.FILLED, closedAt: new Date() } });
          vacancyFilled = true;
        }
      }
      await this.audit.log(
        {
          action: AuditAction.APPLICATION_STATUS_CHANGED,
          entityType: 'Application',
          entityId: id,
          companyId: actor.companyId,
          actorUserId: actor.userId,
          ip: meta.ip,
          metadata: { from: a.status, to: dto.status, reason: dto.reason ?? null, hired, vacancyFilled },
        },
        tx,
      );
      return { hired, vacancyFilled };
    });

    const company = await this.prisma.company.findUniqueOrThrow({ where: { id: actor.companyId }, select: { name: true } });
    await this.notifications.notify([a.workerId], {
      type: `APPLICATION_${dto.status}`,
      category: 'applications',
      companyId: actor.companyId,
      title: `${company.name}: "${a.vacancy.title}"`,
      body: `${STATUS_TEXT[dto.status] ?? ''}${dto.reason ? ` ${dto.reason}` : ''}`.trim(),
      data: { applicationId: id, vacancyId: a.vacancyId },
    });
    const updated = await this.prisma.application.findUniqueOrThrow({ where: { id } });
    return { ...updated, ...result };
  }
}
