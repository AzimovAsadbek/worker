import { JwtService } from '@nestjs/jwt';
import { TokenService } from '../src/auth/token.service';
import { createApp, nextPhone, resetDb, TestCtx } from './helpers';

describe('Auth (phone + OTP, JWT, refresh rotation)', () => {
  let ctx: TestCtx;

  beforeAll(async () => {
    ctx = await createApp();
    await resetDb(ctx.prisma);
  });
  afterAll(async () => {
    await ctx.app.close();
  });

  const requestOtp = (phone: string) => ctx.http().post('/api/v1/auth/otp/request').send({ phone });
  const verify = (phone: string, code: string) =>
    ctx.http().post('/api/v1/auth/otp/verify').send({ phone, code, platform: 'android', deviceId: 'device-e2e-001', deviceName: 'Test phone' });

  it('register == login: first verify creates the user; tokens work', async () => {
    const phone = '+998 91 000 00 01';
    const r = await requestOtp(phone).expect(200);
    expect(r.body).toMatchObject({ phone: '+998910000001', expiresInSeconds: 300, resendInSeconds: 60 });
    const v = await verify(phone, '111111').expect(200);
    expect(v.body.isNewUser).toBe(true);
    expect(v.body.accessToken).toBeTruthy();
    expect(v.body.refreshToken).toBeTruthy();
    expect(v.body.me.memberships).toEqual([]);
    const me = await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${v.body.accessToken}`).expect(200);
    expect(me.body.phone).toBe('+998910000001');
    // OTP is hashed at rest, never stored in clear text
    const ch = await ctx.prisma.otpChallenge.findFirst({ where: { phone: '+998910000001' } });
    expect(ch!.codeHash).not.toContain('111111');
    // login is audited
    expect(await ctx.prisma.auditLog.count({ where: { action: 'LOGIN', actorUserId: v.body.me.id } })).toBe(1);
  });

  it('rejects invalid phone numbers', async () => {
    const r = await requestOtp('12345').expect(400);
    expect(r.body.code).toBe('INVALID_PHONE');
  });

  it('enforces resend cooldown', async () => {
    const phone = nextPhone();
    await requestOtp(phone).expect(200);
    const r = await requestOtp(phone).expect(429);
    expect(r.body.code).toBe('OTP_COOLDOWN');
    expect(r.body.details.retryAfterSeconds).toBeGreaterThan(0);
  });

  it('wrong code → OTP_INVALID with attempts left, then lockout (brute-force protection)', async () => {
    const phone = nextPhone();
    await requestOtp(phone).expect(200);
    for (let i = 4; i >= 1; i--) {
      const r = await verify(phone, '000000').expect(400);
      expect(r.body.code).toBe('OTP_INVALID');
      expect(r.body.details.attemptsLeft).toBe(i);
    }
    const locked = await verify(phone, '000000').expect(429);
    expect(locked.body.code).toBe('OTP_TOO_MANY_ATTEMPTS');
    // even the right code no longer works for this challenge
    const after = await verify(phone, '111111').expect(400);
    expect(after.body.code).toBe('OTP_EXPIRED');
  });

  it('a code cannot be reused', async () => {
    const phone = nextPhone();
    await requestOtp(phone).expect(200);
    await verify(phone, '111111').expect(200);
    const again = await verify(phone, '111111').expect(400);
    expect(again.body.code).toBe('OTP_EXPIRED');
  });

  it('expired code is refused', async () => {
    const phone = nextPhone();
    await requestOtp(phone).expect(200);
    await ctx.prisma.otpChallenge.updateMany({ where: { phone }, data: { expiresAt: new Date(Date.now() - 1000) } });
    const r = await verify(phone, '111111').expect(400);
    expect(r.body.code).toBe('OTP_EXPIRED');
  });

  it('limits codes per phone per hour', async () => {
    const phone = nextPhone();
    const ch = { phone, codeHash: 'x', expiresAt: new Date(Date.now() + 60_000), consumedAt: new Date() };
    await ctx.prisma.otpChallenge.createMany({
      data: Array.from({ length: 5 }, (_, i) => ({ ...ch, createdAt: new Date(Date.now() - (10 + i) * 60_000) })),
    });
    const r = await requestOtp(phone).expect(429);
    expect(r.body.code).toBe('OTP_LIMIT_EXCEEDED');
  });

  describe('sessions', () => {
    let access: string;
    let refresh: string;
    const phone = nextPhone();

    beforeAll(async () => {
      await requestOtp(phone).expect(200);
      const v = await verify(phone, '111111').expect(200);
      access = v.body.accessToken;
      refresh = v.body.refreshToken;
    });

    it('refresh rotates the token; the new pair works', async () => {
      const r = await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: refresh }).expect(200);
      expect(r.body.refreshToken).not.toBe(refresh);
      await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${r.body.accessToken}`).expect(200);
      // old token replayed inside grace window: rejected but session survives
      const replay = await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: refresh }).expect(401);
      expect(replay.body.code).toBe('REFRESH_INVALID');
      await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${r.body.accessToken}`).expect(200);
      // old token replayed after the grace window: theft assumed → whole session revoked
      await ctx.prisma.refreshToken.updateMany({ where: { rotatedAt: { not: null } }, data: { rotatedAt: new Date(Date.now() - 60_000) } });
      await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: refresh }).expect(401);
      const revoked = await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${r.body.accessToken}`).expect(401);
      expect(revoked.body.code).toBe('SESSION_REVOKED');
      await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: r.body.refreshToken }).expect(401);
      expect(await ctx.prisma.auditLog.count({ where: { action: 'REFRESH_REUSE_DETECTED' } })).toBeGreaterThan(0);
      access = '';
    });

    it('logout invalidates the access token immediately', async () => {
      await requestOtp(phone).catch(() => undefined);
      await ctx.prisma.otpChallenge.deleteMany({ where: { phone } });
      await requestOtp(phone).expect(200);
      const v = await verify(phone, '111111').expect(200);
      access = v.body.accessToken;
      await ctx.http().get('/api/v1/auth/sessions').set('Authorization', `Bearer ${access}`).expect(200);
      await ctx.http().post('/api/v1/auth/logout').set('Authorization', `Bearer ${access}`).expect(204);
      const r = await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${access}`).expect(401);
      expect(r.body.code).toBe('SESSION_REVOKED');
      await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: v.body.refreshToken }).expect(401);
    });

    it('logout-all revokes every device', async () => {
      await ctx.prisma.otpChallenge.deleteMany({ where: { phone } });
      await requestOtp(phone).expect(200);
      const a = await verify(phone, '111111').expect(200);
      await ctx.prisma.otpChallenge.deleteMany({ where: { phone } });
      await requestOtp(phone).expect(200);
      const b = await verify(phone, '111111').expect(200);
      await ctx.http().post('/api/v1/auth/logout-all').set('Authorization', `Bearer ${a.body.accessToken}`).expect(204);
      await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${b.body.accessToken}`).expect(401);
    });

    it('deactivated users are locked out', async () => {
      await ctx.prisma.otpChallenge.deleteMany({ where: { phone } });
      await requestOtp(phone).expect(200);
      const v = await verify(phone, '111111').expect(200);
      await ctx.prisma.user.update({ where: { phone }, data: { isActive: false } });
      const r = await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${v.body.accessToken}`).expect(401);
      expect(r.body.code).toBe('USER_DEACTIVATED');
      await ctx.prisma.user.update({ where: { phone }, data: { isActive: true } });
    });
  });

  describe('JWT validation', () => {
    it('unauthenticated request → 401', async () => {
      const r = await ctx.http().get('/api/v1/me').expect(401);
      expect(r.body.code).toBe('UNAUTHORIZED');
    });
    it('garbage / tampered JWT → 401', async () => {
      await ctx.http().get('/api/v1/me').set('Authorization', 'Bearer abc.def.ghi').expect(401);
      const jwt = ctx.app.get(JwtService);
      const forged = jwt.sign({ sub: '00000000-0000-4000-8000-000000000000', sid: '00000000-0000-4000-8000-000000000000', typ: 'access' }, { secret: 'x'.repeat(40) });
      await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${forged}`).expect(401);
    });
    it('"alg: none" token → 401', async () => {
      const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
      const none = `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub: 'x', sid: 'y', typ: 'access' })}.`;
      await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${none}`).expect(401);
    });
    it('expired token → 401 TOKEN_EXPIRED', async () => {
      const jwt = ctx.app.get(JwtService);
      const expired = jwt.sign({ sub: 'u', sid: 's', typ: 'access' }, { expiresIn: -10 });
      const r = await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${expired}`).expect(401);
      expect(r.body.code).toBe('TOKEN_EXPIRED');
    });
  });

  describe('rate limiting', () => {
    beforeAll(() => {
      process.env.THROTTLE_DISABLED = 'false';
    });
    afterAll(() => {
      process.env.THROTTLE_DISABLED = 'true';
    });
    it('OTP request endpoint is limited per IP (20/min)', async () => {
      const codes: number[] = [];
      for (let i = 0; i < 22; i++) codes.push((await requestOtp(nextPhone())).status);
      expect(codes.filter((c) => c === 429).length).toBeGreaterThan(0);
      const r = await requestOtp(nextPhone()).expect(429);
      expect(r.body.code).toBe('RATE_LIMITED');
    });
    it('authenticated requests are limited per user, not per shared (CGNAT) IP', async () => {
      const tokens = ctx.app.get(TokenService);
      const a = await ctx.prisma.user.create({ data: { phone: nextPhone() } });
      const b = await ctx.prisma.user.create({ data: { phone: nextPhone() } });
      const ta = (await tokens.createSession(a.id, {})).accessToken;
      const tb = (await tokens.createSession(b.id, {})).accessToken;
      let limitedA = false;
      for (let i = 0; i < 125; i++) {
        const r = await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${ta}`);
        if (r.status === 429) limitedA = true;
      }
      expect(limitedA).toBe(true);
      // same IP, different user → not affected
      await ctx.http().get('/api/v1/me').set('Authorization', `Bearer ${tb}`).expect(200);
    });
  });
});
