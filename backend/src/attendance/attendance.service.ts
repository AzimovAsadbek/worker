import { HttpException, Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { AssignmentStatus, EventSource, MembershipStatus, Prisma, Role, Shift, ShiftStatus, SiteStatus, WorkEventType } from '@prisma/client';
import { AppException, ErrorCode } from '../common/errors';
import { dateOnly, localDateString } from '../common/utils/time';
import { PrismaService } from '../prisma/prisma.service';
import { AuditAction, AuditService } from '../audit/audit.service';
import {
  assessLocation,
  checkInLocationRule,
  checkOutRule,
  checkTimestamp,
  computeLateness,
  Flag,
  GeoPoint,
  isImpossibleTravel,
  isStaleOpenShift,
  mergeFlags,
  RuleResult,
  RULES,
} from './attendance.rules';
import { AttendanceEventType, SyncEventDto } from './dto/attendance.dto';

export interface EventInput {
  actorUserId: string;
  subjectUserId: string;
  source: EventSource;
  type: AttendanceEventType;
  siteId: string;
  occurredAt: Date;
  clientEventId?: string;
  point?: GeoPoint | null;
  isMocked?: boolean | null;
  deviceId?: string | null;
  note?: string | null;
  /** Worker self-service requires location for check-in; supervisor manual entries do not. */
  requireLocation: boolean;
}

export type SyncStatus = 'ACCEPTED' | 'DUPLICATE' | 'REJECTED' | 'RETRY';

export interface SyncResult {
  clientEventId: string;
  status: SyncStatus;
  code?: string;
  message?: string;
  details?: Record<string, unknown>;
  eventId?: string;
  shift?: ShiftSummary | null;
}

export interface ShiftSummary {
  id: string;
  siteId: string;
  companyId: string;
  businessDate: string;
  status: ShiftStatus;
  startedAt: Date;
  endedAt: Date | null;
  workedMinutes: number;
  verifiedMinutes: number;
  isLate: boolean;
  lateMinutes: number;
  isResident: boolean;
  flags: string[];
}

export const toShiftSummary = (s: Shift): ShiftSummary => ({
  id: s.id,
  siteId: s.siteId,
  companyId: s.companyId,
  businessDate: s.businessDate.toISOString().slice(0, 10),
  status: s.status,
  startedAt: s.startedAt,
  endedAt: s.endedAt,
  workedMinutes: s.workedMinutes,
  verifiedMinutes: s.verifiedMinutes,
  isLate: s.isLate,
  lateMinutes: s.lateMinutes,
  isResident: s.isResident,
  flags: s.flags,
});

class RuleRejection extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly details?: Record<string, unknown>,
    public readonly shift?: Shift | null,
  ) {
    super(message);
  }
}

function unwrap<T>(r: RuleResult<T>): T {
  if (!r.ok) throw new RuleRejection(r.code, r.message, r.details);
  return r.value;
}

/**
 * Ingests attendance events (check-in / check-out). Each event is processed in its own SERIALIZABLE
 * transaction: the WorkEvent row (append-only), the Shift projection and the audit entry commit together.
 */
@Injectable()
export class AttendanceService {
  private readonly logger = new Logger(AttendanceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /** Offline sync entry point. Events are applied in chronological order; processing stops at the first transient failure. */
  async sync(userId: string, events: SyncEventDto[]): Promise<{ results: SyncResult[] }> {
    const ordered = [...events].sort((a, b) => Date.parse(a.occurredAt) - Date.parse(b.occurredAt));
    const results: SyncResult[] = [];
    let halted = false;
    for (const e of ordered) {
      if (halted) {
        results.push({ clientEventId: e.clientEventId, status: 'RETRY', code: 'PREVIOUS_EVENT_PENDING', message: 'Retry after the previous event' });
        continue;
      }
      const hasPoint = e.latitude !== undefined && e.longitude !== undefined;
      const r = await this.apply({
        actorUserId: userId,
        subjectUserId: userId,
        source: EventSource.MOBILE_APP,
        type: e.type,
        siteId: e.siteId,
        occurredAt: new Date(e.occurredAt),
        clientEventId: e.clientEventId,
        point: hasPoint ? { latitude: e.latitude!, longitude: e.longitude!, accuracyMeters: e.accuracy ?? null } : null,
        isMocked: e.isMocked ?? null,
        deviceId: e.deviceId ?? null,
        note: e.note ?? null,
        requireLocation: true,
      });
      results.push(r);
      if (r.status === 'RETRY') halted = true;
    }
    // Keep response in the order the client sent.
    const byId = new Map(results.map((r) => [r.clientEventId, r]));
    return { results: events.map((e) => byId.get(e.clientEventId)!) };
  }

  async apply(input: EventInput): Promise<SyncResult> {
    const clientEventId = input.clientEventId ?? `srv-${randomUUID()}`;
    const duplicate = await this.findDuplicate(input.actorUserId, clientEventId);
    if (duplicate) return duplicate;

    try {
      const { eventId, shift } = await this.prisma.serializable((tx) =>
        input.type === 'WORK_STARTED' ? this.startWork(tx, input, clientEventId) : this.endWork(tx, input, clientEventId),
      );
      return { clientEventId, status: 'ACCEPTED', eventId, shift: toShiftSummary(shift) };
    } catch (e) {
      if (e instanceof RuleRejection) {
        return { clientEventId, status: 'REJECTED', code: e.code, message: e.message, details: e.details, shift: e.shift ? toShiftSummary(e.shift) : null };
      }
      if (e instanceof AppException) {
        const body = e.getResponse() as { message?: string };
        return { clientEventId, status: 'REJECTED', code: e.code, message: body.message };
      }
      const code = (e as { code?: string }).code;
      if (code === 'P2002') {
        // Unique race: same clientEventId processed concurrently, or a second OPEN shift attempt.
        const dup = await this.findDuplicate(input.actorUserId, clientEventId);
        if (dup) return dup;
        return { clientEventId, status: 'REJECTED', code: ErrorCode.ALREADY_CHECKED_IN, message: 'You have already started work' };
      }
      if (e instanceof HttpException) throw e;
      this.logger.error({ err: e, type: input.type }, 'Attendance event failed');
      return { clientEventId, status: 'RETRY', code: ErrorCode.INTERNAL, message: 'Temporary server error, will retry' };
    }
  }

  private async findDuplicate(actorUserId: string, clientEventId: string): Promise<SyncResult | null> {
    const existing = await this.prisma.workEvent.findUnique({
      where: { actorUserId_clientEventId: { actorUserId, clientEventId } },
      include: { shift: true },
    });
    if (!existing) return null;
    return { clientEventId, status: 'DUPLICATE', eventId: existing.id, shift: existing.shift ? toShiftSummary(existing.shift) : null };
  }

  /** Shared eligibility: active user, active membership, active site, active WORKER assignment. */
  private async loadContext(tx: Prisma.TransactionClient, input: EventInput) {
    const site = await tx.site.findFirst({ where: { id: input.siteId, deletedAt: null } });
    if (!site) throw new RuleRejection(ErrorCode.NOT_ASSIGNED_TO_SITE, 'Site not found or not assigned to you');
    const membership = await tx.companyMembership.findUnique({
      where: { companyId_userId: { companyId: site.companyId, userId: input.subjectUserId } },
    });
    const assignment = await tx.siteAssignment.findFirst({
      where: { siteId: site.id, userId: input.subjectUserId, status: AssignmentStatus.ACTIVE, role: Role.WORKER },
    });
    if (!membership || !assignment) throw new RuleRejection(ErrorCode.NOT_ASSIGNED_TO_SITE, 'You are not assigned to this site');
    if (membership.status !== MembershipStatus.ACTIVE) throw new RuleRejection(ErrorCode.MEMBERSHIP_INACTIVE, 'Your membership in this company is not active');
    if (site.status !== SiteStatus.ACTIVE) throw new RuleRejection(ErrorCode.SITE_INACTIVE, 'This site is not active');
    return { site, assignment };
  }

  private async anomalyFlags(tx: Prisma.TransactionClient, input: EventInput): Promise<Flag[]> {
    const flags: Flag[] = [];
    if (input.point) {
      const prev = await tx.workEvent.findFirst({
        where: {
          subjectUserId: input.subjectUserId,
          latitude: { not: null },
          occurredAt: { gte: new Date(input.occurredAt.getTime() - 24 * 3600_000), lte: input.occurredAt },
        },
        orderBy: { occurredAt: 'desc' },
      });
      if (
        prev &&
        isImpossibleTravel(
          { point: { latitude: prev.latitude!, longitude: prev.longitude!, accuracyMeters: prev.accuracyMeters }, at: prev.occurredAt },
          { point: input.point, at: input.occurredAt },
        )
      ) {
        flags.push(Flag.IMPOSSIBLE_TRAVEL);
      }
    }
    if (input.deviceId) {
      const shared = await tx.workEvent.count({
        where: {
          deviceId: input.deviceId,
          subjectUserId: { not: input.subjectUserId },
          occurredAt: {
            gte: new Date(input.occurredAt.getTime() - RULES.SHARED_DEVICE_WINDOW_MS),
            lte: new Date(input.occurredAt.getTime() + RULES.SHARED_DEVICE_WINDOW_MS),
          },
        },
      });
      if (shared) flags.push(Flag.SHARED_DEVICE);
    }
    if (input.source !== EventSource.MOBILE_APP) flags.push(Flag.MANUAL_ENTRY);
    return flags;
  }

  private eventData(input: EventInput, clientEventId: string, extra: Partial<Prisma.WorkEventUncheckedCreateInput>) {
    return {
      clientEventId,
      subjectUserId: input.subjectUserId,
      actorUserId: input.actorUserId,
      source: input.source,
      occurredAt: input.occurredAt,
      latitude: input.point?.latitude ?? null,
      longitude: input.point?.longitude ?? null,
      accuracyMeters: input.point?.accuracyMeters ?? null,
      isMocked: input.isMocked ?? null,
      deviceId: input.deviceId ?? null,
      reason: input.note ?? null,
      ...extra,
    } as Prisma.WorkEventUncheckedCreateInput;
  }

  private async startWork(tx: Prisma.TransactionClient, input: EventInput, clientEventId: string) {
    const now = new Date();
    const tsFlags = unwrap(checkTimestamp(input.occurredAt, now));
    const { site, assignment } = await this.loadContext(tx, input);

    // One open shift per worker (across all companies).
    const open = await tx.shift.findFirst({ where: { workerId: input.subjectUserId, status: ShiftStatus.OPEN } });
    if (open) {
      const openSite = open.siteId === site.id ? site : await tx.site.findUniqueOrThrow({ where: { id: open.siteId } });
      const stale = isStaleOpenShift(
        { startedAt: open.startedAt, businessDate: open.businessDate.toISOString().slice(0, 10) },
        input.occurredAt,
        openSite.timezone,
      );
      if (!stale) throw new RuleRejection(ErrorCode.ALREADY_CHECKED_IN, 'You have already started work', { shiftId: open.id }, open);
      await this.autoCloseMissedCheckout(tx, open, input);
    }

    let locationFlags: Flag[] = [];
    let distance: number | null = null;
    let inside: boolean | null = null;
    if (input.requireLocation || input.point) {
      if (input.requireLocation) {
        const a = unwrap(checkInLocationRule(site, input.point ?? null, input.isMocked));
        locationFlags = a.flags;
        distance = a.distanceMeters;
        inside = a.verdict !== 'OUTSIDE';
      } else if (input.point) {
        const a = assessLocation(site, input.point, input.isMocked);
        locationFlags = a.flags;
        distance = a.distanceMeters;
        inside = a.verdict !== 'OUTSIDE';
      }
    } else {
      locationFlags = [Flag.NO_LOCATION];
    }
    const anomalies = await this.anomalyFlags(tx, input);
    const late = computeLateness(site, input.occurredAt);
    const flags = mergeFlags(tsFlags, locationFlags, anomalies);

    const shift = await tx.shift.create({
      data: {
        companyId: site.companyId,
        siteId: site.id,
        workerId: input.subjectUserId,
        businessDate: dateOnly(late.businessDate),
        startedAt: input.occurredAt,
        originalStartAt: input.occurredAt,
        status: ShiftStatus.OPEN,
        isResident: assignment.isResident,
        isLate: late.isLate,
        lateMinutes: late.lateMinutes,
        flags,
      },
    });
    const event = await tx.workEvent.create({
      data: this.eventData(input, clientEventId, {
        companyId: site.companyId,
        siteId: site.id,
        shiftId: shift.id,
        type: WorkEventType.WORK_STARTED,
        distanceMeters: distance,
        insideGeofence: inside,
        flags,
        metadata: { isResident: assignment.isResident, isWorkDay: late.isWorkDay, lateMinutes: late.lateMinutes },
      }),
    });
    await this.audit.log(
      {
        action: AuditAction.WORK_STARTED,
        entityType: 'Shift',
        entityId: shift.id,
        companyId: site.companyId,
        actorUserId: input.actorUserId,
        metadata: { source: input.source, flags, workerId: input.subjectUserId },
      },
      tx,
    );
    return { eventId: event.id, shift };
  }

  /** Missed checkout: close with 0 counted minutes and require review. Never assume the worker worked. */
  private async autoCloseMissedCheckout(tx: Prisma.TransactionClient, open: Shift, input: EventInput) {
    const flags = mergeFlags(open.flags, [Flag.MISSED_CHECKOUT]);
    await tx.shift.update({
      where: { id: open.id },
      data: { status: ShiftStatus.NEEDS_REVIEW, flags, workedMinutes: 0, verifiedMinutes: 0 },
    });
    await tx.workEvent.create({
      data: {
        companyId: open.companyId,
        siteId: open.siteId,
        shiftId: open.id,
        subjectUserId: open.workerId,
        actorUserId: input.subjectUserId,
        type: WorkEventType.SHIFT_AUTO_CLOSED,
        source: EventSource.SYSTEM,
        occurredAt: input.occurredAt,
        reason: 'Missed checkout: new check-in on a later day',
        flags: [Flag.MISSED_CHECKOUT],
      },
    });
    await this.audit.log(
      { action: AuditAction.SHIFT_AUTO_CLOSED, entityType: 'Shift', entityId: open.id, companyId: open.companyId, metadata: { reason: 'MISSED_CHECKOUT' } },
      tx,
    );
  }

  private async endWork(tx: Prisma.TransactionClient, input: EventInput, clientEventId: string) {
    const now = new Date();
    const tsFlags = unwrap(checkTimestamp(input.occurredAt, now));
    const { site } = await this.loadContext(tx, input);

    const open = await tx.shift.findFirst({ where: { workerId: input.subjectUserId, status: ShiftStatus.OPEN } });
    if (!open) throw new RuleRejection(ErrorCode.NO_OPEN_SHIFT, 'You have not started work yet');
    if (open.siteId !== site.id) {
      throw new RuleRejection(ErrorCode.NO_OPEN_SHIFT, 'Your open shift is on another site', { openSiteId: open.siteId }, open);
    }
    const outcome = unwrap(checkOutRule(open.startedAt, input.occurredAt));

    let locationFlags: Flag[] = [];
    let distance: number | null = null;
    let inside: boolean | null = null;
    if (input.point) {
      const a = assessLocation(site, input.point, input.isMocked);
      // Resident workers are always "inside" — location at checkout carries no signal for them.
      locationFlags = open.isResident ? a.flags.filter((f) => f === Flag.MOCK_LOCATION) : a.flags;
      distance = a.distanceMeters;
      inside = a.verdict !== 'OUTSIDE';
    } else if (input.source === EventSource.MOBILE_APP) {
      locationFlags = [Flag.NO_LOCATION];
    }
    const anomalies = await this.anomalyFlags(tx, input);
    const eventFlags = mergeFlags(tsFlags, locationFlags, anomalies, outcome.flags);
    const shiftFlags = mergeFlags(open.flags, eventFlags);

    const shift = await tx.shift.update({
      where: { id: open.id },
      data: {
        endedAt: input.occurredAt,
        originalEndAt: input.occurredAt,
        workedMinutes: outcome.workedMinutes,
        status: outcome.needsReview ? ShiftStatus.NEEDS_REVIEW : ShiftStatus.CLOSED,
        flags: shiftFlags,
      },
    });
    const event = await tx.workEvent.create({
      data: this.eventData(input, clientEventId, {
        companyId: site.companyId,
        siteId: site.id,
        shiftId: shift.id,
        type: WorkEventType.WORK_ENDED,
        distanceMeters: distance,
        insideGeofence: inside,
        flags: eventFlags,
        metadata: { workedMinutes: outcome.workedMinutes },
      }),
    });
    await this.audit.log(
      {
        action: AuditAction.WORK_ENDED,
        entityType: 'Shift',
        entityId: shift.id,
        companyId: site.companyId,
        actorUserId: input.actorUserId,
        metadata: { source: input.source, workedMinutes: outcome.workedMinutes, flags: eventFlags, workerId: input.subjectUserId },
      },
      tx,
    );
    return { eventId: event.id, shift };
  }

  /** Worker's "Today" screen: where do I work, did I start, did I finish. */
  async today(userId: string) {
    const assignments = await this.prisma.siteAssignment.findMany({
      where: {
        userId,
        role: Role.WORKER,
        status: AssignmentStatus.ACTIVE,
        site: { deletedAt: null, company: { deletedAt: null, memberships: { some: { userId, status: MembershipStatus.ACTIVE } } } },
      },
      include: {
        site: {
          select: {
            id: true,
            name: true,
            address: true,
            latitude: true,
            longitude: true,
            radiusMeters: true,
            timezone: true,
            shiftStart: true,
            shiftEnd: true,
            lateGraceMinutes: true,
            workDays: true,
            status: true,
            company: { select: { id: true, name: true } },
            project: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: { startDate: 'asc' },
    });
    const openShift = await this.prisma.shift.findFirst({
      where: { workerId: userId, status: ShiftStatus.OPEN },
      include: { site: { select: { id: true, name: true, timezone: true } } },
    });
    const tz = assignments[0]?.site.timezone ?? openShift?.site.timezone ?? 'Asia/Tashkent';
    const todayStr = localDateString(new Date(), tz);
    const todayShifts = await this.prisma.shift.findMany({
      where: { workerId: userId, businessDate: dateOnly(todayStr) },
      include: { site: { select: { id: true, name: true } } },
      orderBy: { startedAt: 'asc' },
    });
    const openTasks = await this.prisma.task.count({
      where: { assigneeId: userId, status: { in: ['ASSIGNED', 'IN_PROGRESS', 'CHANGES_REQUESTED'] } },
    });
    return {
      date: todayStr,
      serverTime: new Date(),
      assignments: assignments.map((a) => ({
        assignmentId: a.id,
        isResident: a.isResident,
        site: { ...a.site, company: undefined, project: undefined, projectName: a.site.project.name },
        company: a.site.company,
      })),
      openShift: openShift
        ? { ...toShiftSummary(openShift), siteName: openShift.site.name, isStale: isStaleOpenShift({ startedAt: openShift.startedAt, businessDate: openShift.businessDate.toISOString().slice(0, 10) }, new Date(), openShift.site.timezone) }
        : null,
      todayShifts: todayShifts.map((s) => ({ ...toShiftSummary(s), siteName: s.site.name })),
      openTasks,
    };
  }
}
