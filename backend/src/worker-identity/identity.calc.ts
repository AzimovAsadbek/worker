/**
 * Worker identity: pure computation over already-verified records.
 * Self-reported data is returned separately and never influences these numbers.
 */
import { addDays, isoWeekday } from '../common/utils/time';

export type TrustLevel = 'SELF_REPORTED' | 'EMPLOYER_VERIFIED' | 'WORK_VERIFIED' | 'PERFORMANCE_VERIFIED';

export const TRUST_CRITERIA = {
  PERFORMANCE_MIN_WORKDAYS: 20,
  PERFORMANCE_MIN_TASKS: 5,
  PERFORMANCE_MIN_PUNCTUALITY: 0.8,
  ATTENDANCE_WINDOW_DAYS: 90,
} as const;

export interface VerifiedShiftRow {
  businessDate: string; // YYYY-MM-DD
  verifiedMinutes: number;
  isLate: boolean;
  companyId: string;
  projectId: string;
}

export interface AssignmentWindow {
  startDate: string; // YYYY-MM-DD
  endDate: string | null;
  workDays: number[];
}

export interface IdentityInput {
  verifiedShifts: VerifiedShiftRow[];
  approvedTasks: number;
  hasEmployerRelation: boolean;
  assignments: AssignmentWindow[];
  today: string; // YYYY-MM-DD in the worker's primary timezone
}

export interface IdentityStats {
  verifiedWorkdays: number;
  verifiedMinutes: number;
  verifiedHours: number;
  verifiedShifts: number;
  verifiedTasks: number;
  verifiedEmployers: number;
  verifiedProjects: number;
  punctualityRate: number | null;
  attendanceRate: number | null;
  attendanceWindowDays: number;
  expectedDays: number;
  attendedDays: number;
  firstVerifiedDate: string | null;
  lastVerifiedDate: string | null;
  trustLevel: TrustLevel;
}

const round = (n: number, d = 2) => Math.round(n * 10 ** d) / 10 ** d;

/** Expected workdays in [from, to] across assignments (a day counts once even with several sites). */
export function expectedWorkdays(assignments: AssignmentWindow[], from: string, to: string): Set<string> {
  const days = new Set<string>();
  for (const a of assignments) {
    let d = a.startDate > from ? a.startDate : from;
    const end = a.endDate && a.endDate < to ? a.endDate : to;
    let guard = 0;
    while (d <= end && guard++ < 400) {
      if (a.workDays.includes(isoWeekday(d))) days.add(d);
      d = addDays(d, 1);
    }
  }
  return days;
}

export function computeIdentity(input: IdentityInput): IdentityStats {
  const shifts = input.verifiedShifts;
  const workdays = new Set(shifts.map((s) => s.businessDate));
  const minutes = shifts.reduce((acc, s) => acc + s.verifiedMinutes, 0);
  const employers = new Set(shifts.map((s) => s.companyId));
  const projects = new Set(shifts.map((s) => s.projectId));
  const punctualityRate = shifts.length ? round(shifts.filter((s) => !s.isLate).length / shifts.length) : null;

  // Attendance over the last N days up to yesterday (today is still in progress).
  const to = addDays(input.today, -1);
  const from = addDays(input.today, -TRUST_CRITERIA.ATTENDANCE_WINDOW_DAYS);
  const expected = expectedWorkdays(input.assignments, from, to);
  const attended = [...expected].filter((d) => workdays.has(d)).length;
  const attendanceRate = expected.size ? round(attended / expected.size) : null;

  const sortedDays = [...workdays].sort();
  let trustLevel: TrustLevel = 'SELF_REPORTED';
  if (input.hasEmployerRelation) trustLevel = 'EMPLOYER_VERIFIED';
  if (shifts.length > 0) trustLevel = 'WORK_VERIFIED';
  if (
    workdays.size >= TRUST_CRITERIA.PERFORMANCE_MIN_WORKDAYS &&
    input.approvedTasks >= TRUST_CRITERIA.PERFORMANCE_MIN_TASKS &&
    (punctualityRate ?? 0) >= TRUST_CRITERIA.PERFORMANCE_MIN_PUNCTUALITY
  ) {
    trustLevel = 'PERFORMANCE_VERIFIED';
  }

  return {
    verifiedWorkdays: workdays.size,
    verifiedMinutes: minutes,
    verifiedHours: round(minutes / 60, 1),
    verifiedShifts: shifts.length,
    verifiedTasks: input.approvedTasks,
    verifiedEmployers: employers.size,
    verifiedProjects: projects.size,
    punctualityRate,
    attendanceRate,
    attendanceWindowDays: TRUST_CRITERIA.ATTENDANCE_WINDOW_DAYS,
    expectedDays: expected.size,
    attendedDays: attended,
    firstVerifiedDate: sortedDays[0] ?? null,
    lastVerifiedDate: sortedDays[sortedDays.length - 1] ?? null,
    trustLevel,
  };
}
