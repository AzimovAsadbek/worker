# Worker OS — Architecture

## Overview

```
Flutter app (Android/iOS, role-based UI, Drift offline store)
        │  HTTPS (JSON REST, JWT)
        ▼
Nginx (TLS, security headers, body-size limit, rate-limit)
        │
        ▼
NestJS API — modular monolith (TypeScript, Prisma)
        │                         │
        ▼                         ▼
PostgreSQL 16              S3-compatible object storage (MinIO in dev)
```

**Modular monolith.** One deployable, strict module boundaries, one database. No microservices.

## Backend modules (`backend/src`)

| Module | Responsibility |
|---|---|
| `common/` | Guards (JWT, company role), decorators, error filter, pagination, geo/time utils |
| `prisma/` | Prisma client lifecycle |
| `auth/` | OTP request/verify, SMS provider, JWT, refresh rotation, sessions, logout |
| `users/` | `/me`, profile, memberships, device tokens, notification preferences |
| `companies/` | Company CRUD, trust signals, verification request, platform-admin verification |
| `memberships/` | Add/remove members (workers, foremen), roles, blocks |
| `projects/` | Projects CRUD |
| `sites/` | Sites CRUD, geofence, site assignments |
| `attendance/` | Work-event sync (check-in/out), rules, anomaly detection, shifts, verification, corrections, manual entry, dashboard |
| `tasks/` | Tasks, approvals |
| `evidence/` | Secure upload (magic bytes, size, sanitised names), signed URLs |
| `vacancies/` | Vacancies, public job board |
| `applications/` | Applications, status changes, hiring |
| `worker-identity/` | Verified stats + trust level computation |
| `disputes/` | Shift disputes and resolutions |
| `notifications/` | In-app notifications, FCM sender, scheduled reminders/alerts |
| `audit/` | Append-only audit log |
| `storage/` | S3 client wrapper |

### Request pipeline
`helmet → CORS allow-list → body limits → ThrottlerGuard (global + per-route) → JwtAuthGuard (session check) →
CompanyRolesGuard (membership + role, attaches membership to request) → ValidationPipe (whitelist, forbidNonWhitelisted) →
service (tenant-scoped queries, foreman site scoping) → AllExceptionsFilter (stable error codes)`.

### Tenant isolation
- Company-scoped routes: `/companies/:companyId/...` with `@CompanyRoles(...)`.
- Every query inside those services filters by `companyId` **and** the target id, so an id from another
  tenant resolves to `404`, never to data (IDOR-safe).
- Foremen: `SiteAccessService.assertSiteAccess()` restricts to assigned sites.
- Worker routes: `/me/...` always filter by `req.user.id`.

### Work events (event-sourced core)
`WorkEvent` is append-only. `Shift` is a projection (start/end/effective minutes/status/flags) updated in
the same DB transaction as the event. Corrections add `SHIFT_CORRECTED` with `{from, to, reason}`.
Idempotency: unique `(actorUserId, clientEventId)`; duplicates return the stored result.
Concurrency: check-in/out for a worker run in a serializable transaction with retry, plus a partial
unique index "one open shift per worker" as the last line of defence.

### Time
Sites carry an IANA timezone (default `Asia/Tashkent`). The **business date** of a shift is the site-local
date of its start. Midnight-crossing shifts stay on the start date. Timestamps are stored in UTC.

## Mobile (`mobile/lib`)

```
core/      api (Dio + refresh interceptor + error mapping), auth (secure token storage),
           db (Drift: pending_events, cache), sync (queue + backoff), location, theme, widgets, l10n (uz)
features/  auth, onboarding, worker (today, jobs, my_work, profile), company (dashboard, workers,
           shifts review, tasks, sites, projects, vacancies, applications, disputes), notifications
```
- State: Riverpod. Navigation: GoRouter with role-based shells. Storage: Drift (SQLite).
- Worker Today screen merges the server state with local pending events, so the worker always sees
  "Ish boshlandi 08:05 · yuborilmagan" even offline.

## Extensibility
- `Company.industry` (construction first; delivery, cleaning, warehouse, … later).
- `WorkEvent.source` (`MOBILE_APP`, `FOREMAN_APP`, `KIOSK`, `SYSTEM`) — a shared site device/kiosk
  can submit events on behalf of workers without the "1 worker = 1 device" assumption.
- `MANAGER` role exists in the enum and guards.
- `WorkEvent.flags` is the hook for a future risk engine.
