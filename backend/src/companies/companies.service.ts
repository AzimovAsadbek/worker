import { Injectable } from '@nestjs/common';
import { ApplicationStatus, CompanyVerificationStatus, MembershipStatus, Role, ShiftStatus, VacancyStatus } from '@prisma/client';
import { ErrorCode, conflict, notFound } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { CreateCompanyDto, UpdateCompanyDto, VerificationDecisionDto, VerificationRequestDto } from './dto/companies.dto';
import type { RequestMeta } from '../common/types';

const MAX_COMPANIES_PER_USER = 5;

@Injectable()
export class CompaniesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async create(userId: string, dto: CreateCompanyDto, meta: RequestMeta) {
    const owned = await this.prisma.company.count({ where: { createdById: userId, deletedAt: null } });
    if (owned >= MAX_COMPANIES_PER_USER) throw conflict(ErrorCode.CONFLICT, `A user can create at most ${MAX_COMPANIES_PER_USER} companies`);
    return this.prisma.$transaction(async (tx) => {
      const company = await tx.company.create({ data: { ...dto, createdById: userId } });
      await tx.companyMembership.create({ data: { companyId: company.id, userId, role: Role.COMPANY_ADMIN } });
      await this.audit.log(
        { action: AuditAction.COMPANY_CREATED, entityType: 'Company', entityId: company.id, companyId: company.id, actorUserId: userId, ip: meta.ip },
        tx,
      );
      return company;
    });
  }

  async get(companyId: string) {
    const c = await this.prisma.company.findFirst({ where: { id: companyId, deletedAt: null } });
    if (!c) throw notFound('Company');
    return c;
  }

  async update(companyId: string, userId: string, dto: UpdateCompanyDto, meta: RequestMeta) {
    const c = await this.prisma.company.update({ where: { id: companyId }, data: dto });
    await this.audit.log({
      action: AuditAction.COMPANY_UPDATED,
      entityType: 'Company',
      entityId: companyId,
      companyId,
      actorUserId: userId,
      ip: meta.ip,
      metadata: { fields: Object.keys(dto) },
    });
    return c;
  }

  /**
   * Trust signals are computed from real records only. `verified` is true only after a platform review.
   */
  async trustSignals(companyId: string) {
    const company = await this.get(companyId);
    const [workersManaged, activeWorkers, verifiedShifts, activeProjects, completedVacancies] = await Promise.all([
      this.prisma.companyMembership.count({ where: { companyId, role: Role.WORKER } }),
      this.prisma.companyMembership.count({ where: { companyId, role: Role.WORKER, status: MembershipStatus.ACTIVE } }),
      this.prisma.shift.count({ where: { companyId, status: ShiftStatus.VERIFIED } }),
      this.prisma.project.count({ where: { companyId, deletedAt: null, status: { in: ['ACTIVE', 'PLANNED'] } } }),
      this.prisma.vacancy.count({
        where: {
          companyId,
          deletedAt: null,
          status: { in: [VacancyStatus.FILLED, VacancyStatus.CLOSED] },
          applications: { some: { status: ApplicationStatus.ACCEPTED } },
        },
      }),
    ]);
    return {
      companyId,
      name: company.name,
      industry: company.industry,
      region: company.region,
      city: company.city,
      verificationStatus: company.verificationStatus,
      verified: company.verificationStatus === CompanyVerificationStatus.VERIFIED,
      verifiedAt: company.verifiedAt,
      memberSince: company.createdAt,
      workersManaged,
      activeWorkers,
      verifiedShifts,
      activeProjects,
      completedVacancies,
    };
  }

  async requestVerification(companyId: string, userId: string, dto: VerificationRequestDto, meta: RequestMeta) {
    const c = await this.get(companyId);
    if (c.verificationStatus === CompanyVerificationStatus.VERIFIED) throw conflict(ErrorCode.CONFLICT, 'Company is already verified');
    const updated = await this.prisma.company.update({
      where: { id: companyId },
      data: { registrationNumber: dto.registrationNumber, verificationStatus: CompanyVerificationStatus.PENDING, verificationNote: dto.note ?? null },
    });
    await this.audit.log({ action: AuditAction.COMPANY_VERIFICATION_REQUESTED, entityType: 'Company', entityId: companyId, companyId, actorUserId: userId, ip: meta.ip });
    return updated;
  }

  listForVerification(status: CompanyVerificationStatus) {
    return this.prisma.company.findMany({
      where: { verificationStatus: status, deletedAt: null },
      orderBy: { updatedAt: 'asc' },
      take: 100,
      select: { id: true, name: true, registrationNumber: true, region: true, city: true, phone: true, verificationNote: true, createdAt: true },
    });
  }

  async decideVerification(companyId: string, adminId: string, dto: VerificationDecisionDto, meta: RequestMeta) {
    await this.get(companyId);
    const updated = await this.prisma.company.update({
      where: { id: companyId },
      data: {
        verificationStatus: dto.decision,
        verificationNote: dto.note ?? null,
        verifiedAt: dto.decision === 'VERIFIED' ? new Date() : null,
      },
    });
    await this.audit.log({
      action: AuditAction.COMPANY_VERIFICATION_DECIDED,
      entityType: 'Company',
      entityId: companyId,
      companyId,
      actorUserId: adminId,
      ip: meta.ip,
      metadata: { decision: dto.decision },
    });
    return updated;
  }
}
