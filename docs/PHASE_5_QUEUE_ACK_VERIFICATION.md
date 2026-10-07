# Phase 5 — Text relay queue and ACK verification

Verified on 2026-10-04. Baseline Git HEAD: `9667403`; the working tree already
contained the initial Phase 5 queue/ACK edits. This change completes only the
compile fix and text relay queue/ACK work, not the rest of Phase 5.

## Behavior

- B atomically records the seen marker and a durable job even without a C link.
- Native send success does not remove the data job or mark A delivered.
- The regular five-second retry loop drains jobs when their backoff expires.
  Backoff is capped at 300 seconds; work is not silently abandoned after five
  attempts. Reconnection and service restart permit immediate retry.
- C queues ACKs before sending. ACKs carry both the traversed path and a fixed
  return route; intermediate nodes check the next hop, prior endpoint identity,
  original job and return path. ACKs are never inserted into chat or ACKed again.
- B caches the destination receipt and queues its return hop atomically. If the
  return ACK is lost after native success, origin retransmission can replay the
  persisted receipt, including after B restarts.
- Repeated packets use the same data ID. Conflicting data is rejected; repeated
  ACKs do not add chat rows or downgrade a delivered/synced message.
- Queue jobs and cached receipts expire after 48 hours of local queue age.
  Cleanup runs at initialization and at most once every six hours thereafter.
- SQLite v8 adds fields to the v7 queues without clearing or rebuilding pending
  data. Legacy pending ACKs are converted to the new path/route representation.

## Automated verification

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: 127 passed, 4 opt-in live tests skipped.
- `git diff --check`: passed.
- `flutter build apk --debug --no-pub`: passed; output is
  `build/app/outputs/flutter-apk/app-debug.apk`. The existing Java native-access,
  location plugin KGP and SDK XML compatibility warnings were non-fatal.

Regression coverage includes no-next-hop buffering, data and ACK backoff,
restart at B/C, lost native delivery, lost return ACK, concurrent duplicates,
wrong ACK sender, loop/route rejection, hop limit, queue transaction rollback,
conflicting data IDs, legacy seen-only recovery, migration from v1/v2, and v7
pending queue/ACK preservation. Existing direct message, SOS, account, media and
widget tests also passed in the full suite.

## Physical verification still required

These are simulated transports with real temporary SQLite databases, not phone
radio evidence. Install the same new APK on A/B/C, confirm no A–C direct endpoint,
then test messages both ways, lost links, restarting B with pending data/ACK,
duplicate delivery and loop topology in a separate run. Capture endpoint logs,
message IDs, destination persistence and origin delivered status.

Remote peer discovery, SOS/Rescue relay and media relay remain separate work.
Phase 5 is not complete on the basis of these automated results.
