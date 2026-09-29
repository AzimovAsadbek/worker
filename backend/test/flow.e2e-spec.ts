import { buildWorld, createApp, ev, hoursAgo, makeUser, resetDb, sync, TestCtx, World } from './helpers';

/**
 * The core product chain end-to-end:
 * Attendance → Work Event → Verification → Verified Work → Worker Identity → Opportunity
 */
describe('Critical flow: company → site → worker → check-in/out → verification → identity → vacancy → hire', () => {
  let ctx: TestCtx;
  let w: World;
  let shiftId: string;

  beforeAll(async () => {
    ctx = await createApp();
    await resetDb(ctx.prisma);
    w = await buildWorld(ctx);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  it('admin sees company, roles and membership in /me', async () => {
    const me = await ctx.http().get('/api/v1/me').set(w.admin.auth).expect(200);
    expect(me.body.memberships).toEqual([expect.objectContaining({ role: 'COMPANY_ADMIN', company: expect.objectContaining({ id: w.companyId }) })]);
    const company = await ctx.http().get(`/api/v1/companies/${w.companyId}`).set(w.admin.auth).expect(200);
    expect(company.body.myRole).toBe('COMPANY_ADMIN');
    expect(company.body.verificationStatus).toBe('UNVERIFIED');
  });

  it('foreman sees only own site; worker sees the site on Today', async () => {
    const sites = await ctx.http().get(`/api/v1/companies/${w.companyId}/sites`).set(w.foreman.auth).expect(200);
    expect(sites.body.map((s: { id: string }) => s.id)).toEqual([w.siteId]);
    const adminSites = await ctx.http().get(`/api/v1/companies/${w.companyId}/sites`).set(w.admin.auth).expect(200);
    expect(adminSites.body).toHaveLength(2);

    const today = await ctx.http().get('/api/v1/me/today').set(w.worker.auth).expect(200);
    expect(today.body.assignments).toHaveLength(1);
    expect(today.body.assignments[0].site).toMatchObject({ id: w.siteId, radiusMeters: 200 });
    expect(today.body.openShift).toBeNull();
  });

  it('worker checks in (WORK_STARTED event + open shift)', async () => {
    const start = ev('WORK_STARTED', w.siteId, hoursAgo(9));
    const [r] = await sync(ctx, w.worker, start);
    expect(r.status).toBe('ACCEPTED');
    expect(r.shift!.status).toBe('OPEN');
    shiftId = r.shift!.id;
    const event = await ctx.prisma.workEvent.findFirst({ where: { clientEventId: start.clientEventId } });
    expect(event).toMatchObject({ type: 'WORK_STARTED', insideGeofence: true, source: 'MOBILE_APP', deviceId: 'device-test-0001' });
    expect(event!.latitude).toBeCloseTo(41.0016);

    // same event re-sent (retry after network drop) → DUPLICATE, no second event
    const [dup] = await sync(ctx, w.worker, start);
    expect(dup.status).toBe('DUPLICATE');
    expect(dup.shift!.id).toBe(shiftId);
    expect(await ctx.prisma.workEvent.count({ where: { type: 'WORK_STARTED' } })).toBe(1);

    // a different tap while checked in → ALREADY_CHECKED_IN
    const [again] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId, hoursAgo(8)));
    expect(again).toMatchObject({ status: 'REJECTED', code: 'ALREADY_CHECKED_IN' });
  });

  it('foreman dashboard shows the worker on site', async () => {
    const d = await ctx.http().get(`/api/v1/companies/${w.companyId}/dashboard`).set(w.foreman.auth).expect(200);
    expect(d.body.totals.assigned).toBe(1);
    expect(d.body.sites[0].workers[0]).toMatchObject({ userId: w.worker.id, status: expect.stringMatching(/ON_SITE|PENDING_CHECKOUT/) });
  });

  it('worker checks out (WORK_ENDED) → shift CLOSED, awaiting verification', async () => {
    const [r] = await sync(ctx, w.worker, ev('WORK_ENDED', w.siteId, hoursAgo(0.5)));
    expect(r.status).toBe('ACCEPTED');
    expect(r.shift).toMatchObject({ id: shiftId, status: 'CLOSED', workedMinutes: 510 });
    const [twice] = await sync(ctx, w.worker, ev('WORK_ENDED', w.siteId, hoursAgo(0.4)));
    expect(twice).toMatchObject({ status: 'REJECTED', code: 'NO_OPEN_SHIFT' });

    // not yet verified → identity has no verified work
    const id = await ctx.http().get('/api/v1/me/identity').set(w.worker.auth).expect(200);
    expect(id.body.verified.verifiedWorkdays).toBe(0);
    expect(id.body.verified.trustLevel).toBe('EMPLOYER_VERIFIED');
  });

  it('foreman verifies the shift → verified work history and identity', async () => {
    const list = await ctx.http().get(`/api/v1/companies/${w.companyId}/shifts?status=CLOSED,NEEDS_REVIEW`).set(w.foreman.auth).expect(200);
    expect(list.body.items.map((s: { id: string }) => s.id)).toContain(shiftId);
    const detail = await ctx.http().get(`/api/v1/companies/${w.companyId}/shifts/${shiftId}`).set(w.foreman.auth).expect(200);
    expect(detail.body.events.map((e: { type: string }) => e.type)).toEqual(['WORK_STARTED', 'WORK_ENDED']);

    const v = await ctx.http().post(`/api/v1/companies/${w.companyId}/shifts/${shiftId}/verify`).set(w.foreman.auth).send({ breakMinutes: 60 }).expect(200);
    expect(v.body).toMatchObject({ status: 'VERIFIED', verifiedMinutes: 450 });
    // cannot verify twice
    await ctx.http().post(`/api/v1/companies/${w.companyId}/shifts/${shiftId}/verify`).set(w.foreman.auth).send({}).expect(409);

    const history = await ctx.http().get('/api/v1/me/shifts').set(w.worker.auth).expect(200);
    expect(history.body.items[0]).toMatchObject({ id: shiftId, status: 'VERIFIED', verifiedMinutes: 450 });
    expect(history.body.summary).toEqual({ verifiedShifts: 1, verifiedMinutes: 450 });

    const id = await ctx.http().get('/api/v1/me/identity').set(w.worker.auth).expect(200);
    expect(id.body.verified).toMatchObject({ verifiedWorkdays: 1, verifiedHours: 7.5, verifiedEmployers: 1, trustLevel: 'WORK_VERIFIED' });
    expect(id.body.employers[0]).toMatchObject({ companyId: w.companyId, verifiedDays: 1 });

    const notes = await ctx.http().get('/api/v1/me/notifications').set(w.worker.auth).expect(200);
    expect(notes.body.items.map((n: { type: string }) => n.type)).toContain('SHIFT_VERIFIED');
    expect(notes.body.unread).toBeGreaterThan(0);
  });

  it('audit trail records the whole chain', async () => {
    const logs = await ctx.http().get(`/api/v1/companies/${w.companyId}/audit-logs?limit=100`).set(w.admin.auth).expect(200);
    const actions = logs.body.items.map((l: { action: string }) => l.action);
    for (const a of ['COMPANY_CREATED', 'PROJECT_CREATED', 'SITE_CREATED', 'MEMBER_ADDED', 'WORKER_ADDED', 'WORK_STARTED', 'WORK_ENDED', 'SHIFT_VERIFIED']) {
      expect(actions).toContain(a);
    }
  });

  describe('vacancy → application → hire', () => {
    let vacancyId: string;
    let applicant: Awaited<ReturnType<typeof makeUser>>;
    let applicationId: string;

    it('company creates and publishes a vacancy', async () => {
      const v = await ctx.http().post(`/api/v1/companies/${w.companyId}/vacancies`).set(w.admin.auth).send({
        title: "G'isht teruvchi kerak",
        description: "3-qavat devorlari uchun tajribali g'isht teruvchi kerak.",
        category: 'BRICKLAYER',
        region: 'Namangan viloyati',
        city: 'Namangan',
        rateAmount: 250000,
        paymentPeriod: 'DAILY',
        workersNeeded: 1,
        siteId: w.siteId,
      }).expect(201);
      expect(v.body.status).toBe('DRAFT');
      vacancyId = v.body.id;
      // drafts are invisible on the job board
      applicant = await makeUser(ctx, 'Job Seeker');
      await ctx.http().get(`/api/v1/vacancies/${vacancyId}`).set(applicant.auth).expect(404);
      await ctx.http().post(`/api/v1/companies/${w.companyId}/vacancies/${vacancyId}/status`).set(w.admin.auth).send({ status: 'OPEN' }).expect(200);
    });

    it('worker browses, sees company trust, applies once', async () => {
      await ctx.http().put('/api/v1/me/worker-profile').set(applicant.auth).send({ primaryTrade: "G'isht teruvchi", selfReportedExperienceYears: 5 }).expect(200);
      const list = await ctx.http().get('/api/v1/vacancies?category=BRICKLAYER').set(applicant.auth).expect(200);
      expect(list.body.items).toHaveLength(1);
      expect(list.body.items[0].company.name).toBe('Company A');
      const d = await ctx.http().get(`/api/v1/vacancies/${vacancyId}`).set(applicant.auth).expect(200);
      expect(d.body.canApply).toBe(true);
      expect(d.body.companyTrust).toMatchObject({ verified: false, verifiedShifts: 1, workersManaged: 1 });
      expect(d.body.createdById).toBeUndefined();

      const a = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(applicant.auth).send({ coverNote: 'Ertadan boshlay olaman' }).expect(201);
      applicationId = a.body.id;
      const dup = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(applicant.auth).send({}).expect(409);
      expect(dup.body.code).toBe('ALREADY_APPLIED');
      // existing member cannot apply to own company
      const member = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(w.worker.auth).send({}).expect(409);
      expect(member.body.code).toBe('ALREADY_MEMBER');
    });

    it('company reviews applicants with verified identity and accepts → worker is hired, vacancy filled', async () => {
      const apps = await ctx.http().get(`/api/v1/companies/${w.companyId}/vacancies/${vacancyId}/applications`).set(w.admin.auth).expect(200);
      expect(apps.body.items[0]).toMatchObject({ id: applicationId, identity: { trustLevel: 'SELF_REPORTED', verifiedWorkdays: 0 } });
      const detail = await ctx.http().get(`/api/v1/companies/${w.companyId}/applications/${applicationId}`).set(w.admin.auth).expect(200);
      expect(detail.body.identity.selfReported.experienceYears).toBe(5);
      expect(detail.body.identity.verified.verifiedWorkdays).toBe(0);

      const r = await ctx.http().post(`/api/v1/companies/${w.companyId}/applications/${applicationId}/status`).set(w.admin.auth).send({ status: 'ACCEPTED' }).expect(200);
      expect(r.body).toMatchObject({ status: 'ACCEPTED', hired: true, vacancyFilled: true });
      const me = await ctx.http().get('/api/v1/me').set(applicant.auth).expect(200);
      expect(me.body.memberships[0]).toMatchObject({ role: 'WORKER', company: expect.objectContaining({ id: w.companyId }) });
      const today = await ctx.http().get('/api/v1/me/today').set(applicant.auth).expect(200);
      expect(today.body.assignments[0].site.id).toBe(w.siteId); // assigned to the vacancy's site
      const vac = await ctx.http().get(`/api/v1/companies/${w.companyId}/vacancies/${vacancyId}`).set(w.admin.auth).expect(200);
      expect(vac.body.status).toBe('FILLED');
      const mine = await ctx.http().get('/api/v1/me/applications').set(applicant.auth).expect(200);
      expect(mine.body.items[0].status).toBe('ACCEPTED');
      const notes = await ctx.http().get('/api/v1/me/notifications').set(applicant.auth).expect(200);
      expect(notes.body.items[0].type).toBe('APPLICATION_ACCEPTED');
      // admin was notified about the new application
      const adminNotes = await ctx.http().get('/api/v1/me/notifications').set(w.admin.auth).expect(200);
      expect(adminNotes.body.items.map((n: { type: string }) => n.type)).toContain('APPLICATION_RECEIVED');
      // closed vacancy no longer accepts applications
      const late = await makeUser(ctx, 'Late applicant');
      const closed = await ctx.http().post(`/api/v1/vacancies/${vacancyId}/apply`).set(late.auth).send({}).expect(409);
      expect(closed.body.code).toBe('VACANCY_NOT_OPEN');
    });
  });

  it('worker leaves the company but keeps verified history (portable identity)', async () => {
    const me = await ctx.http().get('/api/v1/me').set(w.worker.auth).expect(200);
    await ctx.http().post(`/api/v1/me/memberships/${me.body.memberships[0].id}/leave`).set(w.worker.auth).expect(204);
    const after = await ctx.http().get('/api/v1/me').set(w.worker.auth).expect(200);
    expect(after.body.memberships).toHaveLength(0);
    const id = await ctx.http().get('/api/v1/me/identity').set(w.worker.auth).expect(200);
    expect(id.body.verified.verifiedWorkdays).toBe(1);
    const history = await ctx.http().get('/api/v1/me/shifts').set(w.worker.auth).expect(200);
    expect(history.body.items).toHaveLength(1);
    // the company still owns its operational record
    await ctx.http().get(`/api/v1/companies/${w.companyId}/shifts/${shiftId}`).set(w.admin.auth).expect(200);
    // and the worker can no longer check in there
    const [r] = await sync(ctx, w.worker, ev('WORK_STARTED', w.siteId));
    expect(r).toMatchObject({ status: 'REJECTED', code: 'NOT_ASSIGNED_TO_SITE' });
  });
});
