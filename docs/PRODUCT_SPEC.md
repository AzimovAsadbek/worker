# Worker OS — MVP Product Specification

## 1. Thesis

```
Attendance → Work Event → Verification → Verified Work → Worker Identity → Opportunity
```

Worker OS turns every real work occurrence into a **verified, append-only work record**.
Companies get a simple tool to run a construction site; workers get a **portable, verified work history**
that they can use to get their next job.

## 2. Hypotheses the MVP tests

1. A company / foreman on a real construction site will use Worker OS **daily** to manage workers,
   start/end work and keep history.
2. A worker sees value in a verified work history and uses it to find new jobs.

Everything not needed to test these is out of scope (see §10).

## 3. Roles

| Role | Scope | MVP |
|---|---|---|
| `COMPANY_ADMIN` | Full access inside one company (tenant) | ✅ |
| `MANAGER` | Company-wide operations, no company settings / role management | enum + guards ready |
| `FOREMAN` | Only sites assigned to them | ✅ |
| `WORKER` | Only own data; portable identity across companies | ✅ |

A single user (phone number) can have different roles in different companies
(e.g. worker in company A, foreman in company B). Role is per `CompanyMembership`.

## 4. Tenancy

`Company` is the tenant. Projects, sites, memberships, shifts, work events, tasks, evidence,
vacancies and applications carry `companyId`. Every company-scoped endpoint lives under
`/companies/:companyId/...` and is gated by a membership + role guard; foremen are further
restricted to their assigned sites in the service layer.

**Ownership principle:** the company owns its operational data; the worker owns the portable
identity/history derived from **their own verified records**. When a worker leaves a company,
the membership becomes `REMOVED` but shifts/tasks remain, so the history is not lost.

## 5. Core flows

### 5.1 Auth (phone + OTP)
Phone → OTP (SMS) → verify → user (auto-created on first login) → memberships → role-based home.
- OTP: 6 digits, 5 min expiry, max 5 attempts per code, resend cooldown 60 s, max 5 codes/hour/phone,
  hashed at rest (HMAC-SHA256 with server pepper), never logged.
- Access token (JWT, 15 min) + opaque refresh token (30 days) with **rotation and reuse detection**
  (a reused refresh token revokes the whole session family).
- Sessions are per device; user can list and revoke them; logout revokes the session immediately.

### 5.2 Company admin
Register → create company → create project → create site (map pin + radius + shift hours) →
add foreman (by phone) → add workers (by phone) → assign to sites.
Dashboard: workers, projects, sites, attendance today, work history (shifts), vacancies, applications, company profile.

### 5.3 Foreman — "10-second dashboard"
Opening the app answers: **how many workers today, who is absent, who is late, who has not checked out.**
Foreman can: add worker to own site, assign/unassign, see attendance & shifts, manually check a worker
in/out (no-phone scenario), verify / reject / correct shifts (bulk verify), create & review tasks,
resolve disputes, create vacancies for own sites.

### 5.4 Worker — "5-second Today screen"
Answers: **where do I work today, have I started, have I finished.**
Tabs: **Bugun (Today) · Ishlar (Jobs) · Mening ishim (My Work) · Profil**.
Huge buttons: **ISHNI BOSHLASH** / **ISHNI YAKUNLASH**. Sync status is always visible.

### 5.5 Check-in / check-out = events
Every press creates an immutable `WorkEvent` (`WORK_STARTED` / `WORK_ENDED`) with
worker, site, client timestamp, server receive time, lat/lng/accuracy, mock-location flag,
device id, source, client idempotency key. A `Shift` is a projection over these events.

Server rules (see `backend/src/attendance/attendance.rules.ts`):
- Worker must be an **active member** of the site's company **and actively assigned** to the site.
- Check-in: rejected if clearly outside geofence (`distance − accuracy > radius`), if location is
  missing, if already checked in, if timestamp is in the future (>5 min skew) or older than 72 h.
- Check-out: requires an open shift; end time must be after start. Checkout outside the geofence is
  **accepted but flagged** (a worker may walk out and then remember).
- An open shift from a previous business day is auto-closed as **`NEEDS_REVIEW` / `MISSED_CHECKOUT`
  with 0 counted minutes** when the worker checks in the next morning (resident-worker safe).
- **GPS presence ≠ work.** Hours only count after supervisor verification.

### 5.6 Resident workers
`SiteAssignment.isResident = true`. For them, geofence presence has no meaning, so the evidence is:
explicit start + explicit end + shift window + supervisor confirmation. Being on site 24 h never
produces 24 h of work: missed checkouts produce 0 counted minutes until a foreman corrects them.

### 5.7 Offline-first
Events are written to the local Drift DB first (`PENDING`), then synced in order via
`POST /work-events/sync` (batch, idempotent on `(actor, clientEventId)`).
Statuses: `PENDING → SYNCING → SYNCED | REJECTED`; transient failures retry with exponential backoff
(connectivity change, app resume, timer, manual). A crash during sync resets `SYNCING → PENDING`
on start; re-sending is safe because the server answers `DUPLICATE` with the original result.

### 5.8 Anti-fraud (flags, not verdicts)
Flags stored on events and aggregated onto shifts: `OUTSIDE_GEOFENCE`, `LOW_ACCURACY`,
`MOCK_LOCATION`, `IMPOSSIBLE_TRAVEL`, `SHARED_DEVICE`, `CLOCK_SKEW`, `LATE_SYNC`, `LONG_SHIFT`,
`MISSED_CHECKOUT`, `MANUAL_ENTRY`. They are shown to the foreman during verification; nothing is
auto-punished and nobody is blacklisted platform-wide.

### 5.9 Verification & corrections
Foreman/admin: verify (single/bulk), reject (reason required), correct (new start/end + reason
required). Corrections append a `SHIFT_CORRECTED` event carrying the original and new values,
the actor and the reason; history is never silently overwritten.

### 5.10 Disputes
Worker disputes a shift ("I worked until 18:00") with a claimed time and reason. Foreman/admin resolves
(accept → correction event + verify; reject → reason). Both statements stay in the audit trail.

### 5.11 Tasks & evidence (P1)
Foreman assigns a task (e.g. "G'isht terish, 20 m²") → worker starts → submits with photos/comment →
foreman approves / rejects / requests changes → `APPROVED` tasks count as **verified tasks**.

### 5.12 Worker identity
Self-reported (profile: trade, experience years, bio) is shown **separately** from verified data:
verified workdays, verified hours, attendance % (last 90 days), punctuality %, verified tasks,
verified employers, projects.

Trust levels (explicit, computed server-side):
| Level | Criteria |
|---|---|
| `SELF_REPORTED` | profile only |
| `EMPLOYER_VERIFIED` | has been added by at least one company (membership) |
| `WORK_VERIFIED` | ≥ 1 supervisor-verified shift |
| `PERFORMANCE_VERIFIED` | ≥ 20 verified workdays, ≥ 5 approved tasks, punctuality ≥ 80 % |

Visibility: the worker; companies where the worker is/was a member; companies the worker applied to.

### 5.13 Vacancies & applications
Company/foreman creates a vacancy (title, description, category, region/city/address, rate, payment period,
workers needed, start date, duration, requirements, site, status). Workers browse open vacancies,
see company trust signals, apply once (withdraw / re-apply allowed). Company sees applicants **with their
verified identity**, shortlists / accepts / rejects. Accepting hires the worker (active membership).
Vacancy becomes `FILLED` when accepted count reaches `workersNeeded`. A company can block a worker
from **its own** vacancies (never platform-wide).

### 5.14 Company trust signals
Verification status (only `VERIFIED` after platform review — never self-assigned), workers managed,
verified shifts, completed vacancies, active projects. No badge is shown without a real criterion.

### 5.15 Notifications
In-app notification center (always) + FCM push (when Firebase credentials are configured).
Worker: shift reminder, task assigned, task reviewed, shift verified/rejected, application status.
Foreman: late/absent workers, pending checkouts, tasks awaiting approval, disputes.
Admin: new applications, disputes. Per-category preferences.

## 6. Error messages (Uzbek-first, specific)
Every API error returns a stable machine code (`OUTSIDE_GEOFENCE`, `NOT_ASSIGNED_TO_SITE`, …) that the
app maps to a specific Uzbek message, e.g. *"Siz obyekt hududidan tashqaridasiz."*,
*"Internet mavjud emas. Ma'lumot saqlandi va internet qaytganda yuboriladi."*

## 7. Audit log
`LOGIN, LOGOUT, COMPANY_CREATED, MEMBER_ADDED, WORKER_ADDED, WORKER_REMOVED, SITE_CREATED, PROJECT_CREATED,
SITE_ASSIGNED, WORK_STARTED, WORK_ENDED, SHIFT_VERIFIED, SHIFT_REJECTED, SHIFT_CORRECTED, TASK_CREATED,
TASK_APPROVED, TASK_REJECTED, VACANCY_CREATED, APPLICATION_STATUS_CHANGED, DISPUTE_OPENED, DISPUTE_RESOLVED, …`
with actor, action, entity, timestamp, metadata, IP.

## 8. Priorities
- **P0:** auth, company, roles, projects, sites, workers, check-in/out, work events, offline sync,
  supervisor verification, work history, vacancies, applications, security, audit, tests.
- **P1:** tasks, evidence, notifications, company verification, worker profile, disputes.
- **P2 (not built):** analytics, web admin, payments, AI, insurance, financial services.

## 9. Data we deliberately do NOT collect
No JSHSHIR/passport, no biometrics, no continuous GPS tracking (location only at the moment of an event),
no contacts. Company tax id (STIR) is optional and only for company verification.

## 10. Out of scope
AI, CV builder, computer vision, payments/payroll, insurance, credit scoring, blockchain,
microservices, Kubernetes, social feed, chat.
