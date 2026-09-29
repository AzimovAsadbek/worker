import { buildWorld, createApp, makeUser, resetDb, TestCtx, World } from './helpers';

const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(100, 2)]);

describe('Tasks + evidence + verified tasks', () => {
  let ctx: TestCtx;
  let w: World;
  const api = (p: string) => `/api/v1/companies/${w.companyId}${p}`;

  beforeAll(async () => {
    ctx = await createApp();
    await resetDb(ctx.prisma);
    w = await buildWorld(ctx);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('assign → start → evidence → submit → changes requested → resubmit → approve', async () => {
    const t = await ctx.http().post(api('/tasks')).set(w.foreman.auth)
      .send({ siteId: w.siteId, assigneeId: w.worker.id, title: "G'isht terish — 3-qavat", quantity: 20, unit: 'm2', dueDate: '2026-10-05' }).expect(201);
    const id = t.body.id;
    const mine = await ctx.http().get('/api/v1/me/tasks').set(w.worker.auth).expect(200);
    expect(mine.body.items[0]).toMatchObject({ id, status: 'ASSIGNED', company: { id: w.companyId } });

    // review before submission is refused
    await ctx.http().post(api(`/tasks/${id}/review`)).set(w.foreman.auth).send({ decision: 'APPROVED' }).expect(409);

    await ctx.http().post(`/api/v1/me/tasks/${id}/start`).set(w.worker.auth).expect(200);
    await ctx.http().post(`/api/v1/me/tasks/${id}/evidence`).set(w.worker.auth).field('comment', 'Tayyor devor').attach('file', PNG, 'devor.png').expect(201);
    await ctx.http().post(`/api/v1/me/tasks/${id}/submit`).set(w.worker.auth).send({ completedQuantity: 20, note: 'Bajarildi' }).expect(200);

    const noComment = await ctx.http().post(api(`/tasks/${id}/review`)).set(w.foreman.auth).send({ decision: 'CHANGES_REQUESTED' }).expect(400);
    expect(noComment.body.code).toBe('VALIDATION_FAILED');
    await ctx.http().post(api(`/tasks/${id}/review`)).set(w.foreman.auth).send({ decision: 'CHANGES_REQUESTED', comment: "Burchakni to'g'rilang" }).expect(200);
    await ctx.http().post(`/api/v1/me/tasks/${id}/submit`).set(w.worker.auth).send({}).expect(200);
    const approved = await ctx.http().post(api(`/tasks/${id}/review`)).set(w.foreman.auth).send({ decision: 'APPROVED' }).expect(200);
    expect(approved.body.status).toBe('APPROVED');
    expect(approved.body.approvals.map((x: { decision: string }) => x.decision)).toEqual(['CHANGES_REQUESTED', 'APPROVED']);
    expect(approved.body.evidence).toHaveLength(1);

    // approved tasks are immutable for the worker
    await ctx.http().post(`/api/v1/me/tasks/${id}/submit`).set(w.worker.auth).send({}).expect(409);
    await ctx.http().post(`/api/v1/me/tasks/${id}/evidence`).set(w.worker.auth).attach('file', PNG, 'x.png').expect(409);

    const identity = await ctx.http().get('/api/v1/me/identity').set(w.worker.auth).expect(200);
    expect(identity.body.verified.verifiedTasks).toBe(1);
    const events = await ctx.prisma.workEvent.findMany({ where: { entityId: id }, orderBy: { createdAt: 'asc' } });
    expect(events.map((e) => e.type)).toEqual(['TASK_ASSIGNED', 'TASK_STARTED', 'TASK_SUBMITTED', 'TASK_CHANGES_REQUESTED', 'TASK_SUBMITTED', 'TASK_APPROVED']);
  });

  it('tasks can only be assigned to workers on the site', async () => {
    const stranger = await makeUser(ctx, 'Stranger');
    const r = await ctx.http().post(api('/tasks')).set(w.foreman.auth).send({ siteId: w.siteId, assigneeId: stranger.id, title: 'Task' }).expect(400);
    expect(r.body.code).toBe('NOT_ASSIGNED_TO_SITE');
  });
});

describe('Vacancy edge cases', () => {
  let ctx: TestCtx;
  let w: World;
  let vacancyId: string;
  const api = (p: string) => `/api/v1/companies/${w.companyId}${p}`;
  const body = {
    title: 'Betonchi kerak',
    description: 'Monolit karkas uchun betonchi ishchilar kerak.',
    category: 'CONCRETE',
    city: 'Namangan',
    rateAmount: 200000,
    paymentPeriod: 'DAILY',
    workersNeeded: 2,
    publish: true,
  };

  beforeAll(async () => {
    ctx = await createApp();
    await resetDb(ctx.prisma);
    w = await buildWorld(ctx);
    const v = await ctx.http().post(api('/vacancies')).set(w.admin.auth).send(body).expect(201);
    vacancyId = v.body.id;
    expect(v.body.status).toBe('OPEN');
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('withdraw and re-apply', async () => {
    const u = await makeUser(ctx, 'Seeker 1');
    const a = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(u.auth).send({}).expect(201);
    await ctx.http().post(`/api/v1/me/applications/${a.body.id}/withdraw`).set(u.auth).expect(200);
    await ctx.http().post(`/api/v1/me/applications/${a.body.id}/withdraw`).set(u.auth).expect(409);
    const again = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(u.auth).send({ coverNote: 'Qayta' }).expect(201);
    expect(again.body.id).toBe(a.body.id);
    expect(again.body.status).toBe('SUBMITTED');
  });

  it('company blocks an applicant (reason required, company-local only)', async () => {
    const u = await makeUser(ctx, 'Seeker 2');
    await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(u.auth).send({}).expect(201);
    await ctx.http().post(api('/blocks')).set(w.admin.auth).send({ userId: u.id }).expect(400);
    await ctx.http().post(api('/blocks')).set(w.admin.auth).send({ userId: u.id, reason: 'Oldingi obyektda asbob-uskunani qaytarmagan' }).expect(201);
    const v2 = await ctx.http().post(api('/vacancies')).set(w.admin.auth).send({ ...body, title: 'Boshqa vakansiya' }).expect(201);
    const r = await ctx.http().post(`/api/v1/vacancies/${v2.body.id}/apply`).set(u.auth).send({}).expect(403);
    expect(r.body.code).toBe('BLOCKED_BY_COMPANY');
    // cannot block random people with no relation to the company
    const random = await makeUser(ctx, 'Random person');
    await ctx.http().post(api('/blocks')).set(w.admin.auth).send({ userId: random.id, reason: 'no relation at all' }).expect(404);
    // another company is unaffected
    const other = await buildWorld(ctx, 'Z');
    const ov = await ctx.http().post(`/api/v1/companies/${other.companyId}/vacancies`).set(other.admin.auth).send(body).expect(201);
    await ctx.http().post(`/api/v1/vacancies/${ov.body.id}/apply`).set(u.auth).send({}).expect(201);
  });

  it('rejected application cannot be accepted later; invalid transitions are refused', async () => {
    const u = await makeUser(ctx, 'Seeker 3');
    const a = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(u.auth).send({}).expect(201);
    await ctx.http().post(api(`/applications/${a.body.id}/status`)).set(w.admin.auth).send({ status: 'REJECTED', reason: 'Tajriba yetarli emas' }).expect(200);
    const r = await ctx.http().post(api(`/applications/${a.body.id}/status`)).set(w.admin.auth).send({ status: 'ACCEPTED' }).expect(409);
    expect(r.body.code).toBe('APPLICATION_INVALID_STATE');
    const notes = await ctx.http().get('/api/v1/me/notifications').set(u.auth).expect(200);
    expect(notes.body.items[0].body).toContain('Tajriba yetarli emas');
  });

  it('paused vacancy is hidden from the board and refuses applications', async () => {
    await ctx.http().post(api(`/vacancies/${vacancyId}/status`)).set(w.admin.auth).send({ status: 'PAUSED' }).expect(200);
    const u = await makeUser(ctx, 'Seeker 4');
    const board = await ctx.http().get('/api/v1/vacancies').set(u.auth).expect(200);
    expect(board.body.items.map((x: { id: string }) => x.id)).not.toContain(vacancyId);
    const r = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(u.auth).send({}).expect(409);
    expect(r.body.code).toBe('VACANCY_NOT_OPEN');
    await ctx.http().post(api(`/vacancies/${vacancyId}/status`)).set(w.admin.auth).send({ status: 'OPEN' }).expect(200);
  });

  it('foreman vacancies must be tied to own site; foreman sees only own vacancies', async () => {
    const r = await ctx.http().post(api('/vacancies')).set(w.foreman.auth).send(body).expect(400);
    expect(r.body.code).toBe('VALIDATION_FAILED');
    await ctx.http().post(api('/vacancies')).set(w.foreman.auth).send({ ...body, siteId: w.site2Id }).expect(403);
    const mine = await ctx.http().post(api('/vacancies')).set(w.foreman.auth).send({ ...body, siteId: w.siteId }).expect(201);
    const list = await ctx.http().get(api('/vacancies')).set(w.foreman.auth).expect(200);
    expect(list.body.items.map((x: { id: string }) => x.id)).toEqual([mine.body.id]);
  });

  it('company verification: request → platform review → badge only after VERIFIED', async () => {
    await ctx.http().post(api('/verification-request')).set(w.admin.auth).send({ registrationNumber: '12345' }).expect(400);
    const req = await ctx.http().post(api('/verification-request')).set(w.admin.auth).send({ registrationNumber: '301234567' }).expect(201);
    expect(req.body.verificationStatus).toBe('PENDING');
    let trust = await ctx.http().get(`/api/v1/companies/${w.companyId}/trust`).set(w.worker.auth).expect(200);
    expect(trust.body.verified).toBe(false);
    const staff = await makeUser(ctx, 'Platform staff');
    await ctx.prisma.user.update({ where: { id: staff.id }, data: { isPlatformAdmin: true } });
    const pending = await ctx.http().get('/api/v1/admin/companies').set(staff.auth).expect(200);
    expect(pending.body.map((c: { id: string }) => c.id)).toContain(w.companyId);
    await ctx.http().post(`/api/v1/admin/companies/${w.companyId}/verification`).set(staff.auth).send({ decision: 'VERIFIED' }).expect(201);
    trust = await ctx.http().get(`/api/v1/companies/${w.companyId}/trust`).set(w.worker.auth).expect(200);
    expect(trust.body.verified).toBe(true);
  });

  it('notification preferences are respected', async () => {
    const u = await makeUser(ctx, 'Quiet seeker');
    await ctx.http().put('/api/v1/me/notification-preferences').set(u.auth).send({ prefs: { applications: { inApp: false, push: false } } }).expect(200);
    await ctx.http().put('/api/v1/me/notification-preferences').set(u.auth).send({ prefs: { unknown: { inApp: false } } }).expect(400);
    const a = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(u.auth).send({}).expect(201);
    await ctx.http().post(api(`/applications/${a.body.id}/status`)).set(w.admin.auth).send({ status: 'SHORTLISTED' }).expect(200);
    const notes = await ctx.http().get('/api/v1/me/notifications').set(u.auth).expect(200);
    expect(notes.body.total).toBe(0);
  });
});
