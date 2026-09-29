# Security audit — Worker OS MVP

Scope: NestJS API, PostgreSQL schema, Nginx, Flutter app. Date: 2026-09-30.
Each item lists the control and the automated test that proves it (`backend/test/*.e2e-spec.ts`, `backend/src/**/*.spec.ts`, `mobile/test`).

## Authentication

| Risk | Control | Evidence |
|---|---|---|
| OTP brute force | 6 digits, 5 attempts per code counted **atomically** (`updateMany … attempts < max`), then the code is burned | auth: *wrong code → attempts left, then lockout* |
| OTP flooding / SMS cost abuse | 60 s resend cooldown, 5 codes/hour/phone, 20 req/min/IP on `/otp/request` (+ nginx 60 r/min/IP) | auth: cooldown, hourly limit, rate limit |
| OTP leakage | Stored as HMAC-SHA256(pepper, phone:code); never logged (dev provider logs a masked phone only); request bodies are not logged and `code`/`phone`/`refreshToken`/`authorization` are redacted | auth: *hashed at rest* |
| Replay of OTP | Single use (`consumedAt`), only the newest challenge is valid, 5 min expiry | auth: *cannot be reused*, *expired* |
| JWT forgery | HS256 only (`algorithms` pinned), issuer checked, ≥32-char secret enforced at boot; `alg:none` and foreign-key tokens rejected | auth: *tampered*, *alg none* |
| Stolen/expired tokens | 15-min access tokens bound to a **session row** checked on every request → logout, logout-all, session revoke and user deactivation are immediate | auth: *logout invalidates immediately*, *deactivated* |
| Refresh token theft | Opaque 384-bit tokens, SHA-256 at rest, rotated on every use; replay of a rotated token after 15 s grace **revokes the session** and is audited | auth: *refresh rotates … reuse revokes* |
| Dev OTP in production | Boot fails when `SMS_PROVIDER=dev` and `NODE_ENV=production` | `configuration.ts` |

## Authorization & tenant isolation

| Risk | Control | Evidence |
|---|---|---|
| Cross-tenant access | Every company route is `/companies/:companyId/...` behind `CompanyRolesGuard` (active membership required); non-members get **404** (no existence leak); all service queries filter by `companyId` | security: 12 GET paths + mutations from company B → 404 |
| IDOR (ids from another tenant) | Lookups are `findFirst({ id, companyId })`, never by id alone | security: *IDOR* block |
| Foreman privilege escalation | Role matrix per route; foreman limited to assigned sites (`AccessService`), can add only WORKERs to own sites | security: *foreman cannot use admin-only endpoints*, *own sites only* |
| Worker ↔ worker | `/me/*` always filters by the caller; sync events are always attributed to the caller (extra fields rejected) | security: *worker cannot read another worker's…*, *cannot forge work history* |
| Self-approval | Supervisors cannot verify/correct/review their own shifts or tasks | `CANNOT_REVIEW_OWN_WORK` |
| Mass assignment | Global `ValidationPipe` with `whitelist` + `forbidNonWhitelisted` | security: *unknown fields are rejected* |
| Last admin lock-out | Last admin cannot leave/be removed/demoted | security: *last admin* |
| Platform staff routes | `isPlatformAdmin` only, hidden with 404 | security: *hidden* |
| Unfair blacklisting | Blocks are company-local, require a reason, and only for people who interacted with the company | tasks-vacancies: *company blocks an applicant* |

## Data integrity

| Risk | Control |
|---|---|
| Silent history rewrite | `WorkEvent` and `AuditLog` are append-only (PostgreSQL triggers reject UPDATE/DELETE); corrections append `SHIFT_CORRECTED` with from/to/actor/reason; originals kept on the shift (`originalStartAt/EndAt`) |
| Duplicate events | Unique `(actorUserId, clientEventId)`; duplicates return the stored result; SERIALIZABLE transactions with retry; partial unique index "one OPEN shift per worker" |
| GPS fraud | Mock-location, low accuracy, geofence uncertainty, impossible travel, shared device, late sync flags — shown to supervisors, never auto-punishment |

## Injection, uploads, transport

| Risk | Control | Evidence |
|---|---|---|
| SQL injection | Prisma parameterised queries only (the single raw query is static) | security: *SQL-injection-looking search* |
| XSS via uploads | Content sniffed by magic bytes (JPEG/PNG/WEBP/PDF only), extension must match content, SVG/HTML/scripts/executables rejected; served with `nosniff`, `Content-Disposition: inline`, `CSP: sandbox` | unit: file-validation; security: PHP/SVG/HTML/EXE cases |
| Path traversal | Storage keys are `companies/{companyId}/tasks/{taskId}/{uuid}.{ext}`; user filenames only kept sanitised for display | security: *path traversal* |
| Oversized payloads | JSON 256 kB, uploads `UPLOAD_MAX_BYTES` (8 MB) in multer + nginx 10 MB, max 10 files/task, sync batch ≤ 50 | security: *oversized* |
| Private files | Bucket private; files streamed only after an access check (uploader or supervisor of that site) | security: *only the uploader and site supervisors can download* |
| Transport | Nginx TLS 1.2/1.3, HTTP→HTTPS redirect; Android release builds forbid cleartext (debug allows only emulator/localhost) | `nginx.conf`, `network_security_config.xml` |
| Headers / CORS | helmet (HSTS, frame DENY, nosniff, no-referrer, CSP); CORS allow-list, arbitrary origins not reflected; `x-powered-by` off | security: headers, CORS |
| DoS / rate limits | Per-user limits when authenticated (carrier-grade NAT safe), per-IP otherwise; nginx edge limits | auth: *limited per user, not per shared IP* |

## Secrets & privacy

- Secrets only via `.env` (git-ignored, `.env.example` committed); boot-time validation of lengths.
- Tokens on device in Android Keystore / iOS Keychain (`flutter_secure_storage`); `android:allowBackup="false"`.
- No JSHSHIR/passport/biometrics. Location is captured **only at the moment of an event** (no background tracking).
- Company STIR is optional and used only for company verification.
- Worker identity is visible only to the worker, companies where they are/were a member (foremen: their sites), and companies they applied to.
- Logs: request id/method/path/status only — no bodies, query strings, tokens or phone numbers.

## Residual risks / recommendations before a public launch

1. **Eskiz SMS integration is implemented but untested against the live API** (no credentials). Test with a real account and approved message template.
2. Add an account-deletion / data-export flow (legal requirement for personal data in many markets; Uzbek law on personal data applies).
3. Consider device attestation (Play Integrity) to strengthen mock-location detection beyond the OS flag.
4. Put the API behind a WAF / managed load balancer and enable automated PostgreSQL backups + object-storage versioning.
5. Run `npm audit` / `flutter pub outdated` in CI; current production dependency audit: **0 vulnerabilities** (two transitive packages pinned via `overrides`).
6. Evidence photos are not re-encoded (EXIF metadata is kept). Strip EXIF server-side if privacy of photo metadata matters.
