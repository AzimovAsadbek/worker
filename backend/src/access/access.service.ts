import { Injectable } from '@nestjs/common';
import { AssignmentStatus, CompanyMembership, Prisma, Role, Site } from '@prisma/client';
import { ErrorCode, forbidden, notFound } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Row-level access rules inside a tenant.
 * - COMPANY_ADMIN / MANAGER: every site of the company.
 * - FOREMAN: only sites with an ACTIVE FOREMAN assignment.
 * - WORKER: none of the company-management endpoints (guarded by CompanyRoles).
 */
@Injectable()
export class AccessService {
  constructor(private readonly prisma: PrismaService) {}

  isManagement(m: CompanyMembership) {
    return m.role === Role.COMPANY_ADMIN || m.role === Role.MANAGER;
  }

  /** null = unrestricted (management). */
  async supervisedSiteIds(m: CompanyMembership): Promise<string[] | null> {
    if (this.isManagement(m)) return null;
    if (m.role !== Role.FOREMAN) return [];
    const rows = await this.prisma.siteAssignment.findMany({
      where: { companyId: m.companyId, userId: m.userId, role: Role.FOREMAN, status: AssignmentStatus.ACTIVE, site: { deletedAt: null } },
      select: { siteId: true },
    });
    return rows.map((r) => r.siteId);
  }

  /** Prisma filter for entities that have a `siteId` column. */
  async siteScope(m: CompanyMembership): Promise<{ siteId?: { in: string[] } }> {
    const ids = await this.supervisedSiteIds(m);
    return ids === null ? {} : { siteId: { in: ids } };
  }

  async assertSiteAccess(m: CompanyMembership, siteId: string): Promise<Site> {
    const site = await this.prisma.site.findFirst({ where: { id: siteId, companyId: m.companyId, deletedAt: null } });
    if (!site) throw notFound('Site');
    const ids = await this.supervisedSiteIds(m);
    if (ids !== null && !ids.includes(siteId)) throw forbidden(ErrorCode.SITE_NOT_ASSIGNED, 'This site is not assigned to you');
    return site;
  }

  /**
   * A foreman may act on a worker only if the worker is (or was) assigned to one of the foreman's sites.
   * Management may act on any member of the company. Returns the worker's membership.
   */
  async assertWorkerAccess(m: CompanyMembership, workerUserId: string, opts: { includeFormer?: boolean } = {}) {
    const membership = await this.prisma.companyMembership.findUnique({
      where: { companyId_userId: { companyId: m.companyId, userId: workerUserId } },
    });
    if (!membership || (!opts.includeFormer && membership.status === 'REMOVED')) throw notFound('Worker');
    const ids = await this.supervisedSiteIds(m);
    if (ids === null) return membership;
    const where: Prisma.SiteAssignmentWhereInput = {
      companyId: m.companyId,
      userId: workerUserId,
      siteId: { in: ids },
      ...(opts.includeFormer ? {} : { status: AssignmentStatus.ACTIVE }),
    };
    const assigned = await this.prisma.siteAssignment.count({ where });
    if (!assigned) throw forbidden(ErrorCode.WORKER_NOT_IN_YOUR_SITES, 'This worker is not assigned to your sites');
    return membership;
  }
}
