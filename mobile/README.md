# Worker OS — mobile app (Flutter)

One app, role-based UI:

- **Worker** — Bugun (Today: site, status, big ISHNI BOSHLASH / ISHNI YAKUNLASH), Ishlar (job board),
  Mening ishim (verified history, disputes, tasks with photo evidence), Profil (verified identity vs self-reported).
- **Company admin / foreman** — Bugun (10-second dashboard), Ishchilar, Tasdiqlash (verification queue),
  Ko'proq (sites & projects, tasks, vacancies & applicants, disputes, company profile).

Users with several memberships switch role/company from Profile → *Rolni almashtirish*.

## Run

```bash
flutter pub get
```

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

## Structure

```
lib/core/       api client (refresh single-flight, error → Uzbek message), auth session, Drift DB (outbox + cache),
                sync service (backoff, crash recovery), location + geofence, theme, shared widgets, strings (uz)
lib/data/       typed repository for every endpoint
lib/models/     defensive JSON models
lib/features/   auth · onboarding · worker · company · common
test/           outbox/sync, Today state, parity rules, error mapping, widgets
web/            QA-only web target (drift wasm assets); production targets are Android and iOS
```

## Offline-first attendance

Every tap is written to the local `pending_events` table **before** any network call, then sent to
`POST /work-events/sync` in chronological batches. Server idempotency on `clientEventId` makes resends safe
(app killed mid-sync → rows reset from SYNCING to PENDING on start). Retries: exponential 5 s → 5 min,
immediately on reconnect / app resume / "Hozir yuborish".

## Checks

```bash
flutter analyze && flutter test
```

Regenerate Drift code after changing tables:

```bash
dart run build_runner build --delete-conflicting-outputs
```
