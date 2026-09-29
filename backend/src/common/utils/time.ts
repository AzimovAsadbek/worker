/**
 * Timezone helpers built on Intl (full ICU in Node) — no external tz library needed.
 */
interface LocalParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  weekday: number; // ISO 1=Mon..7=Sun
}

const fmtCache = new Map<string, Intl.DateTimeFormat>();
function formatter(tz: string) {
  let f = fmtCache.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      weekday: 'short',
    });
    fmtCache.set(tz, f);
  }
  return f;
}

const WEEKDAYS: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

export function isValidTimezone(tz: string): boolean {
  try {
    formatter(tz);
    return true;
  } catch {
    return false;
  }
}

export function localParts(date: Date, tz: string): LocalParts {
  const parts = Object.fromEntries(formatter(tz).formatToParts(date).map((p) => [p.type, p.value]));
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
    weekday: WEEKDAYS[parts.weekday as string],
  };
}

/** Site-local calendar date as "YYYY-MM-DD". */
export function localDateString(date: Date, tz: string): string {
  const p = localParts(date, tz);
  return `${p.year}-${String(p.month).padStart(2, '0')}-${String(p.day).padStart(2, '0')}`;
}

/** "YYYY-MM-DD" → Date at UTC midnight (how Prisma represents @db.Date). */
export function dateOnly(ymd: string): Date {
  return new Date(`${ymd}T00:00:00.000Z`);
}

/** Offset of `tz` from UTC in minutes at a given instant (e.g. +300 for Asia/Tashkent). */
export function tzOffsetMinutes(date: Date, tz: string): number {
  const p = localParts(date, tz);
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return Math.round((asUtc - Math.floor(date.getTime() / 1000) * 1000) / 60000);
}

/** The UTC instant of a site-local wall-clock time ("HH:mm") on a site-local date ("YYYY-MM-DD"). */
export function zonedTimeToUtc(ymd: string, hhmm: string, tz: string): Date {
  const [h, m] = hhmm.split(':').map(Number);
  const guess = new Date(`${ymd}T${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:00.000Z`);
  const offset = tzOffsetMinutes(guess, tz);
  const first = new Date(guess.getTime() - offset * 60000);
  const offset2 = tzOffsetMinutes(first, tz); // handle DST edges
  return offset2 === offset ? first : new Date(guess.getTime() - offset2 * 60000);
}

export function addDays(ymd: string, days: number): string {
  const d = dateOnly(ymd);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

export function isoWeekday(ymd: string): number {
  const d = dateOnly(ymd).getUTCDay();
  return d === 0 ? 7 : d;
}

export const HHMM_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

export const minutesBetween = (a: Date, b: Date) => Math.max(0, Math.round((b.getTime() - a.getTime()) / 60000));
