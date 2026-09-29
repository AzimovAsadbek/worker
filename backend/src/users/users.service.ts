import { Injectable } from '@nestjs/common';
import { MembershipStatus, Prisma, Role } from '@prisma/client';
import { ErrorCode, badRequest, conflict, notFound } from '../common/errors';
import { PrismaService } from '../prisma/prisma.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { NOTIFICATION_CATEGORIES, NotificationPrefsDto, RegisterDeviceDto, UpdateMeDto, UpsertWorkerProfileDto } from './dto/users.dto';

export type NotificationPrefs = Record<string, { push: boolean; inApp: boolean }>;

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        workerProfile: true,
        memberships: {
          where: { status: MembershipStatus.ACTIVE, company: { deletedAt: null } },
          include: { company: { select: { id: true, name: true, verificationStatus: true, industry: true, timezone: true } } },
          orderBy: { joinedAt: 'asc' },
        },
      },
    });
    if (!user) throw notFound('User');
    return {
      id: user.id,
      phone: user.phone,
      fullName: user.fullName,
      locale: user.locale,
      isPlatformAdmin: user.isPlatformAdmin,
      profileComplete: !!user.fullName,
      workerProfile: user.workerProfile,
      memberships: user.memberships.map((m) => ({
        id: m.id,
        role: m.role,
        title: m.title,
        joinedAt: m.joinedAt,
        company: m.company,
      })),
      notificationPrefs: this.resolvePrefs(user.notificationPrefs),
    };
  }

  async updateMe(userId: string, dto: UpdateMeDto) {
    await this.prisma.user.update({ where: { id: userId }, data: dto });
    return this.getMe(userId);
  }

  getWorkerProfile(userId: string) {
    return this.prisma.workerProfile.findUnique({ where: { userId } });
  }

  upsertWorkerProfile(userId: string, dto: UpsertWorkerProfileDto) {
    return this.prisma.workerProfile.upsert({ where: { userId }, create: { userId, ...dto }, update: dto });
  }

  /** Worker (or foreman) leaves a company. History stays — it belongs to the worker's portable identity. */
  async leaveCompany(userId: string, membershipId: string) {
    const m = await this.prisma.companyMembership.findFirst({ where: { id: membershipId, userId, status: MembershipStatus.ACTIVE } });
    if (!m) throw notFound('Membership');
    if (m.role === Role.COMPANY_ADMIN) {
      const admins = await this.prisma.companyMembership.count({
        where: { companyId: m.companyId, role: Role.COMPANY_ADMIN, status: MembershipStatus.ACTIVE },
      });
      if (admins <= 1) throw conflict(ErrorCode.LAST_ADMIN, 'The last admin cannot leave the company');
    }
    const open = await this.prisma.shift.count({ where: { workerId: userId, companyId: m.companyId, status: 'OPEN' } });
    if (open) throw conflict(ErrorCode.SHIFT_OPEN, 'Finish the current shift before leaving');
    await this.prisma.$transaction(async (tx) => {
      await tx.companyMembership.update({ where: { id: m.id }, data: { status: MembershipStatus.REMOVED, removedAt: new Date() } });
      await tx.siteAssignment.updateMany({
        where: { companyId: m.companyId, userId, status: 'ACTIVE' },
        data: { status: 'ENDED', endDate: new Date() },
      });
      await this.audit.log(
        { action: AuditAction.MEMBER_LEFT, entityType: 'CompanyMembership', entityId: m.id, companyId: m.companyId, actorUserId: userId },
        tx,
      );
    });
  }

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    await this.prisma.deviceToken.upsert({
      where: { token: dto.token },
      create: { userId, token: dto.token, platform: dto.platform },
      update: { userId, platform: dto.platform },
    });
  }

  resolvePrefs(raw: Prisma.JsonValue): NotificationPrefs {
    const stored = (raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {}) as Record<string, { push?: unknown; inApp?: unknown }>;
    const out: NotificationPrefs = {};
    for (const c of NOTIFICATION_CATEGORIES) {
      const v = stored[c] ?? {};
      out[c] = { push: v.push !== false, inApp: v.inApp !== false };
    }
    return out;
  }

  async updatePrefs(userId: string, dto: NotificationPrefsDto) {
    const next: NotificationPrefs = {};
    for (const [k, v] of Object.entries(dto.prefs)) {
      if (!(NOTIFICATION_CATEGORIES as readonly string[]).includes(k)) throw badRequest(ErrorCode.VALIDATION_FAILED, `Unknown category ${k}`);
      if (typeof v !== 'object' || v === null) throw badRequest(ErrorCode.VALIDATION_FAILED, `Invalid value for ${k}`);
      next[k] = { push: v.push !== false, inApp: v.inApp !== false };
    }
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const merged = { ...this.resolvePrefs(user.notificationPrefs), ...next };
    await this.prisma.user.update({ where: { id: userId }, data: { notificationPrefs: merged } });
    return merged;
  }
}
