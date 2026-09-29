import { buildWorld, createApp, ev, hoursAgo, inside, makeUser, outside, resetDb, sync, TestCtx, World } from './helpers';

describe('Attendance edge cases', () => {
  let ctx: TestCtx;
  let w: World;
  const api = (p: string) => `/api/v1/companies/${w.companyId}${p}`;

  beforeAll(async () => {
    ctx = await createApp();
  });
  beforeEach(async () => {
    await resetDb(ctx.prisma);
    w = await buildWorld(ctx);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('check-in outside the site → OUTSIDE_GEOFENCE; nothing stored', async () => {
    const [r] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, new Date(), outside));
    expect(r).toMatchObject({ status: 'REJECTED', code: 'OUTSIDE_GEOFENCE' });
    expect(await ctx.prisma.shift.count()).toBe(0);
    expect(await ctx.prisma.workEvent.count()).toBe(0);
  });

  it('check-in without location → LOCATION_REQUIRED', async () => {
    const [r] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, new Date(), null));
    expect(r).toMatchObject({ status: 'REJECTED', code: 'LOCATION_REQUIRED' });
  });

  it('poor GPS accuracy near the fence → accepted with flags', async () => {
    const [r] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, new Date(), { latitude: 41.0011 + 0.0025, longitude: 71.6726, accuracy: 150 }));
    expect(r.status).toBe('ACCEPTED');
    expect(r.shift!.flags).toEqual(expect.arrayContaining(['GEOFENCE_UNCERTAIN', 'LOW_ACCURACY']));
  });

  it('checkout without check-in → NO_OPEN_SHIFT', async () => {
    const [r] = await sync(ctx, w.worker, ev('WORK_ENDED', w.siteId));
    expect(r).toMatchObject({ status: 'REJECTED', code: 'NO_OPEN_SHIFT' });
  });

  it('site the worker is not assigned to → NOT_ASSIGNED_TO_SITE', async () => {
    const [r] = await sync(ctx, w.worker, ev('WORK_STARTED', w.site2Id, new Date(), { latitude: 41.0511, longitude: 71.6726, accuracy: 10 }));
    expect(r).toMatchObject({ status: 'REJECTED', code: 'NOT_ASSIGNED_TO_SITE' });
  });

  it('manipulated future timestamp → TIMESTAMP_IN_FUTURE', async () => {
    const [r] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, new Date(Date.now() + 3600_000)));
    expect(r).toMatchObject({ status: 'REJECTED', code: 'TIMESTAMP_IN_FUTURE' });
  });

  it('offline batch: start + end synced together, out of order, twice (app killed during sync) → one shift, no duplicates', async () => {
    const start = ev('WORK_STARTED', w.siteId, hoursAgo(10));
    const end = ev('WORK_ENDED', w.siteId, hoursAgo(2));
    const first = await sync(ctx, w.worker, end, start); // client order reversed
    expect(first.map((r) => r.status)).toEqual(['ACCEPTED', 'ACCEPTED']);
    expect(first[0].clientEventId).toBe(end.clientEventId); // response keeps request order
    expect(first[0].shift!.status).toBe('CLOSED');
    expect(first[0].shift!.flags).toContain('LATE_SYNC');
    const second = await sync(ctx, w.worker, start, end);
    expect(second.map((r) => r.status)).toEqual(['DUPLICATE', 'DUPLICATE']);
    expect(await ctx.prisma.shift.count()).toBe(1);
    expect(await ctx.prisma.workEvent.count()).toBe(2);
  });

  it('concurrent duplicate sync requests do not create duplicates', async () => {
    const start = ev('WORK_STARTED', w.siteId, hoursAgo(1));
    const results = await Promise.all([1, 2, 3].map(() => ctx.http().post('/api/v1/work-events/sync').set(w.worker.auth).send({ events: [start] })));
    const statuses = results.map((r) => r.body.results[0].status).sort();
    expect(statuses.filter((s) => s === 'ACCEPTED')).toHaveLength(1);
    expect(await ctx.prisma.workEvent.count({ where: { type: 'WORK_STARTED' } })).toBe(1);
    // two different taps racing → still only one open shift
    const races = await Promise.all([1, 2].map(() => ctx.http().post('/api/v1/work-events/sync').set(w.worker.auth).send({ events: [ev('WORK_STARTED', w.siteId)] })));
    expect(races.every((r) => r.body.results[0].status === 'REJECTED')).toBe(true);
    expect(await ctx.prisma.shift.count({ where: { status: 'OPEN' } })).toBe(1);
  });

  it('resident worker forgets checkout: next-morning check-in auto-closes yesterday with 0 minutes (NEEDS_REVIEW)', async () => {
    const assignment = await ctx.prisma.siteAssignment.findFirstOrThrow({ where: { userId: w.worker.id } });
    await ctx.http().patch(api(`/sites/${w.siteId}/assignments/${assignment.id}`)).set(w.foreman.auth).send({ isResident: true }).expect(200);
    const [day1] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(26)));
    expect(day1.status).toBe('ACCEPTED');
    const [day2] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(1)));
    expect(day2.status).toBe('ACCEPTED');
    const old = await ctx.prisma.shift.findUniqueOrThrow({ where: { id: day1.shift!.id } });
    expect(old).toMatchObject({ status: 'NEEDS_REVIEW', workedMinutes: 0, verifiedMinutes: 0, isResident: true });
    expect(old.flags).toContain('MISSED_CHECKOUT');
    expect(await ctx.prisma.workEvent.count({ where: { type: 'SHIFT_AUTO_CLOSED' } })).toBe(1);

    // it cannot be verified without an end time; the foreman corrects it with a reason → history kept
    const noEnd = await ctx.http().post(api(`/shifts/${old.id}/verify`)).set(w.foreman.auth).send({}).expect(409);
    expect(noEnd.body.code).toBe('SHIFT_NOT_REVIEWABLE');
    const start = old.startedAt;
    const end = new Date(start.getTime() + 9 * 3600_000);
    const c = await ctx.http().post(api(`/shifts/${old.id}/correct`)).set(w.foreman.auth)
      .send({ endedAt: end.toISOString(), reason: "Prorab tasdiqladi: 17:00 da tugagan", verify: true, breakMinutes: 60 }).expect(200);
    expect(c.body).toMatchObject({ status: 'VERIFIED', workedMinutes: 540, verifiedMinutes: 480 });
    const detail = await ctx.http().get(api(`/shifts/${old.id}`)).set(w.foreman.auth).expect(200);
    const types = detail.body.events.map((e: { type: string }) => e.type);
    expect(types).toEqual(['WORK_STARTED', 'SHIFT_AUTO_CLOSED', 'SHIFT_CORRECTED', 'SHIFT_VERIFIED']);
    const corr = detail.body.events.find((e: { type: string }) => e.type === 'SHIFT_CORRECTED');
    expect(corr.reason).toContain('17:00');
    expect(corr.metadata.from.endedAt).toBeNull();
    expect(corr.actor.id).toBe(w.foreman.id);
  });

  it('a resident on site 24h is never counted as 24h: long shift needs review', async () => {
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(19)));
    const [end] = await sync(ctx, w.worker, ev('WORK_ENDED', w.siteId, hoursAgo(0.2)));
    expect(end.shift).toMatchObject({ status: 'NEEDS_REVIEW' });
    expect(end.shift!.flags).toContain('LONG_SHIFT');
  });

  it('midnight-crossing night shift stays on its start date and is not auto-closed', async () => {
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(6)));
    const [again] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(1)));
    expect(again.code).toBe('ALREADY_CHECKED_IN');
  });

  it('checkout outside the fence is accepted but flagged', async () => {
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(8)));
    const [end] = await sync(ctx, w.worker, ev('WORK_ENDED', w.siteId, hoursAgo(0.1), outside));
    expect(end.status).toBe('ACCEPTED');
    expect(end.shift!.flags).toContain('OUTSIDE_GEOFENCE');
  });

  it('fraud signals: mock location, shared device, impossible travel are flagged (not auto-punished)', async () => {
    const other = await makeUser(ctx, 'Other worker');
    await ctx.http().post(api('/members')).set(w.foreman.auth).send({ phone: other.phone, role: 'WORKER', siteIds: [w.siteId] }).expect(201);
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(3), inside, { isMocked: true }));
    const [shared] = await sync(ctx, other, ev('WORK_STARTED', w.siteId, hoursAgo(2.9)));
    expect(shared.shift!.flags).toContain('SHARED_DEVICE');
    const s1 = await ctx.prisma.shift.findFirstOrThrow({ where: { workerId: w.worker.id } });
    expect(s1.flags).toContain('MOCK_LOCATION');

    // worker 2 "teleports": event 1 minute later at a location 50 km away is outside and rejected,
    // but the checkout (allowed outside) records IMPOSSIBLE_TRAVEL
    const [end] = await sync(ctx, other, ev('WORK_ENDED', w.siteId, hoursAgo(2.88), { latitude: 41.45, longitude: 71.6726, accuracy: 10 }, { deviceId: 'device-other-01' }));
    expect(end.shift!.flags).toEqual(expect.arrayContaining(['IMPOSSIBLE_TRAVEL', 'OUTSIDE_GEOFENCE']));
    const flagged = await ctx.http().get(api('/shifts?flagged=true')).set(w.foreman.auth).expect(200);
    expect(flagged.body.total).toBe(2);
  });

  it('worker assigned to two sites checks in at one, cannot end on the other', async () => {
    await ctx.http().post(api(`/sites/${w.site2Id}/assignments`)).set(w.admin.auth).send({ userId: w.worker.id }).expect(201);
    const today = await ctx.http().get('/api/v1/me/today').set(w.worker.auth).expect(200);
    expect(today.body.assignments).toHaveLength(2);
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(4)));
    const [r] = await sync(ctx, w.worker, ev('WORK_ENDED', w.site2Id, hoursAgo(1), { latitude: 41.0511, longitude: 71.6726, accuracy: 10 }));
    expect(r).toMatchObject({ status: 'REJECTED', code: 'NO_OPEN_SHIFT' });
  });

  it('removed / suspended worker cannot check in; open shift blocks removal', async () => {
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(3)));
    const members = await ctx.http().get(api('/members?role=WORKER')).set(w.admin.auth).expect(200);
    const memberId = members.body.items[0].id;
    const blocked = await ctx.http().delete(api(`/members/${memberId}`)).set(w.admin.auth).expect(409);
    expect(blocked.body.code).toBe('SHIFT_OPEN');
    await sync(ctx, w.worker, ev('WORK_ENDED', w.siteId, hoursAgo(1)));

    await ctx.http().patch(api(`/members/${memberId}`)).set(w.admin.auth).send({ status: 'SUSPENDED' }).expect(200);
    const [suspended] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId));
    expect(suspended.code).toBe('MEMBERSHIP_INACTIVE');
    await ctx.http().patch(api(`/members/${memberId}`)).set(w.admin.auth).send({ status: 'ACTIVE' }).expect(200);

    await ctx.http().delete(api(`/members/${memberId}`)).set(w.admin.auth).expect(204);
    const [removed] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId));
    expect(removed.code).toBe('NOT_ASSIGNED_TO_SITE');
    expect(await ctx.prisma.auditLog.count({ where: { action: 'WORKER_REMOVED' } })).toBe(1);
  });

  it('worker changes phone: new device works, history stays with the person', async () => {
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(8), inside, { deviceId: 'old-phone-0001' }));
    const [end] = await sync(ctx, w.worker, ev('WORK_ENDED', w.siteId, hoursAgo(1), inside, { deviceId: 'new-phone-0002' }));
    expect(end.status).toBe('ACCEPTED');
    expect(end.shift!.flags).not.toContain('SHARED_DEVICE');
  });

  it('no-phone worker: foreman records attendance manually (MANUAL_ENTRY, no location needed)', async () => {
    const start = await ctx.http().post(api('/attendance/manual')).set(w.foreman.auth)
      .send({ workerId: w.worker.id, siteId: w.siteId, type: 'WORK_STARTED', occurredAt: hoursAgo(8).toISOString(), reason: "Telefoni yo'q" }).expect(200);
    expect(start.body.shift.flags).toContain('MANUAL_ENTRY');
    await ctx.http().post(api('/attendance/manual')).set(w.foreman.auth)
      .send({ workerId: w.worker.id, siteId: w.siteId, type: 'WORK_ENDED', occurredAt: hoursAgo(1).toISOString(), reason: "Telefoni yo'q" }).expect(200);
    const e = await ctx.prisma.workEvent.findFirstOrThrow({ where: { type: 'WORK_STARTED' } });
    expect(e).toMatchObject({ source: 'FOREMAN_APP', actorUserId: w.foreman.id, subjectUserId: w.worker.id, reason: "Telefoni yo'q" });
    // manual entry is still subject to the business rules
    const dbl = await ctx.http().post(api('/attendance/manual')).set(w.foreman.auth)
      .send({ workerId: w.worker.id, siteId: w.siteId, type: 'WORK_ENDED', occurredAt: new Date().toISOString(), reason: 'x-test' }).expect(409);
    expect(dbl.body.code).toBe('NO_OPEN_SHIFT');
  });

  it('bulk verify + reject + dispute + resolution keep both sides in the audit trail', async () => {
    const [a] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(30)), ev('WORK_ENDED', w.siteId, hoursAgo(21)));
    const s1 = a.shift!.id;
    const [b] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(9)));
    await sync(ctx, w.worker, ev('WORK_ENDED', w.siteId, hoursAgo(2)));
    const s2 = b.shift!.id;

    const bulk = await ctx.http().post(api('/shifts/verify')).set(w.foreman.auth).send({ shiftIds: [s1, '00000000-0000-4000-8000-000000000000'] }).expect(200);
    expect(bulk.body.verified).toEqual([s1]);
    expect(bulk.body.skipped[0].code).toBe('NOT_FOUND');

    // reject requires a reason
    await ctx.http().post(api(`/shifts/${s2}/reject`)).set(w.foreman.auth).send({}).expect(400);
    await ctx.http().post(api(`/shifts/${s2}/reject`)).set(w.foreman.auth).send({ reason: '17:00 da ketgan' }).expect(200);

    // worker disputes: "I worked until 18:00"
    const shift2 = await ctx.prisma.shift.findUniqueOrThrow({ where: { id: s2 } });
    const claimedEnd = new Date(shift2.endedAt!.getTime() + 30 * 60_000);
    const d = await ctx.http().post(`/api/v1/me/shifts/${s2}/disputes`).set(w.worker.auth)
      .send({ reason: 'Men 18:00 gacha ishladim', claimedEnd: claimedEnd.toISOString() }).expect(201);
    await ctx.http().post(`/api/v1/me/shifts/${s2}/disputes`).set(w.worker.auth).send({ reason: 'Yana bir marta' }).expect(409);
    const foremanNotes = await ctx.http().get('/api/v1/me/notifications').set(w.foreman.auth).expect(200);
    expect(foremanNotes.body.items.map((n: { type: string }) => n.type)).toContain('DISPUTE_OPENED');

    const list = await ctx.http().get(api('/disputes?status=OPEN')).set(w.foreman.auth).expect(200);
    expect(list.body.items[0].id).toBe(d.body.id);
    const res = await ctx.http().post(api(`/disputes/${d.body.id}/resolve`)).set(w.foreman.auth).send({ accept: true, resolution: "Kamera yozuvi bo'yicha tasdiqlandi" }).expect(200);
    expect(res.body.status).toBe('ACCEPTED');
    const final = await ctx.prisma.shift.findUniqueOrThrow({ where: { id: s2 } });
    expect(final.status).toBe('VERIFIED');
    expect(final.endedAt!.toISOString()).toBe(claimedEnd.toISOString());
    expect(final.originalEndAt!.toISOString()).toBe(shift2.endedAt!.toISOString()); // original kept

    const types = (await ctx.prisma.workEvent.findMany({ where: { shiftId: s2 }, orderBy: { createdAt: 'asc' } })).map((e) => e.type);
    expect(types).toEqual(['WORK_STARTED', 'WORK_ENDED', 'SHIFT_REJECTED', 'DISPUTE_OPENED', 'SHIFT_CORRECTED', 'SHIFT_VERIFIED', 'DISPUTE_RESOLVED']);
    await ctx.http().post(api(`/disputes/${d.body.id}/resolve`)).set(w.foreman.auth).send({ accept: false, resolution: 'again' }).expect(409);
  });

  it('work events and audit log are append-only at the database level', async () => {
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(2)));
    await expect(ctx.prisma.workEvent.updateMany({ data: { reason: 'tampered' } })).rejects.toThrow(/append-only/);
    await expect(ctx.prisma.workEvent.deleteMany({})).rejects.toThrow(/append-only/);
    await expect(ctx.prisma.auditLog.deleteMany({})).rejects.toThrow(/append-only/);
  });

  it('dashboard: absent / on site / checked out', async () => {
    const absentee = await makeUser(ctx, 'Absent worker');
    await ctx.http().post(api('/members')).set(w.foreman.auth).send({ phone: absentee.phone, role: 'WORKER', siteIds: [w.siteId] }).expect(201);
    await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(1)));
    const d = await ctx.http().get(api('/dashboard')).set(w.foreman.auth).expect(200);
    const site = d.body.sites[0];
    expect(site.totals.assigned).toBe(2);
    const byUser = Object.fromEntries(site.workers.map((x: { userId: string; status: string }) => [x.userId, x.status]));
    expect(['ON_SITE', 'PENDING_CHECKOUT']).toContain(byUser[w.worker.id]);
    expect(['ABSENT', 'NOT_YET', 'DAY_OFF']).toContain(byUser[absentee.id]);
    expect(d.body.totals).toHaveProperty('awaitingVerification');
  });
});
