import { Injectable } from '@nestjs/common';
import { CompanyMembership, Prisma } from '@prisma/client';
import { ErrorCode, badRequest, conflict, notFound } from '../common/errors';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { CreateProjectDto, UpdateProjectDto } from './dto/projects.dto';

const toDate = (s?: string) => (s ? new Date(`${s.slice(0, 10)}T00:00:00.000Z`) : undefined);

@Injectable()
export class ProjectsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
    private readonly audit: AuditService,
  ) {}

  async list(actor: CompanyMembership) {
    const siteIds = await this.access.supervisedSiteIds(actor);
    const where: Prisma.ProjectWhereInput = { companyId: actor.companyId, deletedAt: null };
    if (siteIds !== null) where.sites = { some: { id: { in: siteIds } } };
    return this.prisma.project.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { sites: { where: { deletedAt: null } } } } },
    });
  }

  async get(actor: CompanyMembership, id: string) {
    const siteIds = await this.access.supervisedSiteIds(actor);
    const p = await this.prisma.project.findFirst({
      where: { id, companyId: actor.companyId, deletedAt: null, ...(siteIds !== null ? { sites: { some: { id: { in: siteIds } } } } : {}) },
      include: { sites: { where: { deletedAt: null, ...(siteIds !== null ? { id: { in: siteIds } } : {}) }, orderBy: { name: 'asc' } } },
    });
    if (!p) throw notFound('Project');
    return p;
  }

  private validateDates(start?: Date, end?: Date) {
    if (start && end && end < start) throw badRequest(ErrorCode.VALIDATION_FAILED, 'endDate must be after startDate');
  }

  async create(actor: CompanyMembership, dto: CreateProjectDto, meta: RequestMeta) {
    const data = { ...dto, startDate: toDate(dto.startDate), endDate: toDate(dto.endDate) };
    this.validateDates(data.startDate, data.endDate);
    const p = await this.prisma.project.create({ data: { ...data, companyId: actor.companyId, createdById: actor.userId } });
    await this.audit.log({ action: AuditAction.PROJECT_CREATED, entityType: 'Project', entityId: p.id, companyId: actor.companyId, actorUserId: actor.userId, ip: meta.ip });
    return p;
  }

  async update(actor: CompanyMembership, id: string, dto: UpdateProjectDto, meta: RequestMeta) {
    const existing = await this.prisma.project.findFirst({ where: { id, companyId: actor.companyId, deletedAt: null } });
    if (!existing) throw notFound('Project');
    const data = { ...dto, startDate: toDate(dto.startDate), endDate: toDate(dto.endDate) };
    this.validateDates(data.startDate ?? existing.startDate ?? undefined, data.endDate ?? existing.endDate ?? undefined);
    const p = await this.prisma.project.update({ where: { id }, data });
    await this.audit.log({
      action: AuditAction.PROJECT_UPDATED,
      entityType: 'Project',
      entityId: id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { fields: Object.keys(dto) },
    });
    return p;
  }

  async remove(actor: CompanyMembership, id: string, meta: RequestMeta) {
    const p = await this.prisma.project.findFirst({ where: { id, companyId: actor.companyId, deletedAt: null } });
    if (!p) throw notFound('Project');
    const activeSites = await this.prisma.site.count({ where: { projectId: id, deletedAt: null } });
    if (activeSites) throw conflict(ErrorCode.CONFLICT, 'Delete or move the sites of this project first');
    await this.prisma.project.update({ where: { id }, data: { deletedAt: new Date(), status: 'ARCHIVED' } });
    await this.audit.log({ action: AuditAction.PROJECT_DELETED, entityType: 'Project', entityId: id, companyId: actor.companyId, actorUserId: actor.userId, ip: meta.ip });
  }
}
