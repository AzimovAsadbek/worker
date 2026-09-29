#!/usr/bin/env node
/**
 * End-to-end smoke test against a running deployment (dev OTP required: SMS_PROVIDER=dev).
 *
 *   BASE_URL=https://localhost/api/v1 OTP_CODE=111111 node scripts/smoke.mjs
 *   (add NODE_TLS_REJECT_UNAUTHORIZED=0 only for a local self-signed certificate)
 *
 * Flow: register admin → company → project → site → foreman → worker → check-in (+ duplicate) →
 * offline-style late sync of check-out → dashboard → verify → worker history & identity →
 * vacancy → job seeker applies → company accepts → seeker becomes a worker. Exits non-zero on failure.
 */
import { randomUUID } from 'node:crypto';

const BASE = process.env.BASE_URL ?? 'http://localhost:3000/api/v1';
const CODE = process.env.OTP_CODE ?? '111111';
const rnd = () => String(Math.floor(1_000_000 + Math.random() * 8_999_999));
const phone = () => `+99899${rnd()}`;
let step = 0;

async function call(method, path, { token, body, expect = [200, 201, 204] } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  if (!expect.includes(res.status)) throw new Error(`${method} ${path} → ${res.status} ${text}`);
  return json;
}
const ok = (msg) => console.log(`  ✓ ${String(++step).padStart(2)} ${msg}`);
const assert = (cond, msg) => {
  if (!cond) throw new Error(`Assertion failed: ${msg}`);
};

async function login(p, name) {
  await call('POST', '/auth/otp/request', { body: { phone: p } });
  const r = await call('POST', '/auth/otp/verify', { body: { phone: p, code: CODE, deviceId: randomUUID(), platform: 'android' } });
  if (name) await call('PATCH', '/me', { token: r.accessToken, body: { fullName: name } });
  return { token: r.accessToken, id: r.me.id, phone: p };
}

const LAT = 41.0011;
const LNG = 71.6726;
const ev = (type, siteId, at, extra = {}) => ({
  clientEventId: randomUUID(), type, siteId, occurredAt: at.toISOString(), latitude: LAT + 0.0004, longitude: LNG, accuracy: 12, deviceId: 'smoke-device-01', ...extra,
});

async function main() {
  console.log(`Worker OS smoke test → ${BASE}`);
  const health = await call('GET', '/health');
  assert(health.database, 'database reachable');
  ok(`health: ${health.status}`);

  const admin = await login(phone(), 'Smoke Admin');
  const company = await call('POST', '/companies', { token: admin.token, body: { name: `Smoke Co ${rnd()}`, city: 'Namangan' } });
  const c = `/companies/${company.id}`;
  ok('admin registered and created a company');
  const project = await call('POST', `${c}/projects`, { token: admin.token, body: { name: 'Smoke Project' } });
  const site = await call('POST', `${c}/sites`, { token: admin.token, body: { projectId: project.id, name: 'Smoke Site', latitude: LAT, longitude: LNG, radiusMeters: 200 } });
  ok('project + site (geofence) created');

  const foreman = await login(phone(), 'Smoke Foreman');
  await call('POST', `${c}/members`, { token: admin.token, body: { phone: foreman.phone, role: 'FOREMAN', siteIds: [site.id] } });
  const worker = await login(phone(), 'Smoke Worker');
  await call('POST', `${c}/members`, { token: foreman.token, body: { phone: worker.phone, role: 'WORKER', siteIds: [site.id] } });
  ok('foreman added by admin, worker added by foreman');

  const today = await call('GET', '/me/today', { token: worker.token });
  assert(today.assignments[0]?.site.id === site.id, 'worker sees the site');
  const start = ev('WORK_STARTED', site.id, new Date(Date.now() - 9 * 3600_000));
  let [r] = (await call('POST', '/work-events/sync', { token: worker.token, body: { events: [start] } })).results;
  assert(r.status === 'ACCEPTED', `check-in accepted (${r.status} ${r.code ?? ''})`);
  [r] = (await call('POST', '/work-events/sync', { token: worker.token, body: { events: [start] } })).results;
  assert(r.status === 'DUPLICATE', 'retry is idempotent');
  ok('check-in accepted; retried sync is DUPLICATE (idempotent)');

  [r] = (await call('POST', '/work-events/sync', { token: worker.token, body: { events: [ev('WORK_STARTED', site.id, new Date(), { latitude: LAT + 0.05 })] } })).results;
  assert(r.status === 'REJECTED', 'second check-in rejected');
  ok(`double check-in rejected (${r.code})`);

  [r] = (await call('POST', '/work-events/sync', { token: worker.token, body: { events: [ev('WORK_ENDED', site.id, new Date(Date.now() - 45 * 60_000))] } })).results;
  assert(r.status === 'ACCEPTED' && r.shift.status === 'CLOSED', 'check-out closes the shift');
  assert(r.shift.flags.includes('LATE_SYNC'), 'late offline sync flagged');
  ok(`check-out synced late (offline) → ${r.shift.workedMinutes} min, flags ${r.shift.flags.join(',')}`);

  const dash = await call('GET', `${c}/dashboard`, { token: foreman.token });
  assert(dash.totals.awaitingVerification >= 1, 'dashboard shows pending verification');
  ok(`foreman dashboard: ${dash.totals.present}/${dash.totals.assigned} present, ${dash.totals.awaitingVerification} awaiting verification`);

  const verified = await call('POST', `${c}/shifts/${r.shift.id}/verify`, { token: foreman.token, body: { breakMinutes: 60 } });
  assert(verified.status === 'VERIFIED', 'verified');
  ok(`shift verified: ${verified.verifiedMinutes} min`);

  const identity = await call('GET', '/me/identity', { token: worker.token });
  assert(identity.verified.verifiedWorkdays === 1, 'identity counts the verified day');
  ok(`worker identity: ${identity.verified.verifiedWorkdays} day, ${identity.verified.verifiedHours} h, trust ${identity.verified.trustLevel}`);

  const vacancy = await call('POST', `${c}/vacancies`, {
    token: admin.token,
    body: { title: 'Betonchi kerak', description: 'Smoke test vacancy description.', category: 'CONCRETE', rateAmount: 200000, paymentPeriod: 'DAILY', siteId: site.id, publish: true },
  });
  const seeker = await login(phone(), 'Smoke Seeker');
  const app = await call('POST', `/vacancies/${vacancy.id}/apply`, { token: seeker.token, body: { coverNote: 'Tayyorman' } });
  await call('POST', `/vacancies/${vacancy.id}/apply`, { token: seeker.token, body: {}, expect: [409] });
  ok('vacancy published; job seeker applied (duplicate refused)');

  const apps = await call('GET', `${c}/vacancies/${vacancy.id}/applications`, { token: admin.token });
  assert(apps.items[0].identity, 'applicant identity summary visible');
  const accepted = await call('POST', `${c}/applications/${app.id}/status`, { token: admin.token, body: { status: 'ACCEPTED' } });
  assert(accepted.hired && accepted.vacancyFilled, 'hired and filled');
  const seekerToday = await call('GET', '/me/today', { token: seeker.token });
  assert(seekerToday.assignments[0]?.site.id === site.id, 'hired worker assigned to site');
  ok('company accepted → seeker hired and assigned to the site; vacancy FILLED');

  await call('GET', `${c}/shifts`, { token: worker.token, expect: [403] });
  const outsider = await login(phone(), 'Outsider');
  await call('GET', `${c}/shifts`, { token: outsider.token, expect: [404] });
  ok('RBAC + tenant isolation enforced (worker 403, outsider 404)');

  console.log(`\nSMOKE OK — ${step} checks passed`);
}

main().catch((e) => {
  console.error(`\nSMOKE FAILED at step ${step + 1}: ${e.message}`);
  process.exit(1);
});
