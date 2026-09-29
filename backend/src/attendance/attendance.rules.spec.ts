import { ErrorCode } from '../common/errors';
import {
  assessLocation,
  checkInLocationRule,
  checkOutRule,
  checkTimestamp,
  computeLateness,
  correctionRule,
  Flag,
  isImpossibleTravel,
  isStaleOpenShift,
  RULES,
  scheduledEnd,
  SiteRules,
  verifiedMinutes,
} from './attendance.rules';

// Namangan, Tashkent timezone (UTC+5, no DST)
const site: SiteRules = {
  latitude: 41.0011,
  longitude: 71.6726,
  radiusMeters: 200,
  timezone: 'Asia/Tashkent',
  shiftStart: '08:00',
  shiftEnd: '18:00',
  lateGraceMinutes: 15,
  workDays: [1, 2, 3, 4, 5, 6],
};
// ~0.001 deg latitude ≈ 111 m
const near = { latitude: 41.0011 + 0.001, longitude: 71.6726, accuracyMeters: 10 };
const far = { latitude: 41.0011 + 0.01, longitude: 71.6726, accuracyMeters: 10 }; // ~1.1 km

describe('checkTimestamp', () => {
  const now = new Date('2026-09-29T05:00:00Z');
  it('accepts a fresh event', () => {
    expect(checkTimestamp(new Date('2026-09-29T04:59:00Z'), now)).toEqual({ ok: true, value: [] });
  });
  it('rejects events from the future beyond skew (manipulated clock)', () => {
    const r = checkTimestamp(new Date(now.getTime() + RULES.MAX_FUTURE_SKEW_MS + 1000), now);
    expect(r.ok).toBe(false);
    expect(!r.ok && r.code).toBe(ErrorCode.TIMESTAMP_IN_FUTURE);
  });
  it('tolerates small clock skew', () => {
    expect(checkTimestamp(new Date(now.getTime() + 60_000), now).ok).toBe(true);
  });
  it('flags late sync of offline events', () => {
    const r = checkTimestamp(new Date(now.getTime() - 3 * 3600_000), now);
    expect(r).toEqual({ ok: true, value: [Flag.LATE_SYNC] });
  });
  it('rejects events older than 72h', () => {
    const r = checkTimestamp(new Date(now.getTime() - RULES.MAX_EVENT_AGE_MS - 1000), now);
    expect(!r.ok && r.code).toBe(ErrorCode.EVENT_TOO_OLD);
  });
  it('rejects invalid dates', () => {
    expect(checkTimestamp(new Date('garbage'), now).ok).toBe(false);
  });
});

describe('check-in location rule', () => {
  it('requires a location', () => {
    const r = checkInLocationRule(site, null);
    expect(!r.ok && r.code).toBe(ErrorCode.LOCATION_REQUIRED);
  });
  it('accepts inside the geofence', () => {
    const r = checkInLocationRule(site, near);
    expect(r.ok && r.value.verdict).toBe('INSIDE');
    expect(r.ok && r.value.flags).toEqual([]);
  });
  it('rejects clearly outside the geofence with distance details', () => {
    const r = checkInLocationRule(site, far);
    expect(r.ok).toBe(false);
    expect(!r.ok && r.code).toBe(ErrorCode.OUTSIDE_GEOFENCE);
    expect(!r.ok && (r.details?.distanceMeters as number)).toBeGreaterThan(1000);
  });
  it('accepts but flags when the accuracy circle overlaps the fence (poor GPS)', () => {
    const r = checkInLocationRule(site, { latitude: 41.0011 + 0.0025, longitude: 71.6726, accuracyMeters: 150 }); // ~278 m
    expect(r.ok).toBe(true);
    expect(r.ok && r.value.flags).toEqual(expect.arrayContaining([Flag.GEOFENCE_UNCERTAIN, Flag.LOW_ACCURACY]));
  });
  it('does not let a huge claimed accuracy pull a far point inside', () => {
    const r = checkInLocationRule(site, { ...far, accuracyMeters: 50_000 });
    expect(r.ok).toBe(false);
  });
  it('flags mock (fake GPS) locations', () => {
    const r = checkInLocationRule(site, near, true);
    expect(r.ok && r.value.flags).toContain(Flag.MOCK_LOCATION);
  });
  it('assessLocation marks outside for checkout without rejecting', () => {
    expect(assessLocation(site, far).flags).toContain(Flag.OUTSIDE_GEOFENCE);
  });
});

describe('impossible travel', () => {
  const t0 = new Date('2026-09-29T03:00:00Z');
  it('flags 300 km in 10 minutes', () => {
    expect(
      isImpossibleTravel(
        { point: { latitude: 41.31, longitude: 69.24 }, at: t0 }, // Tashkent
        { point: { latitude: 41.0, longitude: 71.67 }, at: new Date(t0.getTime() + 10 * 60_000) }, // Namangan
      ),
    ).toBe(true);
  });
  it('does not flag GPS jitter', () => {
    expect(
      isImpossibleTravel(
        { point: { ...near, accuracyMeters: 50 }, at: t0 },
        { point: { latitude: near.latitude + 0.001, longitude: near.longitude, accuracyMeters: 50 }, at: new Date(t0.getTime() + 1000) },
      ),
    ).toBe(false);
  });
  it('does not flag a realistic drive', () => {
    expect(
      isImpossibleTravel(
        { point: { latitude: 41.31, longitude: 69.24 }, at: t0 },
        { point: { latitude: 41.0, longitude: 71.67 }, at: new Date(t0.getTime() + 4 * 3600_000) },
      ),
    ).toBe(false);
  });
});

describe('lateness & schedule', () => {
  it('on time within grace', () => {
    // 08:10 local = 03:10Z (Tuesday)
    const r = computeLateness(site, new Date('2026-09-29T03:10:00Z'));
    expect(r).toEqual({ businessDate: '2026-09-29', isWorkDay: true, isLate: false, lateMinutes: 0 });
  });
  it('late after grace', () => {
    const r = computeLateness(site, new Date('2026-09-29T03:40:00Z')); // 08:40
    expect(r.isLate).toBe(true);
    expect(r.lateMinutes).toBe(40);
  });
  it('uses the site-local date near midnight (timezone)', () => {
    // 2026-09-29T20:30Z = 2026-09-30 01:30 in Tashkent
    expect(computeLateness(site, new Date('2026-09-29T20:30:00Z')).businessDate).toBe('2026-09-30');
  });
  it('never marks late on a day off', () => {
    // 2026-10-04 is a Sunday
    const r = computeLateness(site, new Date('2026-10-04T06:00:00Z'));
    expect(r.isWorkDay).toBe(false);
    expect(r.isLate).toBe(false);
  });
  it('handles overnight schedules', () => {
    const night = { ...site, shiftStart: '20:00', shiftEnd: '06:00' };
    expect(scheduledEnd(night, '2026-09-29').toISOString()).toBe('2026-09-30T01:00:00.000Z');
  });
});

describe('stale open shift (missed checkout / resident worker)', () => {
  it('is stale when the worker checks in next day', () => {
    expect(isStaleOpenShift({ startedAt: new Date('2026-09-29T03:00:00Z'), businessDate: '2026-09-29' }, new Date('2026-09-30T03:00:00Z'), 'Asia/Tashkent')).toBe(true);
  });
  it('forgotten afternoon shift is stale next morning (17h, new day)', () => {
    // started 14:00 local, next day 07:00 local
    expect(isStaleOpenShift({ startedAt: new Date('2026-09-29T09:00:00Z'), businessDate: '2026-09-29' }, new Date('2026-09-30T02:00:00Z'), 'Asia/Tashkent')).toBe(true);
  });
  it('is not stale on the same day', () => {
    expect(isStaleOpenShift({ startedAt: new Date('2026-09-29T03:00:00Z'), businessDate: '2026-09-29' }, new Date('2026-09-29T12:00:00Z'), 'Asia/Tashkent')).toBe(false);
  });
  it('midnight shift that is still running is not stale before 20h', () => {
    // started 22:00 local, now 02:00 local next day
    expect(isStaleOpenShift({ startedAt: new Date('2026-09-29T17:00:00Z'), businessDate: '2026-09-29' }, new Date('2026-09-29T21:00:00Z'), 'Asia/Tashkent')).toBe(false);
  });
});

describe('check-out & corrections', () => {
  const start = new Date('2026-09-29T03:00:00Z');
  it('computes worked minutes', () => {
    expect(checkOutRule(start, new Date('2026-09-29T13:00:00Z'))).toEqual({ ok: true, value: { workedMinutes: 600, needsReview: false, flags: [] } });
  });
  it('rejects end before start', () => {
    const r = checkOutRule(start, new Date('2026-09-29T02:00:00Z'));
    expect(!r.ok && r.code).toBe(ErrorCode.END_BEFORE_START);
  });
  it('sends very long shifts to review (resident on site 24h ≠ 24h work)', () => {
    const r = checkOutRule(start, new Date('2026-09-30T03:00:00Z'));
    expect(r.ok && r.value.needsReview).toBe(true);
    expect(r.ok && r.value.flags).toContain(Flag.LONG_SHIFT);
  });
  it('correction rejects > 24h and future times', () => {
    const now = new Date('2026-09-30T12:00:00Z');
    expect(correctionRule(start, new Date('2026-09-30T04:00:00Z'), now).ok).toBe(false);
    expect(correctionRule(start, new Date('2026-10-01T04:00:00Z'), now).ok).toBe(false);
    expect(correctionRule(start, new Date('2026-09-29T12:00:00Z'), now)).toEqual({ ok: true, value: { workedMinutes: 540 } });
  });
  it('verified minutes subtract breaks but never go negative', () => {
    expect(verifiedMinutes(600, 60)).toBe(540);
    expect(verifiedMinutes(30, 60)).toBe(0);
  });
});
