import { Injectable } from '@nestjs/common';
import { ApplicationStatus, CompanyMembership, MembershipStatus, Prisma, Role, VacancyStatus } from '@prisma/client';
import { ErrorCode, badRequest, conflict, forbidden, notFound } from '../common/errors';
import { paginated } from '../common/dto/pagination.dto';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { CompaniesService } from '../companies/companies.service';
import { BrowseVacanciesQuery, CompanyVacanciesQuery, CreateVacancyDto, UpdateVacancyDto, VacancyStatusDto } from './dto/vacancies.dto';

const toDate = (s?: string) => (s ? new Date(`${s.slice(0, 10)}T00:00:00.000Z`) : undefined);

const publicCompany = { select: { id: true, name: true, verificationStatus: true, region: true, city: true } } as const;

@Injectable()
export class VacanciesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
    private readonly audit: AuditService,
    private readonly companies: CompaniesService,
  ) {}

  private async vacancyScope(actor: CompanyMembership): Promise<Prisma.VacancyWhereInput> {
    const siteIds = await this.access.supervisedSiteIds(actor);
    if (siteIds === null) return {};
    return { OR: [{ createdById: actor.userId }, { siteId: { in: siteIds } }] };
  }

  async assertVacancyAccess(actor: CompanyMembership, id: string) {
    const v = await this.prisma.vacancy.findFirst({ where: { id, companyId: actor.companyId, deletedAt: null, ...(await this.vacancyScope(actor)) } });
    if (!v) throw notFound('Vacancy');
    return v;
  }

  async create(actor: CompanyMembership, dto: CreateVacancyDto, meta: RequestMeta) {
    if (actor.role === Role.FOREMAN && !dto.siteId) throw badRequest(ErrorCode.VALIDATION_FAILED, 'Select one of your sites');
    let site = null;
    if (dto.siteId) site = await this.access.assertSiteAccess(actor, dto.siteId);
    const { publish, ...data } = dto;
    const v = await this.prisma.vacancy.create({
      data: {
        ...data,
        companyId: actor.companyId,
        createdById: actor.userId,
        startDate: toDate(dto.startDate),
        latitude: dto.latitude ?? site?.latitude,
        longitude: dto.longitude ?? site?.longitude,
        address: dto.address ?? site?.address,
        status: publish ? VacancyStatus.OPEN : VacancyStatus.DRAFT,
        publishedAt: publish ? new Date() : null,
      },
    });
    await this.audit.log({
      action: AuditAction.VACANCY_CREATED,
      entityType: 'Vacancy',
      entityId: v.id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { title: v.title, status: v.status },
    });
    return v;
  }

  async update(actor: CompanyMembership, id: string, dto: UpdateVacancyDto, meta: RequestMeta) {
    const v = await this.assertVacancyAccess(actor, id);
    if (v.status === VacancyStatus.CLOSED || v.status === VacancyStatus.FILLED) throw conflict(ErrorCode.VACANCY_NOT_OPEN, 'Closed vacancies cannot be edited');
    if (dto.siteId) await this.access.assertSiteAccess(actor, dto.siteId);
    const { publish: _p, ...data } = dto;
    const updated = await this.prisma.vacancy.update({ where: { id }, data: { ...data, startDate: toDate(dto.startDate) } });
    await this.audit.log({
      action: AuditAction.VACANCY_UPDATED,
      entityType: 'Vacancy',
      entityId: id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { fields: Object.keys(data) },
    });
    return updated;
  }

  async setStatus(actor: CompanyMembership, id: string, dto: VacancyStatusDto, meta: RequestMeta) {
    const v = await this.assertVacancyAccess(actor, id);
    if (v.status === VacancyStatus.CLOSED || v.status === VacancyStatus.FILLED) {
      if (dto.status !== VacancyStatus.OPEN) throw conflict(ErrorCode.VACANCY_NOT_OPEN, `Vacancy is already ${v.status}`);
      const accepted = await this.prisma.application.count({ where: { vacancyId: id, status: ApplicationStatus.ACCEPTED } });
      if (accepted >= v.workersNeeded) throw conflict(ErrorCode.VACANCY_NOT_OPEN, 'All positions are filled. Increase workersNeeded first.');
    }
    const updated = await this.prisma.vacancy.update({
      where: { id },
      data: {
        status: dto.status,
        publishedAt: dto.status === VacancyStatus.OPEN ? (v.publishedAt ?? new Date()) : v.publishedAt,
        closedAt: dto.status === VacancyStatus.CLOSED ? new Date() : null,
      },
    });
    await this.audit.log({
      action: AuditAction.VACANCY_STATUS_CHANGED,
      entityType: 'Vacancy',
      entityId: id,
      companyId: actor.companyId,
      actorUserId: actor.userId,
      ip: meta.ip,
      metadata: { from: v.status, to: dto.status },
    });
    return updated;
  }

  async listForCompany(actor: CompanyMembership, q: CompanyVacanciesQuery) {
    const where: Prisma.VacancyWhereInput = {
      companyId: actor.companyId,
      deletedAt: null,
      ...(q.status ? { status: q.status } : {}),
      ...(await this.vacancyScope(actor)),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.vacancy.findMany({ where, orderBy: { createdAt: 'desc' }, skip: q.skip, take: q.limit, include: { site: { select: { id: true, name: true } } } }),
      this.prisma.vacancy.count({ where }),
    ]);
    const counts = await this.prisma.application.groupBy({
      by: ['vacancyId', 'status'],
      where: { vacancyId: { in: items.map((i) => i.id) } },
      _count: { _all: true },
    });
    return paginated(
      items.map((v) => {
        const c = counts.filter((x) => x.vacancyId === v.id);
        const n = (s: ApplicationStatus) => c.find((x) => x.status === s)?._count._all ?? 0;
        return { ...v, applications: { new: n('SUBMITTED'), shortlisted: n('SHORTLISTED'), accepted: n('ACCEPTED'), total: c.reduce((a, x) => a + x._count._all, 0) - n('WITHDRAWN') } };
      }),
      total,
      q,
    );
  }

  async getForCompany(actor: CompanyMembership, id: string) {
    await this.assertVacancyAccess(actor, id);
    return this.prisma.vacancy.findUniqueOrThrow({ where: { id }, include: { site: { select: { id: true, name: true } } } });
  }

  // ───── public job board (authenticated workers) ─────

  async browse(userId: string, q: BrowseVacanciesQuery) {
    const where: Prisma.VacancyWhereInput = {
      status: VacancyStatus.OPEN,
      deletedAt: null,
      company: { deletedAt: null },
      ...(q.category ? { category: q.category } : {}),
      ...(q.region ? { region: { equals: q.region, mode: 'insensitive' } } : {}),
      ...(q.city ? { city: { equals: q.city, mode: 'insensitive' } } : {}),
      ...(q.search
        ? { OR: [{ title: { contains: q.search, mode: 'insensitive' } }, { description: { contains: q.search, mode: 'insensitive' } }] }
        : {}),
    };
    const orderBy: Prisma.VacancyOrderByWithRelationInput[] = q.sort === 'rate' ? [{ rateAmount: 'desc' }, { publishedAt: 'desc' }] : [{ publishedAt: 'desc' }];
    const [items, total] = await this.prisma.$transaction([
      this.prisma.vacancy.findMany({
        where,
        orderBy,
        skip: q.skip,
        take: q.limit,
        select: {
          id: true,
          title: true,
          category: true,
          region: true,
          city: true,
          rateAmount: true,
          currency: true,
          paymentPeriod: true,
          workersNeeded: true,
          startDate: true,
          durationDays: true,
          publishedAt: true,
          company: publicCompany,
        },
      }),
      this.prisma.vacancy.count({ where }),
    ]);
    const mine = await this.prisma.application.findMany({
      where: { workerId: userId, vacancyId: { in: items.map((i) => i.id) } },
      select: { vacancyId: true, status: true },
    });
    return paginated(
      items.map((v) => ({ ...v, myApplicationStatus: mine.find((a) => a.vacancyId === v.id)?.status ?? null })),
      total,
      q,
    );
  }

  async publicDetail(userId: string, id: string) {
    const v = await this.prisma.vacancy.findFirst({
      where: { id, deletedAt: null, status: { not: VacancyStatus.DRAFT }, company: { deletedAt: null } },
      include: { company: publicCompany },
    });
    if (!v) throw notFound('Vacancy');
    const [myApplication, trust, membership, blocked] = await Promise.all([
      this.prisma.application.findUnique({ where: { vacancyId_workerId: { vacancyId: id, workerId: userId } } }),
      this.companies.trustSignals(v.companyId),
      this.prisma.companyMembership.findUnique({ where: { companyId_userId: { companyId: v.companyId, userId } } }),
      this.prisma.companyWorkerBlock.count({ where: { companyId: v.companyId, userId } }),
    ]);
    const { createdById: _c, siteId: _s, ...pub } = v;
    return {
      ...pub,
      companyTrust: trust,
      myApplication: myApplication ? { id: myApplication.id, status: myApplication.status, createdAt: myApplication.createdAt } : null,
      canApply:
        v.status === VacancyStatus.OPEN &&
        !blocked &&
        !(membership && membership.status === MembershipStatus.ACTIVE) &&
        (!myApplication || myApplication.status === ApplicationStatus.WITHDRAWN),
    };
  }

  static assertFillable(v: { status: VacancyStatus }) {
    if (v.status !== VacancyStatus.OPEN) throw forbidden(ErrorCode.VACANCY_NOT_OPEN, 'This vacancy is not accepting applications');
  }
}
