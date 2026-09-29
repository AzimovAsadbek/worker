import { Injectable } from '@nestjs/common';
import { AssignmentStatus, CompanyMembership, MembershipStatus, Role, ShiftStatus } from '@prisma/client';
import { ErrorCode, badRequest, conflict, forbidden, notFound } from '../common/errors';
import { isValidTimezone } from '../common/utils/time';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AssignDto, CreateSiteDto, UpdateAssignmentDto, UpdateSiteDto } from './dto/sites.dto';

@Injectable()
export class SitesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
  ) {}

  async list(actor: CompanyMembership, projectId?: string) {
    const scope = await this.access.supervisedSiteIds(actor);
    const sites = await this.prisma.site.findMany({
      where: {
        companyId: actor.companyId,
        deletedAt: null,
        ...(projectId ? { projectId } : {}),
        ...(scope !== null ? { id: { in: scope } } : {}),
      },
      include: { project: { select: { id: true, name: true } } },
      orderBy: { name: 'asc' },
    });
    const counts = await this.prisma.siteAssignment.groupBy({
      by: ['siteId', 'role'],
      where: { siteId: { in: sites.map((s) => s.id) }, status: AssignmentStatus.ACTIVE },
      _count: { _all: true },
    });
    return sites.map((s) => ({
      ...s,
      workerCount: counts.find((c) => c.siteId === s.id && c.role === Role.WORKER)?._count._all ?? 0,
      foremanCount: counts.find((c) => c.siteId === s.id && c.role === Role.FOREMAN)?._count._all ?? 0,
    }));
  }

  async get(actor: CompanyMembership, siteId: string) {
    await this.access.assertSiteAccess(actor, siteId);
    return this.prisma.site.findUniqueOrThrow({ where: { id: siteId }, include: { project: { select: { id: true, name: true } } } });
  }

  async create(actor: CompanyMembership, dto: CreateSiteDto, meta: RequestMeta) {
    const project = await this.prisma.project.findFirst({ where: { id: dto.projectId, companyId: actor.companyId, deletedAt: null } });
    if (!project) throw notFound('Project');
    if (dto.timezone && !isValidTimezone(dto.timezone)) throw badRequest(ErrorCode.VALIDATION_FAILED, 'Unknown timezone');
    const site = await this.prisma.site.create({ data: { ...dto, companyId: actor.companyId, createdById: actor.userId } });
    await this.audit.log({
      action: AuditAction.SITE_CREATED,
      entityType: 'Site',
      entityId: site.id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { name: site.name, projectId: project.id },
    });
    return site;
  }

  async update(actor: CompanyMembership, siteId: string, dto: UpdateSiteDto, meta: RequestMeta) {
    const site = await this.access.assertSiteAccess(actor, siteId);
    if (dto.timezone && !isValidTimezone(dto.timezone)) throw badRequest(ErrorCode.VALIDATION_FAILED, 'Unknown timezone');
    const updated = await this.prisma.site.update({ where: { id: site.id }, data: dto });
    await this.audit.log({
      action: AuditAction.SITE_UPDATED,
      entityType: 'Site',
      entityId: site.id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: {
        fields: Object.keys(dto),
        geofenceChanged: dto.latitude !== undefined || dto.longitude !== undefined || dto.radiusMeters !== undefined,
      },
    });
    return updated;
  }

  async remove(actor: CompanyMembership, siteId: string, meta: RequestMeta) {
    const site = await this.access.assertSiteAccess(actor, siteId);
    const open = await this.prisma.shift.count({ where: { siteId, status: ShiftStatus.OPEN } });
    if (open) throw conflict(ErrorCode.SHIFT_OPEN, 'There are open shifts on this site');
    await this.prisma.$transaction(async (tx) => {
      await tx.site.update({ where: { id: site.id }, data: { deletedAt: new Date(), status: 'ARCHIVED' } });
      await tx.siteAssignment.updateMany({ where: { siteId, status: AssignmentStatus.ACTIVE }, data: { status: AssignmentStatus.ENDED, endDate: new Date() } });
      await this.audit.log({ action: AuditAction.SITE_DELETED, entityType: 'Site', entityId: siteId, companyId: actor.companyId, actorUserId: actor.userId, ip: meta.ip }, tx);
    });
  }

  // ───── assignments ─────

  async listAssignments(actor: CompanyMembership, siteId: string) {
    await this.access.assertSiteAccess(actor, siteId);
    return this.prisma.siteAssignment.findMany({
      where: { siteId, status: AssignmentStatus.ACTIVE },
      include: { user: { select: { id: true, fullName: true, phone: true } } },
      orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
    });
  }

  async assign(actor: CompanyMembership, siteId: string, dto: AssignDto, meta: RequestMeta) {
    const site = await this.access.assertSiteAccess(actor, siteId);
    const member = await this.prisma.companyMembership.findUnique({
      where: { companyId_userId: { companyId: actor.companyId, userId: dto.userId } },
    });
    if (!member || member.status !== MembershipStatus.ACTIVE) throw notFound('Member');
    const role = member.role === Role.FOREMAN ? Role.FOREMAN : member.role === Role.WORKER ? Role.WORKER : null;
    if (!role) throw badRequest(ErrorCode.VALIDATION_FAILED, 'Only workers and foremen can be assigned to sites');
    if (actor.role === Role.FOREMAN && role !== Role.WORKER) throw forbidden(ErrorCode.ROLE_NOT_ALLOWED, 'Foremen can only assign workers');

    const existing = await this.prisma.siteAssignment.findFirst({ where: { siteId, userId: dto.userId, status: AssignmentStatus.ACTIVE } });
    if (existing) throw conflict(ErrorCode.CONFLICT, 'Already assigned to this site');
    const assignment = await this.prisma.siteAssignment.create({
      data: {
        companyId: actor.companyId,
        siteId,
        userId: dto.userId,
        role,
        isResident: role === Role.WORKER ? !!dto.isResident : false,
        assignedById: actor.userId,
      },
    });
    await this.audit.log({
      action: AuditAction.SITE_ASSIGNED,
      entityType: 'SiteAssignment',
      entityId: assignment.id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { siteId, userId: dto.userId, role },
    });
    await this.notifications.notify([dto.userId], {
      type: 'SITE_ASSIGNED',
      category: 'shift',
      companyId: actor.companyId,
      title: 'Yangi obyekt',
      body: `Siz "${site.name}" obyektiga biriktirildingiz.`,
      data: { siteId },
    });
    return assignment;
  }

  async updateAssignment(actor: CompanyMembership, siteId: string, assignmentId: string, dto: UpdateAssignmentDto) {
    await this.access.assertSiteAccess(actor, siteId);
    const a = await this.prisma.siteAssignment.findFirst({ where: { id: assignmentId, siteId, companyId: actor.companyId, status: AssignmentStatus.ACTIVE } });
    if (!a) throw notFound('Assignment');
    if (a.role !== Role.WORKER) throw badRequest(ErrorCode.VALIDATION_FAILED, 'Resident mode applies to workers only');
    return this.prisma.siteAssignment.update({ where: { id: a.id }, data: { isResident: dto.isResident } });
  }

  async unassign(actor: CompanyMembership, siteId: string, assignmentId: string, meta: RequestMeta) {
    await this.access.assertSiteAccess(actor, siteId);
    const a = await this.prisma.siteAssignment.findFirst({ where: { id: assignmentId, siteId, companyId: actor.companyId, status: AssignmentStatus.ACTIVE } });
    if (!a) throw notFound('Assignment');
    if (actor.role === Role.FOREMAN && a.role !== Role.WORKER) throw forbidden(ErrorCode.ROLE_NOT_ALLOWED, 'Foremen can only unassign workers');
    const open = await this.prisma.shift.count({ where: { siteId, workerId: a.userId, status: ShiftStatus.OPEN } });
    if (open) throw conflict(ErrorCode.SHIFT_OPEN, 'The worker has an open shift on this site. Close it first.');
    await this.prisma.siteAssignment.update({ where: { id: a.id }, data: { status: AssignmentStatus.ENDED, endDate: new Date() } });
    await this.audit.log({
      action: AuditAction.SITE_UNASSIGNED,
      entityType: 'SiteAssignment',
      entityId: a.id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { siteId, userId: a.userId },
    });
  }
}
