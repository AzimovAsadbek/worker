import { distanceMeters, geofenceVerdict } from './geo';
import { maskPhone, normalizePhone } from './phone';
import { addDays, isoWeekday, localDateString, tzOffsetMinutes, zonedTimeToUtc } from './time';

describe('phone normalisation', () => {
  it.each([
    ['+998 90 123 45 67', '+998901234567'],
    ['998901234567', '+998901234567'],
    ['90 123-45-67', '+998901234567'],
    ['(93) 555 44 33', '+998935554433'],
  ])('%s → %s', (input, out) => expect(normalizePhone(input)).toBe(out));
  it.each(['', '12345', '+7 912 123 45 67', '+998 12 345 67 89', 'abc901234567', '+9989012345678'])('rejects %s', (input) => {
    expect(normalizePhone(input)).toBeNull();
  });
  it('masks phones', () => expect(maskPhone('+998901234567')).toBe('+99890***67'));
});

describe('geo', () => {
  it('distance Tashkent → Namangan ≈ 200 km', () => {
    const d = distanceMeters(41.3111, 69.2797, 40.9983, 71.6726);
    expect(d).toBeGreaterThan(195_000);
    expect(d).toBeLessThan(215_000);
  });
  it('zero distance', () => expect(distanceMeters(41, 71, 41, 71)).toBe(0));
  it('verdicts', () => {
    expect(geofenceVerdict(150, 200, 10)).toBe('INSIDE');
    expect(geofenceVerdict(250, 200, 80)).toBe('UNCERTAIN');
    expect(geofenceVerdict(900, 200, 80)).toBe('OUTSIDE');
    expect(geofenceVerdict(900, 200, 100_000)).toBe('OUTSIDE'); // accuracy capped
  });
});

describe('time', () => {
  it('Tashkent offset is +300', () => expect(tzOffsetMinutes(new Date('2026-06-01T00:00:00Z'), 'Asia/Tashkent')).toBe(300));
  it('local date string', () => expect(localDateString(new Date('2026-09-29T19:30:00Z'), 'Asia/Tashkent')).toBe('2026-09-30'));
  it('zoned time → utc', () => expect(zonedTimeToUtc('2026-09-29', '08:00', 'Asia/Tashkent').toISOString()).toBe('2026-09-29T03:00:00.000Z'));
  it('handles DST zones', () => {
    // Europe/Berlin summer time (UTC+2)
    expect(zonedTimeToUtc('2026-07-01', '08:00', 'Europe/Berlin').toISOString()).toBe('2026-07-01T06:00:00.000Z');
  });
  it('addDays across month end', () => expect(addDays('2026-09-30', 1)).toBe('2026-10-01'));
  it('iso weekday', () => {
    expect(isoWeekday('2026-09-28')).toBe(1); // Monday
    expect(isoWeekday('2026-10-04')).toBe(7); // Sunday
  });
});
