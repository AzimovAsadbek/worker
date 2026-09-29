import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Role } from '@prisma/client';
import { randomUUID } from 'crypto';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { TokenService } from '../src/auth/token.service';
import { configureApp } from '../src/bootstrap';
import { loadConfig } from '../src/config/configuration';
import { PrismaService } from '../src/prisma/prisma.service';

export interface TestCtx {
  app: INestApplication;
  prisma: PrismaService;
  http: () => ReturnType<typeof request>;
}

export async function createApp(): Promise<TestCtx> {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = moduleRef.createNestApplication({ logger: false });
  configureApp(app, loadConfig());
  await app.init();
  return { app, prisma: app.get(PrismaService), http: () => request(app.getHttpServer()) };
}

/** Wipes all data. TRUNCATE does not fire the append-only row triggers. */
export async function resetDb(prisma: PrismaService) {
  const tables = await prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> '_prisma_migrations'`;
  await prisma.$executeRawUnsafe(`TRUNCATE ${tables.map((t) => `"${t.tablename}"`).join(', ')} RESTART IDENTITY CASCADE`);
}

let phoneSeq = 1_000_000;
/** Unique valid Uzbek mobile number per call. */
export const nextPhone = () => `+99890${String(phoneSeq++).padStart(7, '0')}`;

export interface TestUser {
  id: string;
  phone: string;
  token: string;
  auth: { Authorization: string };
}

/** Creates a user + session directly (OTP flow itself is covered in auth.e2e-spec). */
export async function makeUser(ctx: TestCtx, fullName = 'Test User', phone = nextPhone()): Promise<TestUser> {
  const user = await ctx.prisma.user.upsert({ where: { phone }, create: { phone, fullName }, update: {} });
  const tokens = await ctx.app.get(TokenService).createSession(user.id, { deviceId: randomUUID(), platform: 'android' });
  return { id: user.id, phone, token: tokens.accessToken, auth: { Authorization: `Bearer ${tokens.accessToken}` } };
}

export const SITE_LAT = 41.0011;
export const SITE_LNG = 71.6726;
export const inside = { latitude: SITE_LAT + 0.0005, longitude: SITE_LNG, accuracy: 12 };
export const outside = { latitude: SITE_LAT + 0.02, longitude: SITE_LNG, accuracy: 12 };

export interface World {
  admin: TestUser;
  foreman: TestUser;
  worker: TestUser;
  companyId: string;
  projectId: string;
  siteId: string;
  site2Id: string;
}

/** Company with admin, one project, two sites, a foreman on site 1 and a worker on site 1. */
export async function buildWorld(ctx: TestCtx, label = 'A'): Promise<World> {
  const admin = await makeUser(ctx, `Admin ${label}`);
  const foreman = await makeUser(ctx, `Foreman ${label}`);
  const worker = await makeUser(ctx, `Worker ${label}`);
  const company = await ctx.http().post('/api/v1/companies').set(admin.auth).send({ name: `Company ${label}`, region: 'Namangan viloyati', city: 'Namangan' }).expect(201);
  const companyId = company.body.id;
  const project = await ctx.http().post(`/api/v1/companies/${companyId}/projects`).set(admin.auth).send({ name: `Project ${label}` }).expect(201);
  const siteBody = { projectId: project.body.id, latitude: SITE_LAT, longitude: SITE_LNG, radiusMeters: 200, shiftStart: '08:00', shiftEnd: '18:00' };
  const site = await ctx.http().post(`/api/v1/companies/${companyId}/sites`).set(admin.auth).send({ ...siteBody, name: `Site ${label}1` }).expect(201);
  const site2 = await ctx.http().post(`/api/v1/companies/${companyId}/sites`).set(admin.auth).send({ ...siteBody, name: `Site ${label}2`, latitude: SITE_LAT + 0.05 }).expect(201);
  await ctx.http().post(`/api/v1/companies/${companyId}/members`).set(admin.auth).send({ phone: foreman.phone, role: Role.FOREMAN, siteIds: [site.body.id] }).expect(201);
  await ctx.http().post(`/api/v1/companies/${companyId}/members`).set(foreman.auth).send({ phone: worker.phone, role: Role.WORKER, siteIds: [site.body.id] }).expect(201);
  return { admin, foreman, worker, companyId, projectId: project.body.id, siteId: site.body.id, site2Id: site2.body.id };
}

export function ev(type: 'WORK_STARTED' | 'WORK_ENDED', siteId: string, occurredAt: Date = new Date(), loc: Partial<typeof inside> | null = inside, extra: Record<string, unknown> = {}) {
  return { clientEventId: randomUUID(), type, siteId, occurredAt: occurredAt.toISOString(), ...(loc ?? {}), deviceId: 'device-test-0001', ...extra };
}

export async function sync(ctx: TestCtx, user: TestUser, ...events: ReturnType<typeof ev>[]) {
  const res = await ctx.http().post('/api/v1/work-events/sync').set(user.auth).send({ events }).expect(200);
  return res.body.results as { clientEventId: string; status: string; code?: string; shift?: { id: string; status: string; flags: string[]; workedMinutes: number } }[];
}

export const hoursAgo = (h: number) => new Date(Date.now() - h * 3600_000);
