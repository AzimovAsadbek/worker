import { Injectable } from '@nestjs/common';
import { AssignmentStatus, CompanyMembership, MembershipStatus, Prisma, Role, ShiftStatus } from '@prisma/client';
import { ErrorCode, badRequest, conflict, forbidden, notFound } from '../common/errors';
import { paginated } from '../common/dto/pagination.dto';
import { normalizePhone } from '../common/utils/phone';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AddMemberDto, BlockWorkerDto, ListMembersQuery, UpdateMemberDto } from './dto/memberships.dto';

const memberInclude = {
  user: { select: { id: true, fullName: true, phone: true } },
} satisfies Prisma.CompanyMembershipInclude;

@Injectable()
export class MembershipsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
  ) {}

  async list(actor: CompanyMembership, q: ListMembersQuery) {
    const siteIds = await this.access.supervisedSiteIds(actor);
    const where: Prisma.CompanyMembershipWhereInput = {
      companyId: actor.companyId,
      status: q.status ?? MembershipStatus.ACTIVE,
      ...(q.role ? { role: q.role } : {}),
    };
    const assignmentFilter: Prisma.SiteAssignmentWhereInput = { companyId: actor.companyId, status: AssignmentStatus.ACTIVE };
    if (q.siteId) assignmentFilter.siteId = q.siteId;
    if (siteIds !== null) {
      // Foreman: only workers on own sites (and never other supervisors' private data).
      if (q.siteId && !siteIds.includes(q.siteId)) throw forbidden(ErrorCode.SITE_NOT_ASSIGNED, 'This site is not assigned to you');
      where.role = Role.WORKER;
      if (!q.siteId) assignmentFilter.siteId = { in: siteIds };
    }
    if (q.siteId || siteIds !== null) {
      where.user = { siteAssignments: { some: assignmentFilter } };
    }
    if (q.search) {
      const s = q.search;
      where.AND = [{ user: { OR: [{ fullName: { contains: s, mode: 'insensitive' } }, { phone: { contains: s.replace(/\s/g, '') } }] } }];
    }
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.companyMembership.findMany({
        where,
        include: memberInclude,
        orderBy: [{ role: 'asc' }, { user: { fullName: 'asc' } }],
        skip: q.skip,
        take: q.limit,
      }),
      this.prisma.companyMembership.count({ where }),
    ]);
    const userIds = rows.map((r) => r.userId);
    const assignments = await this.prisma.siteAssignment.findMany({
      where: { companyId: actor.companyId, userId: { in: userIds }, status: AssignmentStatus.ACTIVE },
      include: { site: { select: { id: true, name: true } } },
    });
    const items = rows.map((r) => ({
      ...r,
      assignments: assignments
        .filter((a) => a.userId === r.userId)
        .map((a) => ({ id: a.id, siteId: a.siteId, siteName: a.site.name, role: a.role, isResident: a.isResident })),
    }));
    return paginated(items, total, q);
  }

  async get(actor: CompanyMembership, memberId: string) {
    const m = await this.prisma.companyMembership.findFirst({ where: { id: memberId, companyId: actor.companyId }, include: memberInclude });
    if (!m) throw notFound('Member');
    if (!this.access.isManagement(actor) && m.userId !== actor.userId) {
      await this.access.assertWorkerAccess(actor, m.userId, { includeFormer: true });
    }
    const assignments = await this.prisma.siteAssignment.findMany({
      where: { companyId: actor.companyId, userId: m.userId },
      include: { site: { select: { id: true, name: true } } },
      orderBy: { startDate: 'desc' },
    });
    return { ...m, assignments };
  }

  async add(actor: CompanyMembership, dto: AddMemberDto, meta: RequestMeta) {
    const phone = normalizePhone(dto.phone);
    if (!phone) throw badRequest(ErrorCode.INVALID_PHONE, 'Invalid Uzbek phone number');
    const siteIds = [...new Set(dto.siteIds ?? [])];

    // Role rules
    if (actor.role === Role.FOREMAN) {
      if (dto.role !== Role.WORKER) throw forbidden(ErrorCode.ROLE_NOT_ALLOWED, 'Foremen can only add workers');
      if (!siteIds.length) throw badRequest(ErrorCode.VALIDATION_FAILED, 'Select at least one of your sites');
    }
    if (actor.role === Role.MANAGER && dto.role === Role.COMPANY_ADMIN) {
      throw forbidden(ErrorCode.ROLE_NOT_ALLOWED, 'Managers cannot add admins');
    }
    for (const siteId of siteIds) await this.access.assertSiteAccess(actor, siteId);

    const result = await this.prisma.$transaction(async (tx) => {
      let user = await tx.user.findUnique({ where: { phone } });
      if (!user) user = await tx.user.create({ data: { phone, fullName: dto.fullName ?? null } });
      else if (!user.fullName && dto.fullName) user = await tx.user.update({ where: { id: user.id }, data: { fullName: dto.fullName } });
      if (user.id === actor.userId) throw conflict(ErrorCode.CANNOT_MODIFY_SELF, 'You are already a member');

      const existing = await tx.companyMembership.findUnique({ where: { companyId_userId: { companyId: actor.companyId, userId: user.id } } });
      if (existing && existing.status === MembershipStatus.ACTIVE) {
        throw conflict(ErrorCode.MEMBER_ALREADY_EXISTS, 'This person is already a member of the company', { memberId: existing.id, role: existing.role });
      }
      const membership = existing
        ? await tx.companyMembership.update({
            where: { id: existing.id },
            data: { role: dto.role, status: MembershipStatus.ACTIVE, title: dto.title ?? existing.title, removedAt: null, invitedById: actor.userId, joinedAt: new Date() },
          })
        : await tx.companyMembership.create({
            data: { companyId: actor.companyId, userId: user.id, role: dto.role, title: dto.title, invitedById: actor.userId },
          });

      const assignmentRole = dto.role === Role.FOREMAN ? Role.FOREMAN : Role.WORKER;
      for (const siteId of siteIds) {
        await tx.siteAssignment.create({
          data: {
            companyId: actor.companyId,
            siteId,
            userId: user.id,
            role: assignmentRole,
            isResident: dto.role === Role.WORKER ? !!dto.isResident : false,
            assignedById: actor.userId,
          },
        });
      }
      await this.audit.log(
        {
          action: dto.role === Role.WORKER ? AuditAction.WORKER_ADDED : AuditAction.MEMBER_ADDED,
          entityType: 'CompanyMembership',
          entityId: membership.id,
          companyId: actor.companyId,
          actorUserId: actor.userId,
          ip: meta.ip,
          metadata: { role: dto.role, siteIds, reactivated: !!existing },
        },
        tx,
      );
      return membership;
    });

    const company = await this.prisma.company.findUniqueOrThrow({ where: { id: actor.companyId }, select: { name: true } });
    await this.notifications.notify([result.userId], {
      type: 'MEMBERSHIP_ADDED',
      category: 'system',
      companyId: actor.companyId,
      title: 'Yangi ish joyi',
      body: `Siz "${company.name}" kompaniyasiga qo'shildingiz.`,
      data: { companyId: actor.companyId },
    });
    return this.get(actor, result.id);
  }

  async update(actor: CompanyMembership, memberId: string, dto: UpdateMemberDto, meta: RequestMeta) {
    const m = await this.prisma.companyMembership.findFirst({ where: { id: memberId, companyId: actor.companyId } });
    if (!m || m.status === MembershipStatus.REMOVED) throw notFound('Member');
    if (m.userId === actor.userId && (dto.role || dto.status)) throw forbidden(ErrorCode.CANNOT_MODIFY_SELF, 'You cannot change your own role or status');
    if (actor.role === Role.MANAGER && (m.role === Role.COMPANY_ADMIN || dto.role === Role.COMPANY_ADMIN)) {
      throw forbidden(ErrorCode.ROLE_NOT_ALLOWED, 'Managers cannot manage admins');
    }
    if (m.role === Role.COMPANY_ADMIN && ((dto.role && dto.role !== Role.COMPANY_ADMIN) || dto.status === MembershipStatus.SUSPENDED)) {
      await this.assertNotLastAdmin(actor.companyId);
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      const u = await tx.companyMembership.update({ where: { id: m.id }, data: dto });
      if (dto.role && dto.role !== m.role) {
        // Assignment roles follow the membership role.
        await tx.siteAssignment.updateMany({
          where: { companyId: actor.companyId, userId: m.userId, status: AssignmentStatus.ACTIVE },
          data: { role: dto.role === Role.FOREMAN ? Role.FOREMAN : Role.WORKER },
        });
      }
      await this.audit.log(
        {
          action: AuditAction.MEMBER_UPDATED,
          entityType: 'CompanyMembership',
          entityId: m.id,
          companyId: actor.companyId,
          actorUserId: actor.userId,
          ip: meta.ip,
          metadata: { from: { role: m.role, status: m.status, title: m.title }, to: dto },
        },
        tx,
      );
      return u;
    });
    return updated;
  }

  /** Removes a member from the company. Their history is kept (worker-owned identity, company-owned records). */
  async remove(actor: CompanyMembership, memberId: string, meta: RequestMeta) {
    const m = await this.prisma.companyMembership.findFirst({ where: { id: memberId, companyId: actor.companyId } });
    if (!m || m.status === MembershipStatus.REMOVED) throw notFound('Member');
    if (m.userId === actor.userId) throw forbidden(ErrorCode.CANNOT_MODIFY_SELF, 'Use "leave company" instead');
    if (actor.role === Role.MANAGER && m.role === Role.COMPANY_ADMIN) throw forbidden(ErrorCode.ROLE_NOT_ALLOWED, 'Managers cannot remove admins');
    if (m.role === Role.COMPANY_ADMIN) await this.assertNotLastAdmin(actor.companyId);
    const open = await this.prisma.shift.count({ where: { companyId: actor.companyId, workerId: m.userId, status: ShiftStatus.OPEN } });
    if (open) throw conflict(ErrorCode.SHIFT_OPEN, 'The worker has an open shift. Close or correct it first.');

    await this.prisma.$transaction(async (tx) => {
      await tx.companyMembership.update({ where: { id: m.id }, data: { status: MembershipStatus.REMOVED, removedAt: new Date() } });
      await tx.siteAssignment.updateMany({
        where: { companyId: actor.companyId, userId: m.userId, status: AssignmentStatus.ACTIVE },
        data: { status: AssignmentStatus.ENDED, endDate: new Date() },
      });
      await tx.task.updateMany({
        where: { companyId: actor.companyId, assigneeId: m.userId, status: { in: ['ASSIGNED', 'IN_PROGRESS', 'CHANGES_REQUESTED'] } },
        data: { status: 'CANCELLED' },
      });
      await this.audit.log(
        {
          action: m.role === Role.WORKER ? AuditAction.WORKER_REMOVED : AuditAction.MEMBER_REMOVED,
          entityType: 'CompanyMembership',
          entityId: m.id,
          companyId: actor.companyId,
          actorUserId: actor.userId,
          ip: meta.ip,
          metadata: { role: m.role },
        },
        tx,
      );
    });
  }

  private async assertNotLastAdmin(companyId: string) {
    const admins = await this.prisma.companyMembership.count({
      where: { companyId, role: Role.COMPANY_ADMIN, status: MembershipStatus.ACTIVE },
    });
    if (admins <= 1) throw conflict(ErrorCode.LAST_ADMIN, 'A company must keep at least one active admin');
  }

  // ───── blocks (company-local only; never a platform-wide blacklist) ─────

  listBlocks(companyId: string) {
    return this.prisma.companyWorkerBlock.findMany({ where: { companyId }, orderBy: { createdAt: 'desc' } });
  }

  async block(actor: CompanyMembership, dto: BlockWorkerDto, meta: RequestMeta) {
    const user = await this.prisma.user.findUnique({ where: { id: dto.userId } });
    if (!user) throw notFound('User');
    const hasRelation = await this.prisma.$transaction([
      this.prisma.companyMembership.count({ where: { companyId: actor.companyId, userId: dto.userId } }),
      this.prisma.application.count({ where: { companyId: actor.companyId, workerId: dto.userId } }),
    ]);
    // Can only block people who actually interacted with the company (prevents arbitrary targeting).
    if (hasRelation[0] + hasRelation[1] === 0) throw notFound('Worker');
    const block = await this.prisma.companyWorkerBlock.upsert({
      where: { companyId_userId: { companyId: actor.companyId, userId: dto.userId } },
      create: { companyId: actor.companyId, userId: dto.userId, reason: dto.reason, createdById: actor.userId },
      update: { reason: dto.reason },
    });
    await this.audit.log({
      action: AuditAction.WORKER_BLOCKED,
      entityType: 'CompanyWorkerBlock',
      entityId: block.id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { userId: dto.userId, reason: dto.reason },
    });
    return block;
  }

  async unblock(actor: CompanyMembership, userId: string, meta: RequestMeta) {
    const r = await this.prisma.companyWorkerBlock.deleteMany({ where: { companyId: actor.companyId, userId } });
    if (!r.count) throw notFound('Block');
    await this.audit.log({
      action: AuditAction.WORKER_UNBLOCKED,
      entityType: 'CompanyWorkerBlock',
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { userId },
    });
  }
}
