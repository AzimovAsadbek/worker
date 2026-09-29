# Worker OS

**Workforce management → verified work → worker identity → job opportunities.**

Worker OS lets a construction company (and later delivery, cleaning, warehouse… companies) run its sites
from a phone, and turns every real work occurrence into an **append-only, supervisor-verified work record**.
Workers keep a **portable, verified work history** (verified workdays, hours, tasks, employers) that they
use to get the next job on the built-in job board.

- Product spec: [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Security audit: [docs/SECURITY_AUDIT.md](docs/SECURITY_AUDIT.md)
- QA / production-readiness report: [docs/QA_REPORT.md](docs/QA_REPORT.md)

## Architecture

```
Flutter app (Android / iOS)  ── HTTPS/JSON ──▶  Nginx (TLS, edge rate limits)
  role-based UI, Drift offline outbox                 │
                                                      ▼
                                  NestJS API (modular monolith, Prisma)
                                     │                          │
                                     ▼                          ▼
                              PostgreSQL 16          S3-compatible storage (evidence photos)
```

| Layer | Tech |
|---|---|
| Mobile | Flutter 3.47 · Dart 3.13 · Riverpod 3 · Dio · Drift (SQLite) · GoRouter · Geolocator · image_picker |
| API | NestJS 11 · TypeScript · Prisma 6 · PostgreSQL 16 · JWT + rotating refresh tokens · Swagger |
| Storage | Any S3-compatible store (SeaweedFS in the dev stack) — files are private, streamed by the API after an access check |
| Infra | Docker Compose · Nginx (HTTPS) |
| Push | FCM HTTP v1 (server side, enabled by env) + in-app notification center |

## Repository layout

```
backend/            NestJS API (src/<module>, prisma/, test/ e2e, scripts/smoke.mjs)
mobile/             Flutter app (lib/core, lib/features/{auth,worker,company,...}, test/)
infra/nginx/        Reverse proxy config + dev certificate script
infra/postgres/     DB init (creates the *_test database)
docs/               Product spec, architecture, security audit, QA report
docker-compose.yml  postgres · s3 · api · nginx
```

## Prerequisites

- Docker + Docker Compose v2
- Node.js ≥ 20 (22/24 tested) and npm ≥ 10 — for running the API outside Docker / tests
- Flutter ≥ 3.47 (stable) — mobile app
- Android SDK + JDK 17 — only to build the APK (`flutter doctor` must be green for Android)

## Environment variables

Copy and fill in (never commit `.env`):

```bash
cp .env.example .env                 # shared: compose + API
cp backend/.env.example backend/.env # local API: DATABASE_URL, TEST_DATABASE_URL
```

Generate secrets:

```bash
openssl rand -base64 48   # JWT_ACCESS_SECRET
```

```bash
openssl rand -base64 32   # OTP_PEPPER
```

| Variable | Purpose |
|---|---|
| `POSTGRES_*` | Database credentials (compose) |
| `DATABASE_URL` / `TEST_DATABASE_URL` | Prisma connection (tests refuse to run unless the DB name ends with `_test`) |
| `JWT_ACCESS_SECRET` (≥ 32 chars) | Access-token signing key (HS256, 15 min tokens) |
| `OTP_PEPPER` (≥ 16 chars) | HMAC pepper for OTP hashes |
| `SMS_PROVIDER` | `dev` (fixed `OTP_DEV_CODE`, **refused in production**) or `eskiz` (Eskiz.uz, needs `ESKIZ_EMAIL/PASSWORD/FROM`) |
| `S3_*` | Object storage endpoint, bucket, credentials |
| `CORS_ORIGINS` | Browser origins allow-list (mobile apps don't need CORS) |
| `TRUST_PROXY` | Number of proxies in front of the API (`1` behind nginx) |
| `FCM_SERVICE_ACCOUNT_BASE64` | Optional — enables push; in-app notifications work without it |
| `JOBS_ENABLED` | Shift reminders, absent/late alerts, checkout reminders |
| `SWAGGER_ENABLED` | API docs at `/api/docs` (defaults to off in production) |

The API refuses to start with missing/weak secrets, `SMS_PROVIDER=dev` in production, or `THROTTLE_DISABLED` in production.

## Running locally

### 1. Dependencies (PostgreSQL + S3)

```bash
docker compose up -d postgres s3
```

### 2. API

```bash
cd backend && npm ci
```

```bash
npx prisma migrate deploy && npm run seed
```

```bash
npm run start:dev
```

API: `http://localhost:3000/api/v1` · Swagger: `http://localhost:3000/api/docs` · Health: `/api/v1/health`

### 3. Mobile app

```bash
cd mobile && flutter pub get
```

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

`10.0.2.2` is the host machine from the Android emulator (debug builds allow cleartext only to
`10.0.2.2` / `localhost`). For a physical phone use your machine's LAN address or the HTTPS stack.

### Full stack behind HTTPS (pilot-like)

```bash
./infra/nginx/gen-dev-cert.sh
```

```bash
docker compose up -d --build
```

The API container applies pending migrations on start. Seed demo data inside the container:

```bash
docker compose exec api npm run seed:prod
```

In production mount real certificates at `infra/nginx/certs/fullchain.pem` and `privkey.pem`,
set `NODE_ENV=production`, `SMS_PROVIDER=eskiz`, `SWAGGER_ENABLED=false`.

## Database

- Schema: `backend/prisma/schema.prisma`; migrations in `backend/prisma/migrations` (never edit applied ones).
- Invariants enforced in SQL: one OPEN shift per worker (partial unique index), one ACTIVE assignment per
  site/user, coordinate/radius checks, and **`WorkEvent` / `AuditLog` are append-only (triggers reject UPDATE/DELETE)**.
- Check migration status: `npm run prisma:status`

## Demo accounts (after `npm run seed`, `SMS_PROVIDER=dev`, OTP = `OTP_DEV_CODE`, e.g. `111111`)

| Phone | Role |
|---|---|
| +998 90 000 00 01 | Company admin — Taraqqiyot Construction |
| +998 90 000 00 02 | Foreman — Yangiqo'rg'on Residential Complex (Blok A) |
| +998 90 000 00 03 | Foreman — Namangan Commercial Center |
| +998 90 000 01 01 … 01 16 | Workers (01 01–01 03 are resident workers) |
| +998 90 000 02 01 | Job seeker (not employed; has an application) |

All demo people and numbers are fictional. The seed refuses to run in production.

## Testing

```bash
cd backend && npm run lint && npm run typecheck && npm test
```

```bash
cd backend && npm run test:e2e
```

```bash
cd mobile && flutter analyze && flutter test
```

Smoke test against any running deployment (dev OTP only):

```bash
cd backend && BASE_URL=http://localhost:3000/api/v1 node scripts/smoke.mjs
```

| Suite | Count | Covers |
|---|---|---|
| API unit | 60 | attendance rules (geofence, clock skew, lateness, midnight/night shifts, missed checkout), identity & trust levels, upload validation, phone/geo/time utils |
| API integration/E2E | 83 | OTP auth, refresh rotation & reuse detection, logout/session revocation, full critical flow, offline/duplicate/concurrent sync, resident worker, fraud flags, corrections & disputes, tenant isolation, RBAC, IDOR, malicious uploads, rate limits |
| Mobile | 34 | offline outbox (queue, backoff, crash recovery, dedupe, per-user isolation), Today state derivation, error-code messages, model parsing, widget states |
| Smoke | 13 | the end-to-end business chain over HTTPS |

## Build

```bash
cd backend && npm run build
```

```bash
cd mobile && flutter build apk --release --dart-define=API_BASE_URL=https://api.your-domain.uz/api/v1
```

Release signing: create `android/key.properties` + keystore (git-ignored) and reference them in
`android/app/build.gradle.kts` before publishing to Play Market.

## API documentation

Swagger/OpenAPI at `/api/docs` (JSON at `/api/docs-json`) when `SWAGGER_ENABLED=true`.
All errors share one shape: `{ statusCode, code, message, details, path, timestamp }` — `code` is stable
and the app maps it to a specific Uzbek message (e.g. `OUTSIDE_GEOFENCE` → *"Siz obyekt hududidan tashqaridasiz (~734 m)"*).

## Troubleshooting

| Symptom | Fix |
|---|---|
| API exits: `Missing required environment variable …` | Fill `.env` (see above); secrets have minimum lengths |
| `SMS_PROVIDER=dev is not allowed in production` | Configure Eskiz credentials, or run with `NODE_ENV=development` locally |
| Emulator cannot reach API | Use `10.0.2.2`, not `localhost`; release builds require HTTPS |
| Check-in says "outside the site" | Site coordinates/radius wrong — recapture them standing on site (Sites → Create site → *use current location*) or increase the radius |
| Events stuck "Yuborilmagan" | No connectivity to the API; they retry automatically (5 s → 5 min) and on reconnect; "Hozir yuborish" forces it |
| `prisma migrate dev` wants to reset | Don't edit applied migrations; create a new one |
| Push notifications don't arrive | Set `FCM_SERVICE_ACCOUNT_BASE64`; the mobile FCM client is not wired yet (see QA report) — in-app notifications work |
