import { Injectable } from '@nestjs/common';
import { AssignmentStatus, CompanyMembership, EventSource, Prisma, Role, Shift, ShiftStatus, WorkEventType } from '@prisma/client';
import { AppException, ErrorCode, badRequest, conflict, forbidden, notFound } from '../common/errors';
import { paginated } from '../common/dto/pagination.dto';
import { dateOnly, isoWeekday, localDateString, zonedTimeToUtc } from '../common/utils/time';
import type { RequestMeta } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';
import { AccessService } from '../access/access.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { correctionRule, Flag, localHHMM, mergeFlags, scheduledEnd, verifiedMinutes } from './attendance.rules';
import { AttendanceService, toShiftSummary } from './attendance.service';
import { BulkVerifyDto, CorrectShiftDto, ListShiftsQuery, ManualEventDto, MyShiftsQuery, RejectShiftDto, VerifyShiftDto } from './dto/attendance.dto';

const REVIEWABLE: ShiftStatus[] = [ShiftStatus.CLOSED, ShiftStatus.NEEDS_REVIEW];
/** Open shifts this long after the scheduled end are "pending checkout". */
const PENDING_CHECKOUT_GRACE_MS = 2 * 3600_000;

const shiftListInclude = {
  worker: { select: { id: true, fullName: true, phone: true } },
  site: { select: { id: true, name: true, timezone: true } },
  _count: { select: { disputes: { where: { status: 'OPEN' } } } },
} satisfies Prisma.ShiftInclude;

export type WorkerDayStatus = 'ON_SITE' | 'CHECKED_OUT' | 'ABSENT' | 'NOT_YET' | 'DAY_OFF' | 'PENDING_CHECKOUT';

@Injectable()
export class ShiftsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly attendance: AttendanceService,
  ) {}

  // ───── supervisor: read ─────

  async list(actor: CompanyMembership, q: ListShiftsQuery) {
    const scope = await this.access.siteScope(actor);
    if (q.siteId) await this.access.assertSiteAccess(actor, q.siteId);
    const where: Prisma.ShiftWhereInput = {
      companyId: actor.companyId,
      ...scope,
      ...(q.siteId ? { siteId: q.siteId } : {}),
      ...(q.workerId ? { workerId: q.workerId } : {}),
      ...(q.status?.length ? { status: { in: q.status } } : {}),
      ...(q.flagged ? { NOT: { flags: { isEmpty: true } } } : {}),
    };
    if (q.from || q.to) {
      where.businessDate = { ...(q.from ? { gte: dateOnly(q.from.slice(0, 10)) } : {}), ...(q.to ? { lte: dateOnly(q.to.slice(0, 10)) } : {}) };
    }
    const [items, total] = await this.prisma.$transaction([
      this.prisma.shift.findMany({ where, include: shiftListInclude, orderBy: [{ businessDate: 'desc' }, { startedAt: 'desc' }], skip: q.skip, take: q.limit }),
      this.prisma.shift.count({ where }),
    ]);
    return paginated(items.map((s) => this.present(s)), total, q);
  }

  private present(s: Shift & { worker: { id: string; fullName: string | null; phone: string }; site: { id: string; name: string; timezone: string }; _count?: { disputes: number } }) {
    return {
      ...toShiftSummary(s),
      worker: s.worker,
      site: { id: s.site.id, name: s.site.name },
      originalStartAt: s.originalStartAt,
      originalEndAt: s.originalEndAt,
      breakMinutes: s.breakMinutes,
      reviewNote: s.reviewNote,
      verifiedAt: s.verifiedAt,
      openDisputes: s._count?.disputes ?? 0,
      startLocal: localHHMM(s.startedAt, s.site.timezone),
      endLocal: s.endedAt ? localHHMM(s.endedAt, s.site.timezone) : null,
    };
  }

  private async loadForSupervisor(actor: CompanyMembership, shiftId: string) {
    const shift = await this.prisma.shift.findFirst({ where: { id: shiftId, companyId: actor.companyId }, include: shiftListInclude });
    if (!shift) throw notFound('Shift');
    await this.access.assertSiteAccess(actor, shift.siteId);
    return shift;
  }

  async get(actor: CompanyMembership, shiftId: string) {
    const shift = await this.loadForSupervisor(actor, shiftId);
    return this.detail(shift.id);
  }

  /** Shift with its full, immutable event timeline, disputes and evidence metadata. */
  async detail(shiftId: string) {
    const shift = await this.prisma.shift.findUniqueOrThrow({ where: { id: shiftId }, include: shiftListInclude });
    const [events, disputes, evidence] = await Promise.all([
      this.prisma.workEvent.findMany({ where: { shiftId }, orderBy: [{ occurredAt: 'asc' }, { receivedAt: 'asc' }] }),
      this.prisma.dispute.findMany({ where: { shiftId }, orderBy: { createdAt: 'asc' } }),
      this.prisma.evidence.findMany({
        where: { shiftId, deletedAt: null },
        select: { id: true, kind: true, mimeType: true, comment: true, createdAt: true },
      }),
    ]);
    const actorIds = [...new Set(events.map((e) => e.actorUserId))];
    const actors = await this.prisma.user.findMany({ where: { id: { in: actorIds } }, select: { id: true, fullName: true } });
    return {
      ...this.present(shift),
      events: events.map((e) => ({
        id: e.id,
        type: e.type,
        source: e.source,
        occurredAt: e.occurredAt,
        receivedAt: e.receivedAt,
        actor: actors.find((a) => a.id === e.actorUserId) ?? { id: e.actorUserId, fullName: null },
        latitude: e.latitude,
        longitude: e.longitude,
        accuracyMeters: e.accuracyMeters,
        distanceMeters: e.distanceMeters,
        insideGeofence: e.insideGeofence,
        isMocked: e.isMocked,
        flags: e.flags,
        reason: e.reason,
        metadata: e.metadata,
      })),
      disputes,
      evidence,
    };
  }

  // ───── supervisor: verification ─────

  private assertNotSelf(actor: CompanyMembership, shift: Shift) {
    if (shift.workerId === actor.userId) throw forbidden(ErrorCode.CANNOT_REVIEW_OWN_WORK, 'You cannot review your own work');
  }

  async verify(actor: CompanyMembership, shiftId: string, dto: VerifyShiftDto, meta: RequestMeta) {
    const shift = await this.loadForSupervisor(actor, shiftId);
    this.assertNotSelf(actor, shift);
    if (!REVIEWABLE.includes(shift.status) || !shift.endedAt) {
      throw conflict(
        ErrorCode.SHIFT_NOT_REVIEWABLE,
        shift.status === ShiftStatus.OPEN || !shift.endedAt ? 'The shift has no end time yet — correct it first' : `Shift is ${shift.status}`,
      );
    }
    const breakMinutes = dto.breakMinutes ?? shift.breakMinutes;
    const minutes = verifiedMinutes(shift.workedMinutes, breakMinutes);
    const updated = await this.prisma.$transaction(async (tx) => {
      const r = await tx.shift.updateMany({
        where: { id: shift.id, status: { in: REVIEWABLE } },
        data: {
          status: ShiftStatus.VERIFIED,
          breakMinutes,
          verifiedMinutes: minutes,
          verifiedById: actor.userId,
          verifiedAt: new Date(),
          reviewNote: dto.note ?? null,
        },
      });
      if (r.count === 0) throw conflict(ErrorCode.SHIFT_NOT_REVIEWABLE, 'Shift was changed by someone else');
      await tx.workEvent.create({
        data: {
          companyId: shift.companyId,
          siteId: shift.siteId,
          shiftId: shift.id,
          subjectUserId: shift.workerId,
          actorUserId: actor.userId,
          type: WorkEventType.SHIFT_VERIFIED,
          source: EventSource.FOREMAN_APP,
          occurredAt: new Date(),
          reason: dto.note ?? null,
          metadata: { verifiedMinutes: minutes, breakMinutes },
        },
      });
      await this.audit.log(
        {
          action: AuditAction.SHIFT_VERIFIED,
          entityType: 'Shift',
          entityId: shift.id,
          companyId: shift.companyId,
          actorUserId: actor.userId,
          ip: meta.ip,
          metadata: { verifiedMinutes: minutes, workerId: shift.workerId },
        },
        tx,
      );
      return tx.shift.findUniqueOrThrow({ where: { id: shift.id } });
    });
    await this.notifications.notify([shift.workerId], {
      type: 'SHIFT_VERIFIED',
      category: 'shift',
      companyId: shift.companyId,
      title: 'Ish kuni tasdiqlandi',
      body: `${shift.businessDate.toISOString().slice(0, 10)}: ${formatHours(minutes)} tasdiqlandi. Ish tarixingiz yangilandi.`,
      data: { shiftId: shift.id },
    });
    return toShiftSummary(updated);
  }

  async bulkVerify(actor: CompanyMembership, dto: BulkVerifyDto, meta: RequestMeta) {
    const verified: string[] = [];
    const skipped: { id: string; code: string; message: string }[] = [];
    for (const id of [...new Set(dto.shiftIds)]) {
      try {
        await this.verify(actor, id, {}, meta);
        verified.push(id);
      } catch (e) {
        if (e instanceof AppException) {
          skipped.push({ id, code: e.code, message: String((e.getResponse() as { message?: string }).message ?? '') });
        } else throw e;
      }
    }
    return { verified, skipped };
  }

  async reject(actor: CompanyMembership, shiftId: string, dto: RejectShiftDto, meta: RequestMeta) {
    const shift = await this.loadForSupervisor(actor, shiftId);
    this.assertNotSelf(actor, shift);
    if (!REVIEWABLE.includes(shift.status)) throw conflict(ErrorCode.SHIFT_NOT_REVIEWABLE, `Shift is ${shift.status}`);
    const updated = await this.prisma.$transaction(async (tx) => {
      const r = await tx.shift.updateMany({
        where: { id: shift.id, status: { in: REVIEWABLE } },
        data: { status: ShiftStatus.REJECTED, verifiedMinutes: 0, verifiedById: actor.userId, verifiedAt: new Date(), reviewNote: dto.reason },
      });
      if (r.count === 0) throw conflict(ErrorCode.SHIFT_NOT_REVIEWABLE, 'Shift was changed by someone else');
      await tx.workEvent.create({
        data: {
          companyId: shift.companyId,
          siteId: shift.siteId,
          shiftId: shift.id,
          subjectUserId: shift.workerId,
          actorUserId: actor.userId,
          type: WorkEventType.SHIFT_REJECTED,
          source: EventSource.FOREMAN_APP,
          occurredAt: new Date(),
          reason: dto.reason,
        },
      });
      await this.audit.log(
        { action: AuditAction.SHIFT_REJECTED, entityType: 'Shift', entityId: shift.id, companyId: shift.companyId, actorUserId: actor.userId, ip: meta.ip, metadata: { reason: dto.reason } },
        tx,
      );
      return tx.shift.findUniqueOrThrow({ where: { id: shift.id } });
    });
    await this.notifications.notify([shift.workerId], {
      type: 'SHIFT_REJECTED',
      category: 'shift',
      companyId: shift.companyId,
      title: 'Ish kuni rad etildi',
      body: `${shift.businessDate.toISOString().slice(0, 10)}: ${dto.reason}. Rozi bo'lmasangiz, e'tiroz bildiring.`,
      data: { shiftId: shift.id },
    });
    return toShiftSummary(updated);
  }

  /**
   * Correction never overwrites history silently: the shift projection changes, and a SHIFT_CORRECTED
   * event keeps the previous values, the new values, who corrected and why.
   */
  async correct(actor: CompanyMembership, shiftId: string, dto: CorrectShiftDto, meta: RequestMeta, opts: { disputeId?: string } = {}) {
    const shift = await this.loadForSupervisor(actor, shiftId);
    this.assertNotSelf(actor, shift);
    if (!dto.startedAt && !dto.endedAt) throw badRequest(ErrorCode.VALIDATION_FAILED, 'Provide startedAt and/or endedAt');
    const startedAt = dto.startedAt ? new Date(dto.startedAt) : shift.startedAt;
    const endedAt = dto.endedAt ? new Date(dto.endedAt) : shift.endedAt;
    const rule = correctionRule(startedAt, endedAt, new Date());
    if (!rule.ok) throw badRequest(rule.code, rule.message);

    const breakMinutes = dto.breakMinutes ?? shift.breakMinutes;
    const willVerify = !!dto.verify && !!endedAt;
    const status = !endedAt ? ShiftStatus.OPEN : willVerify ? ShiftStatus.VERIFIED : ShiftStatus.CLOSED;
    const minutes = verifiedMinutes(rule.value.workedMinutes, breakMinutes);
    const site = await this.prisma.site.findUniqueOrThrow({ where: { id: shift.siteId } });
    const businessDate = localDateString(startedAt, site.timezone);

    const updated = await this.prisma.$transaction(async (tx) => {
      if (status === ShiftStatus.OPEN && shift.status !== ShiftStatus.OPEN) {
        const otherOpen = await tx.shift.count({ where: { workerId: shift.workerId, status: ShiftStatus.OPEN, id: { not: shift.id } } });
        if (otherOpen) throw conflict(ErrorCode.ALREADY_CHECKED_IN, 'The worker already has an open shift');
      }
      const u = await tx.shift.update({
        where: { id: shift.id },
        data: {
          startedAt,
          endedAt,
          businessDate: dateOnly(businessDate),
          workedMinutes: rule.value.workedMinutes,
          breakMinutes,
          status,
          flags: mergeFlags(shift.flags, [Flag.CORRECTED]),
          verifiedMinutes: willVerify ? minutes : 0,
          verifiedById: willVerify ? actor.userId : null,
          verifiedAt: willVerify ? new Date() : null,
          reviewNote: dto.reason,
        },
      });
      await tx.workEvent.create({
        data: {
          companyId: shift.companyId,
          siteId: shift.siteId,
          shiftId: shift.id,
          subjectUserId: shift.workerId,
          actorUserId: actor.userId,
          type: WorkEventType.SHIFT_CORRECTED,
          source: EventSource.FOREMAN_APP,
          occurredAt: new Date(),
          reason: dto.reason,
          entityType: opts.disputeId ? 'Dispute' : null,
          entityId: opts.disputeId ?? null,
          metadata: {
            from: { startedAt: shift.startedAt, endedAt: shift.endedAt, status: shift.status, workedMinutes: shift.workedMinutes },
            to: { startedAt, endedAt, status, workedMinutes: rule.value.workedMinutes },
          },
        },
      });
      if (willVerify) {
        await tx.workEvent.create({
          data: {
            companyId: shift.companyId,
            siteId: shift.siteId,
            shiftId: shift.id,
            subjectUserId: shift.workerId,
            actorUserId: actor.userId,
            type: WorkEventType.SHIFT_VERIFIED,
            source: EventSource.FOREMAN_APP,
            occurredAt: new Date(),
            metadata: { verifiedMinutes: minutes, breakMinutes },
          },
        });
      }
      await this.audit.log(
        {
          action: AuditAction.SHIFT_CORRECTED,
          entityType: 'Shift',
          entityId: shift.id,
          companyId: shift.companyId,
          actorUserId: actor.userId,
          ip: meta.ip,
          metadata: { reason: dto.reason, from: { startedAt: shift.startedAt, endedAt: shift.endedAt }, to: { startedAt, endedAt }, verified: willVerify },
        },
        tx,
      );
      return u;
    });
    await this.notifications.notify([shift.workerId], {
      type: 'SHIFT_CORRECTED',
      category: 'shift',
      companyId: shift.companyId,
      title: 'Ish vaqti tuzatildi',
      body: `${businessDate}: ${localHHMM(startedAt, site.timezone)}–${endedAt ? localHHMM(endedAt, site.timezone) : '…'}. Sabab: ${dto.reason}`,
      data: { shiftId: shift.id },
    });
    return toShiftSummary(updated);
  }

  /** No-phone / broken-phone scenario: supervisor records the event for the worker (flagged MANUAL_ENTRY). */
  async manual(actor: CompanyMembership, dto: ManualEventDto) {
    await this.access.assertSiteAccess(actor, dto.siteId);
    await this.access.assertWorkerAccess(actor, dto.workerId);
    if (dto.workerId === actor.userId) throw forbidden(ErrorCode.CANNOT_REVIEW_OWN_WORK, 'You cannot record your own attendance manually');
    const result = await this.attendance.apply({
      actorUserId: actor.userId,
      subjectUserId: dto.workerId,
      source: EventSource.FOREMAN_APP,
      type: dto.type,
      siteId: dto.siteId,
      occurredAt: new Date(dto.occurredAt),
      clientEventId: dto.clientEventId,
      note: dto.reason,
      requireLocation: false,
    });
    if (result.status === 'REJECTED' || result.status === 'RETRY') {
      throw new AppException((result.code ?? ErrorCode.CONFLICT) as ErrorCode, result.message ?? 'Rejected', 409, result.details);
    }
    return result;
  }

  // ───── dashboard: "10 seconds" view for foremen ─────

  async dashboard(actor: CompanyMembership, siteId?: string) {
    const scope = await this.access.supervisedSiteIds(actor);
    if (siteId) await this.access.assertSiteAccess(actor, siteId);
    const sites = await this.prisma.site.findMany({
      where: {
        companyId: actor.companyId,
        deletedAt: null,
        status: 'ACTIVE',
        ...(siteId ? { id: siteId } : scope !== null ? { id: { in: scope } } : {}),
      },
      orderBy: { name: 'asc' },
    });
    const siteIds = sites.map((s) => s.id);
    const now = new Date();

    const assignments = await this.prisma.siteAssignment.findMany({
      where: { siteId: { in: siteIds }, status: AssignmentStatus.ACTIVE, role: Role.WORKER },
      include: { user: { select: { id: true, fullName: true, phone: true } } },
    });
    const dates = [...new Set(sites.map((s) => localDateString(now, s.timezone)))];
    const [todayShifts, openShifts, awaitingVerification, openDisputes, tasksAwaitingReview] = await Promise.all([
      this.prisma.shift.findMany({ where: { siteId: { in: siteIds }, businessDate: { in: dates.map(dateOnly) } } }),
      this.prisma.shift.findMany({ where: { siteId: { in: siteIds }, status: ShiftStatus.OPEN } }),
      this.prisma.shift.count({ where: { siteId: { in: siteIds }, status: { in: REVIEWABLE } } }),
      this.prisma.dispute.count({ where: { companyId: actor.companyId, status: 'OPEN', shift: { siteId: { in: siteIds } } } }),
      this.prisma.task.count({ where: { siteId: { in: siteIds }, status: 'SUBMITTED' } }),
    ]);

    const siteViews = sites.map((site) => {
      const today = localDateString(now, site.timezone);
      const isWorkDay = site.workDays.includes(isoWeekday(today));
      const lateCutoff = new Date(zonedTimeToUtc(today, site.shiftStart, site.timezone).getTime() + site.lateGraceMinutes * 60_000);
      const workers = assignments
        .filter((a) => a.siteId === site.id)
        .map((a) => {
          const shifts = todayShifts.filter((s) => s.siteId === site.id && s.workerId === a.userId && s.businessDate.toISOString().slice(0, 10) === today);
          const open = openShifts.find((s) => s.siteId === site.id && s.workerId === a.userId);
          const latest = shifts[shifts.length - 1];
          let status: WorkerDayStatus;
          if (open) {
            const openDate = open.businessDate.toISOString().slice(0, 10);
            const overdue = openDate < today || now.getTime() > scheduledEnd(site, openDate).getTime() + PENDING_CHECKOUT_GRACE_MS;
            status = overdue ? 'PENDING_CHECKOUT' : 'ON_SITE';
          } else if (latest) status = 'CHECKED_OUT';
          else if (!isWorkDay) status = 'DAY_OFF';
          else status = now > lateCutoff ? 'ABSENT' : 'NOT_YET';
          const shownShift = open ?? latest ?? null;
          return {
            userId: a.userId,
            fullName: a.user.fullName,
            phone: a.user.phone,
            isResident: a.isResident,
            status,
            isLate: shifts.some((s) => s.isLate) || (open?.isLate ?? false),
            lateMinutes: Math.max(0, ...shifts.map((s) => s.lateMinutes), open?.lateMinutes ?? 0),
            shift: shownShift ? { ...toShiftSummary(shownShift), startLocal: localHHMM(shownShift.startedAt, site.timezone), endLocal: shownShift.endedAt ? localHHMM(shownShift.endedAt, site.timezone) : null } : null,
          };
        })
        .sort((x, y) => ORDER[x.status] - ORDER[y.status] || (x.fullName ?? '').localeCompare(y.fullName ?? ''));
      const count = (st: WorkerDayStatus) => workers.filter((w) => w.status === st).length;
      return {
        site: { id: site.id, name: site.name, shiftStart: site.shiftStart, shiftEnd: site.shiftEnd, timezone: site.timezone },
        date: today,
        isWorkDay,
        totals: {
          assigned: workers.length,
          present: count('ON_SITE') + count('CHECKED_OUT') + count('PENDING_CHECKOUT'),
          onSite: count('ON_SITE'),
          checkedOut: count('CHECKED_OUT'),
          late: workers.filter((w) => w.isLate).length,
          absent: count('ABSENT'),
          notYet: count('NOT_YET'),
          pendingCheckout: count('PENDING_CHECKOUT'),
        },
        workers,
      };
    });

    const sum = (k: keyof (typeof siteViews)[number]['totals']) => siteViews.reduce((acc, s) => acc + s.totals[k], 0);
    return {
      generatedAt: now,
      totals: {
        assigned: sum('assigned'),
        present: sum('present'),
        onSite: sum('onSite'),
        late: sum('late'),
        absent: sum('absent'),
        notYet: sum('notYet'),
        pendingCheckout: sum('pendingCheckout'),
        awaitingVerification,
        openDisputes,
        tasksAwaitingReview,
      },
      sites: siteViews,
    };
  }

  // ───── worker: own history ─────

  async myShifts(userId: string, q: MyShiftsQuery) {
    const where: Prisma.ShiftWhereInput = { workerId: userId };
    if (q.from || q.to) {
      where.businessDate = { ...(q.from ? { gte: dateOnly(q.from.slice(0, 10)) } : {}), ...(q.to ? { lte: dateOnly(q.to.slice(0, 10)) } : {}) };
    }
    const [items, total, agg] = await this.prisma.$transaction([
      this.prisma.shift.findMany({
        where,
        include: { site: { select: { id: true, name: true, timezone: true } }, company: { select: { id: true, name: true } } },
        orderBy: [{ businessDate: 'desc' }, { startedAt: 'desc' }],
        skip: q.skip,
        take: q.limit,
      }),
      this.prisma.shift.count({ where }),
      this.prisma.shift.aggregate({ where: { ...where, status: ShiftStatus.VERIFIED }, _sum: { verifiedMinutes: true }, _count: { _all: true } }),
    ]);
    return {
      ...paginated(
        items.map((s) => ({
          ...toShiftSummary(s),
          site: { id: s.site.id, name: s.site.name },
          company: s.company,
          reviewNote: s.reviewNote,
          startLocal: localHHMM(s.startedAt, s.site.timezone),
          endLocal: s.endedAt ? localHHMM(s.endedAt, s.site.timezone) : null,
        })),
        total,
        q,
      ),
      summary: { verifiedShifts: agg._count._all, verifiedMinutes: agg._sum.verifiedMinutes ?? 0 },
    };
  }

  async myShift(userId: string, shiftId: string) {
    const s = await this.prisma.shift.findFirst({ where: { id: shiftId, workerId: userId } });
    if (!s) throw notFound('Shift');
    const d = await this.detail(s.id);
    // Workers see their own timeline but not supervisors' phone numbers.
    return { ...d, worker: { id: d.worker.id, fullName: d.worker.fullName } };
  }
}

const ORDER: Record<WorkerDayStatus, number> = { PENDING_CHECKOUT: 0, ABSENT: 1, NOT_YET: 2, ON_SITE: 3, CHECKED_OUT: 4, DAY_OFF: 5 };

export function formatHours(minutes: number) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m ? `${h} soat ${m} daqiqa` : `${h} soat`;
}
