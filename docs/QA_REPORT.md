# QA & production-readiness report — Worker OS MVP

Date: 2026-09-30 · Commit range: `8ddd563..HEAD`

## What was verified

| Check | Result |
|---|---|
| API lint (eslint) / typecheck (tsc strict) / build | ✅ clean |
| API unit tests | ✅ 60/60 |
| API integration + E2E (real NestJS + PostgreSQL) | ✅ 83/83 |
| Prisma migrations on a fresh DB (`migrate deploy`, test DB) | ✅ |
| Demo seed (idempotent, refuses production) | ✅ |
| Production dependency audit (`npm audit --omit=dev`) | ✅ 0 vulnerabilities |
| `docker compose build` + `up` (postgres, s3, api, nginx), health checks | ✅ all healthy |
| HTTPS smoke test through nginx (`scripts/smoke.mjs`, 13 business checks) | ✅ 13/13 |
| `flutter analyze` (strict casts / raw types + extra lints) | ✅ no issues |
| `flutter test` | ✅ 34/34 |
| Manual UI walkthrough of the Flutter app (web QA build, 375×812, real API + seed data) | ✅ see below |
| `flutter build apk --release` | ⛔ **not run** — no Android SDK on the build machine (installing it requires accepting the Android SDK license, which needs the owner's approval) |
| Real Android device / emulator test | ⛔ not possible for the same reason |

### Manual walkthrough (Flutter web build against the live API)
Foreman login (OTP) → 10-second dashboard (present/absent/late/pending checkout, awaiting verification,
tasks to review) → verification queue → shift with event timeline, GPS distance/accuracy and flags → verify
with break minutes → event appended ("Tasdiqlandi · Bahodir Mirzayev") → logout (confirm) → worker login →
Today screen → START while 2.2 km away → *"Siz obyekt hududidan tashqaridasiz (~2224 m)"* → START on site →
working → **API stopped (offline)** → END → *"Internet mavjud emas. Ma'lumot saqlandi…"*, "Yuborilmagan"
badge and outbox banner → API restarted → automatic retry delivered the event → shift "Tasdiqlash kutilmoqda".

Bugs found and fixed during the walkthrough:
1. List rows squeezed titles into a 1-word column when a long status badge was present → new `RecordTile`.
2. Dashboard tile label broke mid-word ("Yakunlamaga-n") → single-word labels scale down.
3. "Hozir yuborish" did not bypass the retry backoff → `syncNow(force: true)` (+ regression test).
4. After finishing the day a big green START invited an accidental second shift → secondary "new shift" action.
5. Outbox/rejection banners were cramped → readable layout.
6. Deep link lost on app start → preserved through the splash redirect.
7. (API) per-IP rate limit would block whole crews behind mobile carrier NAT → per-user limits.
8. (Rules) night shifts were treated as "missed checkout" right after midnight → fixed rule + tests.

## Final self-audit

**Product**
- *Can a real foreman use it?* Yes: one dashboard answers "how many today / who is absent / late / not checked out"; bulk verify; manual entry for workers without phones.
- *Can a real worker use it?* Yes: one screen, one huge button, Uzbek text, specific error messages, works offline.
- *No internet?* Taps are written to SQLite first, delivered later in order, idempotently; the UI shows the pending state.
- *Worker lives on site?* Resident mode: GPS presence never counts; missed checkout → closed with 0 minutes and sent to review; long shifts need review.
- *Worker changes phone?* Identity is the phone number, not the device; history is server-side. (Unsynced taps on a lost phone are lost — see limitations.)
- *Worker in several companies?* Memberships per company; one open shift at a time across companies; history and identity aggregate all employers.

**Security** — see [SECURITY_AUDIT.md](SECURITY_AUDIT.md): tenant isolation (404), RBAC, no worker-to-worker access, events always attributed to the caller, append-only history, safe uploads.

**Data integrity** — events cannot be deleted/updated (DB triggers); duplicates impossible (unique key + partial index + serializable transactions); every important action is in the audit log.

**UX** — loading / empty / error+retry / offline states on every screen; first-time worker without a site gets a clear next step; errors are specific.

**Technical** — clean builds, migrations, seed, tests, Swagger, Docker, validated env config.

## Known limitations (honest list)

1. **APK not built / not device-tested here** (no Android SDK). Run `flutter doctor`, then `flutter build apk --release`.
2. **Push notifications:** server-side FCM sender + device-token endpoint are implemented; the Flutter FCM client is not wired (needs a Firebase project and `google-services.json`). In-app notification center works.
3. **SMS:** Eskiz.uz provider implemented but not verified against the live API (no credentials).
4. **Site location** is captured from the admin's current GPS or typed coordinates — no map picker (avoids a Maps API key for the MVP).
5. **Unsynced taps on a lost/broken phone are lost**; the foreman can enter them manually (flagged `MANUAL_ENTRY`).
6. Offline mode covers attendance (the core flow). Other screens need connectivity and show a retry state.
7. No web admin (by design for MVP); no payroll, payments, AI, analytics.
8. Attendance % in the identity uses site work-days and assignment periods; public holidays are not modelled yet.
9. No account deletion / data export yet (recommended before public launch).
10. iOS build not verified (no Xcode on the build machine); iOS permission strings are configured.

## Recommended next steps

1. Install Android SDK → build/sign the APK → pilot on 1 site with 1 foreman and 10–20 workers for 2 weeks.
2. Wire FCM on mobile; get Eskiz credentials and an approved SMS template.
3. Deploy: managed PostgreSQL with backups, S3 bucket, domain + Let's Encrypt, `NODE_ENV=production`.
4. Measure the hypotheses: daily active foremen, % shifts verified within 24 h, disputes per 100 shifts,
   worker identity views and applications per worker.
5. Then: map picker for sites, kiosk/shared-device mode (`EventSource.KIOSK` already in the model),
   structured employer reviews, holiday calendar, web admin for large companies.
