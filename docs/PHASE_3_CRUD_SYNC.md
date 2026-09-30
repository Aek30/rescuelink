# Phase 3 — SOS CRUD and Cloud Sync

Verified on 2026-09-30 against the RescueLink Supabase project.

## Delivered

- `รายการเหตุ SOS ของฉัน` stores all incidents in SQLite. Closed incidents can be read, edited and deleted; active incidents cannot be edited or deleted from history.
- SQLite schema version 3 migrates the latest legacy SOS into `sos_records` and creates a durable `sos_queue`. Incident changes and queue commands are committed in the same transaction.
- Signed-in accounts sync through `public.sync_sos`. Each command has a persistent UUID receipt, so retrying after a lost response is idempotent.
- Cloud writes use compare-and-swap versions. Conflicts stop only the affected incident and the Account / Sync screen lets the user compare and select local or Cloud data.
- Deletions remain as Cloud tombstones. Deleted incidents cannot be resurrected by an offline device.
- Guest data remains local. Account databases, queues and sessions stay isolated by owner.
- SOS, nearby chat/outbox and account controls remain available from the existing application navigation.

## Evidence

- Flutter analyzer: `No issues found`.
- Full local suite: 94 passed, 3 opt-in tests skipped. Includes SQLite close/reopen, offline/online retry, process-death simulation, lost response replay, concurrent edit, conflict resolution, deletion tombstones, account isolation, SOS, chat and relay regressions.
- Live Supabase sync: authenticated local create, RPC upload, idempotent replay after SQLite reopen, pull, conflict/rebase and delete all passed using synthetic records; the test removes records through a tombstone.
- Transactional SQL ownership test: account B cannot read, update or delete account A's SOS; anonymous RPC access is denied; fixtures roll back.
- Supabase migrations `20260929060828_sos_cloud_sync_verified` and `20260930082212_sos_payload_validation` are applied.
- Android debug APK built at `build/app/outputs/flutter-apk/app-debug.apk`.
- UI captures: `docs/ui-audit/phase3-history.png` and `docs/ui-audit/phase3-sync.png`.

## Demo path

1. Sign in, open **ศูนย์ช่วยเหลือ**, create an SOS, then end it.
2. Tap the history icon to open **รายการเหตุ SOS ของฉัน**; edit or delete the closed incident.
3. Open **บัญชี / Sync** from history or settings to inspect pending commands, retry sync, and resolve conflicts.
4. Open Chat and send while the peer is offline; the existing durable message outbox retries when the peer reconnects.

Native two-phone radio behavior and real airplane-mode interaction still require physical devices. The automated suite covers the equivalent persistence and retry state transitions; it cannot operate two unavailable phones.
