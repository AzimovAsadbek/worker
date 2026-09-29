import { computeIdentity, expectedWorkdays, VerifiedShiftRow } from './identity.calc';

const shift = (date: string, over: Partial<VerifiedShiftRow> = {}): VerifiedShiftRow => ({
  businessDate: date,
  verifiedMinutes: 540,
  isLate: false,
  companyId: 'c1',
  projectId: 'p1',
  ...over,
});

describe('worker identity', () => {
  it('self-reported only', () => {
    const r = computeIdentity({ verifiedShifts: [], approvedTasks: 0, hasEmployerRelation: false, assignments: [], today: '2026-09-30' });
    expect(r.trustLevel).toBe('SELF_REPORTED');
    expect(r.verifiedWorkdays).toBe(0);
    expect(r.punctualityRate).toBeNull();
    expect(r.attendanceRate).toBeNull();
  });

  it('employer verified when added by a company but no verified work yet', () => {
    const r = computeIdentity({ verifiedShifts: [], approvedTasks: 0, hasEmployerRelation: true, assignments: [], today: '2026-09-30' });
    expect(r.trustLevel).toBe('EMPLOYER_VERIFIED');
  });

  it('counts workdays once even with two verified shifts on the same day', () => {
    const r = computeIdentity({
      verifiedShifts: [shift('2026-09-28'), shift('2026-09-28', { verifiedMinutes: 120 }), shift('2026-09-29', { companyId: 'c2', projectId: 'p2' })],
      approvedTasks: 1,
      hasEmployerRelation: true,
      assignments: [],
      today: '2026-09-30',
    });
    expect(r.verifiedWorkdays).toBe(2);
    expect(r.verifiedShifts).toBe(3);
    expect(r.verifiedMinutes).toBe(1200);
    expect(r.verifiedHours).toBe(20);
    expect(r.verifiedEmployers).toBe(2);
    expect(r.verifiedProjects).toBe(2);
    expect(r.trustLevel).toBe('WORK_VERIFIED');
  });

  it('performance verified requires days, tasks and punctuality', () => {
    const days = Array.from({ length: 20 }, (_, i) => shift(`2026-08-${String(i + 1).padStart(2, '0')}`, { isLate: i < 3 }));
    const ok = computeIdentity({ verifiedShifts: days, approvedTasks: 5, hasEmployerRelation: true, assignments: [], today: '2026-09-30' });
    expect(ok.punctualityRate).toBe(0.85);
    expect(ok.trustLevel).toBe('PERFORMANCE_VERIFIED');
    const fewTasks = computeIdentity({ verifiedShifts: days, approvedTasks: 4, hasEmployerRelation: true, assignments: [], today: '2026-09-30' });
    expect(fewTasks.trustLevel).toBe('WORK_VERIFIED');
    const oftenLate = days.map((d, i) => ({ ...d, isLate: i < 5 }));
    expect(computeIdentity({ verifiedShifts: oftenLate, approvedTasks: 9, hasEmployerRelation: true, assignments: [], today: '2026-09-30' }).trustLevel).toBe('WORK_VERIFIED');
  });

  it('attendance = verified days / expected workdays of assignments (up to yesterday)', () => {
    // Mon 2026-09-21 .. Sun 2026-09-27, Mon-Sat work days → 6 expected (Sunday off)
    const r = computeIdentity({
      verifiedShifts: [shift('2026-09-21'), shift('2026-09-22'), shift('2026-09-23')],
      approvedTasks: 0,
      hasEmployerRelation: true,
      assignments: [{ startDate: '2026-09-21', endDate: '2026-09-27', workDays: [1, 2, 3, 4, 5, 6] }],
      today: '2026-09-30',
    });
    expect(r.expectedDays).toBe(6);
    expect(r.attendedDays).toBe(3);
    expect(r.attendanceRate).toBe(0.5);
  });

  it('expected workdays do not double count overlapping assignments', () => {
    const days = expectedWorkdays(
      [
        { startDate: '2026-09-21', endDate: null, workDays: [1, 2, 3, 4, 5] },
        { startDate: '2026-09-21', endDate: null, workDays: [1, 2, 3, 4, 5, 6] },
      ],
      '2026-09-21',
      '2026-09-27',
    );
    expect(days.size).toBe(6);
  });
});
