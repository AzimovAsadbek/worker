/**
 * Pure attendance rules — no I/O, fully unit-tested (attendance.rules.spec.ts).
 * Principle: GPS is evidence, not truth. Presence on site never equals work time.
 */
import { ErrorCode } from '../common/errors';
import { distanceMeters, geofenceVerdict, GeofenceVerdict } from '../common/utils/geo';
import { addDays, isoWeekday, localDateString, localParts, minutesBetween, zonedTimeToUtc } from '../common/utils/time';

export const RULES = {
  /** Device clock may be ahead of the server by at most this much. */
  MAX_FUTURE_SKEW_MS: 5 * 60_000,
  /** Offline events older than this are refused (a supervisor can still enter them manually). */
  MAX_EVENT_AGE_MS: 72 * 3600_000,
  /** GPS accuracy worse than this is flagged. */
  LOW_ACCURACY_M: 100,
  /** Travel faster than this between two located events is flagged. */
  MAX_SPEED_KMH: 150,
  /** Shifts longer than this are not auto-accepted; they need review. */
  LONG_SHIFT_MINUTES: 16 * 60,
  /** Hard ceiling for corrected shifts. */
  MAX_SHIFT_MINUTES: 24 * 60,
  /** An open shift older than this is treated as a missed checkout when the worker checks in again. */
  STALE_OPEN_SHIFT_MS: 20 * 3600_000,
  /** …or this long once a new business day has started (night shifts stay valid). */
  NEW_DAY_STALE_MS: 12 * 3600_000,
  /** Event synced this long after it happened is marked (informational, typical for offline). */
  LATE_SYNC_MS: 30 * 60_000,
  /** Another user's event from the same device within this window → SHARED_DEVICE flag. */
  SHARED_DEVICE_WINDOW_MS: 12 * 3600_000,
} as const;

export const Flag = {
  OUTSIDE_GEOFENCE: 'OUTSIDE_GEOFENCE',
  GEOFENCE_UNCERTAIN: 'GEOFENCE_UNCERTAIN',
  LOW_ACCURACY: 'LOW_ACCURACY',
  MOCK_LOCATION: 'MOCK_LOCATION',
  IMPOSSIBLE_TRAVEL: 'IMPOSSIBLE_TRAVEL',
  SHARED_DEVICE: 'SHARED_DEVICE',
  LATE_SYNC: 'LATE_SYNC',
  LONG_SHIFT: 'LONG_SHIFT',
  MISSED_CHECKOUT: 'MISSED_CHECKOUT',
  MANUAL_ENTRY: 'MANUAL_ENTRY',
  NO_LOCATION: 'NO_LOCATION',
  CORRECTED: 'CORRECTED',
} as const;
export type Flag = (typeof Flag)[keyof typeof Flag];

export interface SiteRules {
  latitude: number;
  longitude: number;
  radiusMeters: number;
  timezone: string;
  shiftStart: string;
  shiftEnd: string;
  lateGraceMinutes: number;
  workDays: number[];
}

export interface GeoPoint {
  latitude: number;
  longitude: number;
  accuracyMeters?: number | null;
}

export type RuleResult<T> = { ok: true; value: T } | { ok: false; code: ErrorCode; message: string; details?: Record<string, unknown> };

// ───── timestamps ─────

export function checkTimestamp(occurredAt: Date, receivedAt: Date): RuleResult<Flag[]> {
  if (Number.isNaN(occurredAt.getTime())) return { ok: false, code: ErrorCode.VALIDATION_FAILED, message: 'Invalid timestamp' };
  const delta = occurredAt.getTime() - receivedAt.getTime();
  if (delta > RULES.MAX_FUTURE_SKEW_MS) {
    return { ok: false, code: ErrorCode.TIMESTAMP_IN_FUTURE, message: 'Event time is in the future — check the phone clock', details: { skewSeconds: Math.round(delta / 1000) } };
  }
  if (-delta > RULES.MAX_EVENT_AGE_MS) {
    return { ok: false, code: ErrorCode.EVENT_TOO_OLD, message: 'Event is too old to be accepted automatically. Ask your foreman to enter it.' };
  }
  return { ok: true, value: -delta > RULES.LATE_SYNC_MS ? [Flag.LATE_SYNC] : [] };
}

// ───── location ─────

export interface LocationAssessment {
  distanceMeters: number;
  verdict: GeofenceVerdict;
  flags: Flag[];
}

export function assessLocation(site: SiteRules, point: GeoPoint, isMocked?: boolean | null): LocationAssessment {
  const distance = distanceMeters(site.latitude, site.longitude, point.latitude, point.longitude);
  const verdict = geofenceVerdict(distance, site.radiusMeters, point.accuracyMeters);
  const flags: Flag[] = [];
  if (verdict === 'UNCERTAIN') flags.push(Flag.GEOFENCE_UNCERTAIN);
  if (verdict === 'OUTSIDE') flags.push(Flag.OUTSIDE_GEOFENCE);
  if ((point.accuracyMeters ?? 0) > RULES.LOW_ACCURACY_M) flags.push(Flag.LOW_ACCURACY);
  if (isMocked) flags.push(Flag.MOCK_LOCATION);
  return { distanceMeters: Math.round(distance), verdict, flags };
}

/** Check-in requires a location that is not clearly outside the geofence. */
export function checkInLocationRule(site: SiteRules, point: GeoPoint | null, isMocked?: boolean | null): RuleResult<LocationAssessment> {
  if (!point) return { ok: false, code: ErrorCode.LOCATION_REQUIRED, message: 'Location is required to start work' };
  const a = assessLocation(site, point, isMocked);
  if (a.verdict === 'OUTSIDE') {
    return {
      ok: false,
      code: ErrorCode.OUTSIDE_GEOFENCE,
      message: 'You are outside the site area',
      details: { distanceMeters: a.distanceMeters, radiusMeters: site.radiusMeters },
    };
  }
  return { ok: true, value: a };
}

export function isImpossibleTravel(prev: { point: GeoPoint; at: Date }, cur: { point: GeoPoint; at: Date }): boolean {
  const meters = distanceMeters(prev.point.latitude, prev.point.longitude, cur.point.latitude, cur.point.longitude);
  // Discount GPS error so two noisy fixes a minute apart are not "teleports".
  const slack = (prev.point.accuracyMeters ?? 0) + (cur.point.accuracyMeters ?? 0) + 200;
  const effective = Math.max(0, meters - slack);
  if (effective === 0) return false;
  const hours = Math.abs(cur.at.getTime() - prev.at.getTime()) / 3600_000;
  if (hours < 1 / 3600) return true; // moved hundreds of meters in < 1 s
  return effective / 1000 / hours > RULES.MAX_SPEED_KMH;
}

// ───── schedule ─────

export interface Lateness {
  businessDate: string;
  isWorkDay: boolean;
  isLate: boolean;
  lateMinutes: number;
}

export function computeLateness(site: SiteRules, startedAt: Date): Lateness {
  const businessDate = localDateString(startedAt, site.timezone);
  const isWorkDay = site.workDays.includes(isoWeekday(businessDate));
  const scheduled = zonedTimeToUtc(businessDate, site.shiftStart, site.timezone);
  const lateBy = Math.floor((startedAt.getTime() - scheduled.getTime()) / 60000);
  const isLate = isWorkDay && lateBy > site.lateGraceMinutes;
  return { businessDate, isWorkDay, isLate, lateMinutes: isLate ? lateBy : 0 };
}

/** Scheduled end of a shift (handles overnight schedules like 20:00–06:00). */
export function scheduledEnd(site: SiteRules, businessDate: string): Date {
  const start = zonedTimeToUtc(businessDate, site.shiftStart, site.timezone);
  let end = zonedTimeToUtc(businessDate, site.shiftEnd, site.timezone);
  if (end <= start) end = zonedTimeToUtc(addDays(businessDate, 1), site.shiftEnd, site.timezone);
  return end;
}

/**
 * An open shift is "stale" (missed checkout) when it has been open longer than STALE_OPEN_SHIFT_MS,
 * or when a later business day has started and it has been open for more than NEW_DAY_STALE_MS.
 * The second condition catches "forgot to check out yesterday" without breaking night shifts
 * (22:00 → 06:00) that legitimately cross midnight. Resident workers are the main case.
 */
export function isStaleOpenShift(open: { startedAt: Date; businessDate: string }, now: Date, timezone: string): boolean {
  const elapsed = now.getTime() - open.startedAt.getTime();
  if (elapsed > RULES.STALE_OPEN_SHIFT_MS) return true;
  return localDateString(now, timezone) > open.businessDate && elapsed > RULES.NEW_DAY_STALE_MS;
}

// ───── check-out ─────

export interface CheckOutOutcome {
  workedMinutes: number;
  needsReview: boolean;
  flags: Flag[];
}

export function checkOutRule(startedAt: Date, endedAt: Date): RuleResult<CheckOutOutcome> {
  if (endedAt.getTime() < startedAt.getTime()) {
    return { ok: false, code: ErrorCode.END_BEFORE_START, message: 'End time is before the start time' };
  }
  const workedMinutes = minutesBetween(startedAt, endedAt);
  const long = workedMinutes > RULES.LONG_SHIFT_MINUTES;
  return { ok: true, value: { workedMinutes, needsReview: long, flags: long ? [Flag.LONG_SHIFT] : [] } };
}

// ───── corrections ─────

export function correctionRule(startedAt: Date, endedAt: Date | null, now: Date): RuleResult<{ workedMinutes: number }> {
  if (startedAt.getTime() > now.getTime() + RULES.MAX_FUTURE_SKEW_MS) {
    return { ok: false, code: ErrorCode.TIMESTAMP_IN_FUTURE, message: 'Start time is in the future' };
  }
  if (!endedAt) return { ok: true, value: { workedMinutes: 0 } };
  if (endedAt.getTime() > now.getTime() + RULES.MAX_FUTURE_SKEW_MS) {
    return { ok: false, code: ErrorCode.TIMESTAMP_IN_FUTURE, message: 'End time is in the future' };
  }
  if (endedAt <= startedAt) return { ok: false, code: ErrorCode.END_BEFORE_START, message: 'End time must be after start time' };
  const workedMinutes = minutesBetween(startedAt, endedAt);
  if (workedMinutes > RULES.MAX_SHIFT_MINUTES) {
    return { ok: false, code: ErrorCode.VALIDATION_FAILED, message: 'A shift cannot be longer than 24 hours' };
  }
  return { ok: true, value: { workedMinutes } };
}

export function verifiedMinutes(workedMinutes: number, breakMinutes: number): number {
  return Math.max(0, workedMinutes - Math.max(0, breakMinutes));
}

export const mergeFlags = (...lists: (readonly string[] | undefined)[]) => [...new Set(lists.flatMap((l) => l ?? []))];

/** Local wall-clock "HH:mm" of an instant, for messages. */
export function localHHMM(date: Date, tz: string): string {
  const p = localParts(date, tz);
  return `${String(p.hour).padStart(2, '0')}:${String(p.minute).padStart(2, '0')}`;
}
