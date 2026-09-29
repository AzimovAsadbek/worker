import { buildWorld, createApp, ev, hoursAgo, makeUser, resetDb, sync, TestCtx, World } from './helpers';

const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]), Buffer.alloc(200, 1), Buffer.from([0xff, 0xd9])]);

describe('Security: tenant isolation, RBAC, IDOR, uploads', () => {
  let ctx: TestCtx;
  let a: World;
  let b: World;
  let shiftA: string;
  let taskA: string;

  beforeAll(async () => {
    ctx = await createApp();
    await resetDb(ctx.prisma);
    a = await buildWorld(ctx, 'A');
    b = await buildWorld(ctx, 'B');
    const [r] = await sync(ctx, a.worker, ev('WORK_STARTED', a.siteId, hoursAgo(8)));
    await sync(ctx, a.worker, ev('WORK_ENDED', a.siteId, hoursAgo(1)));
    shiftA = r.shift!.id;
    const t = await ctx.http().post(`/api/v1/companies/${a.companyId}/tasks`).set(a.foreman.auth)
      .send({ siteId: a.siteId, assigneeId: a.worker.id, title: "G'isht terish", quantity: 20, unit: 'm2' }).expect(201);
    taskA = t.body.id;
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  describe('Company B cannot touch Company A (tenant isolation → 404, no existence leak)', () => {
    const paths = () => [
      `/api/v1/companies/${a.companyId}`,
      `/api/v1/companies/${a.companyId}/members`,
      `/api/v1/companies/${a.companyId}/sites`,
      `/api/v1/companies/${a.companyId}/sites/${a.siteId}`,
      `/api/v1/companies/${a.companyId}/projects`,
      `/api/v1/companies/${a.companyId}/shifts`,
      `/api/v1/companies/${a.companyId}/shifts/${shiftA}`,
      `/api/v1/companies/${a.companyId}/dashboard`,
      `/api/v1/companies/${a.companyId}/tasks`,
      `/api/v1/companies/${a.companyId}/vacancies`,
      `/api/v1/companies/${a.companyId}/audit-logs`,
      `/api/v1/companies/${a.companyId}/workers/${a.worker.id}/identity`,
    ];
    it('GET endpoints', async () => {
      for (const p of paths()) {
        const r = await ctx.http().get(p).set(b.admin.auth);
        expect({ p, status: r.status }).toEqual({ p, status: 404 });
      }
    });
    it('mutations', async () => {
      await ctx.http().post(`/api/v1/companies/${a.companyId}/shifts/${shiftA}/verify`).set(b.admin.auth).send({}).expect(404);
      await ctx.http().post(`/api/v1/companies/${a.companyId}/members`).set(b.admin.auth).send({ phone: '+998901112233', role: 'WORKER' }).expect(404);
      await ctx.http().patch(`/api/v1/companies/${a.companyId}`).set(b.admin.auth).send({ name: 'Hacked' }).expect(404);
    });
    it('ids from company A used inside company B scope are not found (IDOR)', async () => {
      await ctx.http().get(`/api/v1/companies/${b.companyId}/shifts/${shiftA}`).set(b.admin.auth).expect(404);
      await ctx.http().post(`/api/v1/companies/${b.companyId}/shifts/${shiftA}/verify`).set(b.admin.auth).send({}).expect(404);
      await ctx.http().get(`/api/v1/companies/${b.companyId}/sites/${a.siteId}`).set(b.admin.auth).expect(404);
      await ctx.http().get(`/api/v1/companies/${b.companyId}/tasks/${taskA}`).set(b.admin.auth).expect(404);
      await ctx.http().post(`/api/v1/companies/${b.companyId}/sites/${b.siteId}/assignments`).set(b.admin.auth).send({ userId: a.worker.id }).expect(404);
      await ctx.http().post(`/api/v1/companies/${b.companyId}/sites`).set(b.admin.auth)
        .send({ projectId: a.projectId, name: 'Foreign site', latitude: 41, longitude: 71 }).expect(404);
      // B's worker cannot check in on A's site
      const [r] = await sync(ctx, b.worker, ev('WORK_STARTED', a.siteId));
      expect(r.code).toBe('NOT_ASSIGNED_TO_SITE');
      // B's admin cannot see A's worker identity (worker never applied to B)
      await ctx.http().get(`/api/v1/companies/${b.companyId}/workers/${a.worker.id}/identity`).set(b.admin.auth).expect(403);
    });
    it('company listing data never includes the other tenant', async () => {
      const shifts = await ctx.http().get(`/api/v1/companies/${b.companyId}/shifts`).set(b.admin.auth).expect(200);
      expect(shifts.body.items).toHaveLength(0);
      const members = await ctx.http().get(`/api/v1/companies/${b.companyId}/members`).set(b.admin.auth).expect(200);
      expect(members.body.items.map((m: { userId: string }) => m.userId)).not.toContain(a.worker.id);
    });
  });

  describe('RBAC', () => {
    it('foreman cannot use admin-only endpoints', async () => {
      const cases: [string, string, object?][] = [
        ['patch', `/api/v1/companies/${a.companyId}`, { name: 'x' }],
        ['post', `/api/v1/companies/${a.companyId}/projects`, { name: 'New project' }],
        ['post', `/api/v1/companies/${a.companyId}/sites`, { projectId: a.projectId, name: 'X', latitude: 41, longitude: 71 }],
        ['get', `/api/v1/companies/${a.companyId}/audit-logs`],
        ['get', `/api/v1/companies/${a.companyId}/blocks`],
        ['delete', `/api/v1/companies/${a.companyId}/sites/${a.siteId}`],
      ];
      for (const [method, path, body] of cases) {
        const req = (ctx.http() as unknown as Record<string, (p: string) => import('supertest').Test>)[method](path).set(a.foreman.auth);
        const r = body ? await req.send(body) : await req;
        expect({ path, method, status: r.status, code: r.body.code }).toEqual({ path, method, status: 403, code: 'ROLE_NOT_ALLOWED' });
      }
    });
    it('foreman can only add WORKERs, only to own sites', async () => {
      const r1 = await ctx.http().post(`/api/v1/companies/${a.companyId}/members`).set(a.foreman.auth).send({ phone: '+998971112233', role: 'COMPANY_ADMIN', siteIds: [a.siteId] }).expect(403);
      expect(r1.body.code).toBe('ROLE_NOT_ALLOWED');
      const r2 = await ctx.http().post(`/api/v1/companies/${a.companyId}/members`).set(a.foreman.auth).send({ phone: '+998971112233', role: 'WORKER', siteIds: [a.site2Id] }).expect(403);
      expect(r2.body.code).toBe('SITE_NOT_ASSIGNED');
    });
    it('foreman cannot see or act on sites not assigned to them', async () => {
      await ctx.http().get(`/api/v1/companies/${a.companyId}/sites/${a.site2Id}`).set(a.foreman.auth).expect(403);
      await ctx.http().get(`/api/v1/companies/${a.companyId}/shifts?siteId=${a.site2Id}`).set(a.foreman.auth).expect(403);
      await ctx.http().get(`/api/v1/companies/${a.companyId}/dashboard?siteId=${a.site2Id}`).set(a.foreman.auth).expect(403);
    });
    it('worker cannot use company-management endpoints', async () => {
      for (const p of ['/members', '/shifts', '/dashboard', '/tasks', '/vacancies', '/sites']) {
        const r = await ctx.http().get(`/api/v1/companies/${a.companyId}${p}`).set(a.worker.auth);
        expect({ p, status: r.status }).toEqual({ p, status: 403 });
      }
      await ctx.http().post(`/api/v1/companies/${a.companyId}/shifts/${shiftA}/verify`).set(a.worker.auth).send({}).expect(403);
    });
    it('last admin cannot be removed/demoted; users cannot change their own role', async () => {
      const members = await ctx.http().get(`/api/v1/companies/${a.companyId}/members?role=COMPANY_ADMIN`).set(a.admin.auth).expect(200);
      const self = members.body.items[0].id;
      const r = await ctx.http().patch(`/api/v1/companies/${a.companyId}/members/${self}`).set(a.admin.auth).send({ role: 'WORKER' }).expect(403);
      expect(r.body.code).toBe('CANNOT_MODIFY_SELF');
      const me = await ctx.http().get('/api/v1/me').set(a.admin.auth).expect(200);
      const leave = await ctx.http().post(`/api/v1/me/memberships/${me.body.memberships[0].id}/leave`).set(a.admin.auth).expect(409);
      expect(leave.body.code).toBe('LAST_ADMIN');
    });
    it('platform admin endpoints are hidden from normal users', async () => {
      await ctx.http().get('/api/v1/admin/companies').set(a.admin.auth).expect(404);
    });
  });

  describe('Worker ↔ worker isolation', () => {
    it("a worker cannot read another worker's shift, task or evidence", async () => {
      const other = await makeUser(ctx, 'Nosy worker');
      await ctx.http().get(`/api/v1/me/shifts/${shiftA}`).set(other.auth).expect(404);
      await ctx.http().get(`/api/v1/me/tasks/${taskA}`).set(other.auth).expect(404);
      await ctx.http().post(`/api/v1/me/tasks/${taskA}/submit`).set(other.auth).send({}).expect(404);
      await ctx.http().post(`/api/v1/me/tasks/${taskA}/evidence`).set(other.auth).attach('file', JPEG, 'a.jpg').expect(404);
      await ctx.http().post(`/api/v1/me/shifts/${shiftA}/disputes`).set(other.auth).send({ reason: 'Not my shift at all' }).expect(404);
    });
    it('a worker cannot forge work history: sync events are always attributed to the caller', async () => {
      const r = await ctx.http().post('/api/v1/work-events/sync').set(b.worker.auth)
        .send({ events: [{ ...ev('WORK_STARTED', b.siteId), subjectUserId: a.worker.id }] }).expect(400);
      expect(r.body.code).toBe('VALIDATION_FAILED'); // unknown field rejected (whitelist)
    });
  });

  describe('Evidence uploads', () => {
    const upload = (buf: Buffer, name: string, contentType = 'image/jpeg') =>
      ctx.http().post(`/api/v1/me/tasks/${taskA}/evidence`).set(a.worker.auth).attach('file', buf, { filename: name, contentType });

    it('accepts a real JPEG; only the uploader and site supervisors can download it', async () => {
      const r = await upload(JPEG, 'photo.jpg').expect(201);
      expect(r.body).toMatchObject({ kind: 'PHOTO', mimeType: 'image/jpeg', originalName: 'photo.jpg' });
      const dl = await ctx.http().get(`/api/v1/evidence/${r.body.id}/content`).set(a.foreman.auth).expect(200);
      expect(dl.headers['content-type']).toBe('image/jpeg');
      expect(dl.headers['x-content-type-options']).toBe('nosniff');
      await ctx.http().get(`/api/v1/evidence/${r.body.id}/content`).set(a.worker.auth).expect(200);
      await ctx.http().get(`/api/v1/evidence/${r.body.id}/content`).set(b.admin.auth).expect(404);
      await ctx.http().get(`/api/v1/evidence/${r.body.id}/content`).set(b.worker.auth).expect(404);
      const ev2 = await ctx.prisma.evidence.findUniqueOrThrow({ where: { id: r.body.id } });
      expect(ev2.storageKey).toMatch(new RegExp(`^companies/${a.companyId}/tasks/${taskA}/[0-9a-f-]{36}\\.jpg$`));
    });
    it('rejects a PHP script disguised as an image', async () => {
      const r = await upload(Buffer.from('<?php system($_GET["c"]); ?>'.padEnd(64, ' ')), 'shell.php.jpg').expect(415);
      expect(r.body.code).toBe('FILE_TYPE_NOT_ALLOWED');
    });
    it('rejects SVG / HTML (stored XSS)', async () => {
      await upload(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"></svg>'), 'x.svg', 'image/svg+xml').expect(415);
      await upload(Buffer.from('<html><script>alert(1)</script></html>'.padEnd(64)), 'x.html', 'text/html').expect(415);
    });
    it('rejects a JPEG with a mismatched extension', async () => {
      await upload(JPEG, 'photo.exe').expect(415);
    });
    it('path traversal filename is neutralised', async () => {
      const r = await upload(JPEG, '../../../etc/passwd.jpg').expect(201);
      expect(r.body.originalName).toBe('passwd.jpg');
    });
    it('rejects oversized files', async () => {
      const big = Buffer.concat([JPEG.subarray(0, 4), Buffer.alloc(600 * 1024)]);
      const r = await upload(big, 'big.jpg').expect(413);
      expect(r.body.code).toBe('FILE_TOO_LARGE');
    });
    it('requires a file', async () => {
      const r = await ctx.http().post(`/api/v1/me/tasks/${taskA}/evidence`).set(a.worker.auth).field('comment', 'no file').expect(400);
      expect(r.body.code).toBe('FILE_REQUIRED');
    });
  });

  describe('Input validation & injection', () => {
    it('unknown fields are rejected (mass assignment)', async () => {
      const r = await ctx.http().patch('/api/v1/me').set(a.worker.auth).send({ fullName: 'Ok Name', isPlatformAdmin: true }).expect(400);
      expect(r.body.code).toBe('VALIDATION_FAILED');
      const me = await ctx.http().get('/api/v1/me').set(a.worker.auth).expect(200);
      expect(me.body.isPlatformAdmin).toBe(false);
    });
    it('SQL-injection-looking search is treated as data', async () => {
      const r = await ctx.http().get(`/api/v1/companies/${a.companyId}/members?search=${encodeURIComponent("' OR 1=1; DROP TABLE \"User\"; --")}`).set(a.admin.auth).expect(200);
      expect(r.body.items).toHaveLength(0);
      expect(await ctx.prisma.user.count()).toBeGreaterThan(0);
    });
    it('non-uuid ids → 400/404, never 500', async () => {
      await ctx.http().get(`/api/v1/companies/not-a-uuid/sites`).set(a.admin.auth).expect(404);
      await ctx.http().get(`/api/v1/companies/${a.companyId}/shifts/not-a-uuid`).set(a.admin.auth).expect(400);
    });
    it('malformed JSON → 400', async () => {
      const r = await ctx.http().post('/api/v1/auth/otp/request').set('content-type', 'application/json').send('{"phone":').expect(400);
      expect(r.body.code).toBe('VALIDATION_FAILED');
    });
    it('oversized batch is rejected', async () => {
      const events = Array.from({ length: 51 }, () => ev('WORK_STARTED', a.siteId));
      await ctx.http().post('/api/v1/work-events/sync').set(a.worker.auth).send({ events }).expect(400);
    });
    it('security headers are present', async () => {
      const r = await ctx.http().get('/api/v1/health').expect(200);
      expect(r.headers['x-content-type-options']).toBe('nosniff');
      expect(r.headers['x-powered-by']).toBeUndefined();
      expect(r.headers['strict-transport-security']).toBeDefined();
    });
    it('CORS does not reflect arbitrary origins', async () => {
      const r = await ctx.http().get('/api/v1/health').set('Origin', 'https://evil.example').expect(200);
      expect(r.headers['access-control-allow-origin']).toBeUndefined();
    });
  });
});
