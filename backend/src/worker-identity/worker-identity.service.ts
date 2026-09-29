import { Injectable } from '@nestjs/common';
import { CompanyMembership, Role, ShiftStatus, TaskStatus } from '@prisma/client';
import { forbidden, notFound, ErrorCode } from '../common/errors';
import { addDays, localDateString } from '../common/utils/time';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { computeIdentity, TRUST_CRITERIA, TrustLevel } from './identity.calc';

const DEFAULT_TZ = 'Asia/Tashkent';

export interface IdentitySummary {
  trustLevel: TrustLevel;
  verifiedWorkdays: number;
  verifiedHours: number;
  verifiedTasks: number;
  verifiedEmployers: number;
  punctualityRate: number | null;
}

@Injectable()
export class WorkerIdentityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
  ) {}

  /** Full identity: verified stats + per-employer breakdown + self-reported profile (kept separate). */
  async identity(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, include: { workerProfile: true } });
    if (!user) throw notFound('Worker');
    const today = localDateString(new Date(), DEFAULT_TZ);
    const windowStart = addDays(today, -TRUST_CRITERIA.ATTENDANCE_WINDOW_DAYS);

    const [shifts, approvedTasks, membershipCount, assignments] = await Promise.all([
      this.prisma.shift.findMany({
        where: { workerId: userId, status: ShiftStatus.VERIFIED },
        select: {
          businessDate: true,
          verifiedMinutes: true,
          isLate: true,
          companyId: true,
          site: { select: { projectId: true, project: { select: { name: true } } } },
          company: { select: { name: true, verificationStatus: true } },
        },
      }),
      this.prisma.task.count({ where: { assigneeId: userId, status: TaskStatus.APPROVED } }),
      this.prisma.companyMembership.count({ where: { userId, role: Role.WORKER } }),
      this.prisma.siteAssignment.findMany({
        where: {
          userId,
          role: Role.WORKER,
          OR: [{ endDate: null }, { endDate: { gte: new Date(`${windowStart}T00:00:00Z`) } }],
        },
        select: { startDate: true, endDate: true, site: { select: { workDays: true, timezone: true } } },
      }),
    ]);

    const stats = computeIdentity({
      verifiedShifts: shifts.map((s) => ({
        businessDate: s.businessDate.toISOString().slice(0, 10),
        verifiedMinutes: s.verifiedMinutes,
        isLate: s.isLate,
        companyId: s.companyId,
        projectId: s.site.projectId,
      })),
      approvedTasks,
      hasEmployerRelation: membershipCount > 0,
      assignments: assignments.map((a) => ({
        startDate: localDateString(a.startDate, a.site.timezone),
        endDate: a.endDate ? localDateString(a.endDate, a.site.timezone) : null,
        workDays: a.site.workDays,
      })),
      today,
    });

    const employerMap = new Map<string, { companyId: string; name: string; companyVerified: boolean; verifiedDays: Set<string>; verifiedMinutes: number; projects: Set<string> }>();
    for (const s of shifts) {
      const e = employerMap.get(s.companyId) ?? {
        companyId: s.companyId,
        name: s.company.name,
        companyVerified: s.company.verificationStatus === 'VERIFIED',
        verifiedDays: new Set<string>(),
        verifiedMinutes: 0,
        projects: new Set<string>(),
      };
      e.verifiedDays.add(s.businessDate.toISOString().slice(0, 10));
      e.verifiedMinutes += s.verifiedMinutes;
      e.projects.add(s.site.project.name);
      employerMap.set(s.companyId, e);
    }

    return {
      userId,
      fullName: user.fullName,
      verified: stats,
      employers: [...employerMap.values()].map((e) => ({
        companyId: e.companyId,
        name: e.name,
        companyVerified: e.companyVerified,
        verifiedDays: e.verifiedDays.size,
        verifiedHours: Math.round((e.verifiedMinutes / 60) * 10) / 10,
        projects: [...e.projects],
      })),
      selfReported: user.workerProfile
        ? {
            primaryTrade: user.workerProfile.primaryTrade,
            trades: user.workerProfile.trades,
            experienceYears: user.workerProfile.selfReportedExperienceYears,
            bio: user.workerProfile.bio,
            region: user.workerProfile.region,
            city: user.workerProfile.city,
            availability: user.workerProfile.availability,
          }
        : null,
      trustCriteria: TRUST_CRITERIA,
      generatedAt: new Date(),
    };
  }

  /** Lightweight batch summary for applicant lists (no N+1: 3 grouped queries for the whole page). */
  async summaries(userIds: string[]): Promise<Map<string, IdentitySummary>> {
    const ids = [...new Set(userIds)];
    const out = new Map<string, IdentitySummary>();
    if (!ids.length) return out;
    const [shifts, tasks, memberships] = await Promise.all([
      this.prisma.shift.findMany({
        where: { workerId: { in: ids }, status: ShiftStatus.VERIFIED },
        select: { workerId: true, businessDate: true, verifiedMinutes: true, companyId: true, isLate: true, site: { select: { projectId: true } } },
      }),
      this.prisma.task.groupBy({ by: ['assigneeId'], where: { assigneeId: { in: ids }, status: TaskStatus.APPROVED }, _count: { _all: true } }),
      this.prisma.companyMembership.groupBy({ by: ['userId'], where: { userId: { in: ids }, role: Role.WORKER }, _count: { _all: true } }),
    ]);
    const today = localDateString(new Date(), DEFAULT_TZ);
    for (const id of ids) {
      const own = shifts.filter((s) => s.workerId === id);
      const stats = computeIdentity({
        verifiedShifts: own.map((s) => ({
          businessDate: s.businessDate.toISOString().slice(0, 10),
          verifiedMinutes: s.verifiedMinutes,
          isLate: s.isLate,
          companyId: s.companyId,
          projectId: s.site.projectId,
        })),
        approvedTasks: tasks.find((t) => t.assigneeId === id)?._count._all ?? 0,
        hasEmployerRelation: (memberships.find((m) => m.userId === id)?._count._all ?? 0) > 0,
        assignments: [],
        today,
      });
      out.set(id, {
        trustLevel: stats.trustLevel,
        verifiedWorkdays: stats.verifiedWorkdays,
        verifiedHours: stats.verifiedHours,
        verifiedTasks: stats.verifiedTasks,
        verifiedEmployers: stats.verifiedEmployers,
        punctualityRate: stats.punctualityRate,
      });
    }
    return out;
  }

  /**
   * A company may see a worker's identity only if the worker is/was its member (foremen: on their sites)
   * or applied to one of its vacancies (the worker shared it by applying).
   */
  async identityForCompany(actor: CompanyMembership, workerUserId: string) {
    const applied = await this.prisma.application.count({ where: { companyId: actor.companyId, workerId: workerUserId } });
    if (applied && this.access.isManagement(actor)) return this.identity(workerUserId);
    if (applied && actor.role === Role.FOREMAN) {
      const own = await this.prisma.application.count({
        where: { companyId: actor.companyId, workerId: workerUserId, vacancy: { createdById: actor.userId } },
      });
      if (own) return this.identity(workerUserId);
    }
    try {
      await this.access.assertWorkerAccess(actor, workerUserId, { includeFormer: true });
    } catch {
      throw forbidden(ErrorCode.FORBIDDEN, 'You cannot view this worker');
    }
    return this.identity(workerUserId);
  }
}
