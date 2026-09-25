# Validation

## Phase 5 part 1 — 2026-09-25

- Full Flutter suite: PASS, 57 tests, including 5 new multi-hop tests using three services with separate SQLite databases.
- Flutter analyze: PASS, no issues. `git diff --check`: PASS.
- Verified simulated A → B → C text delivery, unchanged origin/content, concurrent duplicate suppression, relay restart deduplication, path/loop validation, hop ceiling, failed-link behavior, and version 1 → 2 database migration preserving identity/history.
- No new APK build or physical three-phone test performed in this step. Existing APK is from the previous phase.
- Only text relay is implemented. Relay queues, end-to-end relay ACK and SOS/Rescue forwarding remain part 2; physical acceptance remains part 3. See [scope and limitations](PHASE_5_PART_1.md).
- Initial sandbox SDK invocation stalled without output and was canceled. Completed test/analyze results above came from authorized SDK runs outside the sandbox.

## P30 follow-up and notification preference — 2026-09-25

- Final debug APK build: PASS (101.7 seconds), including the optional fused-location code; output `build/app/outputs/flutter-apk/app-debug.apk`.
- Full Flutter suite: PASS, 52 tests. Added coverage for simultaneous local start deduplication, stale advertiser cleanup, and timeout diagnostic text. Analyze: PASS, no issues. `git diff --check`: PASS.
- Removed bottom SOS SnackBar; Android notification and visible status/count remain.
- Optional Google fused-location request now runs alongside Android GPS/network with a shared 60-second deadline and cancellation. Declared play-services-location 21.3.0 explicitly (already present in the local dependency cache). Native Android providers remain usable without the optional Google route.
- P30 native positioning and the exact reported two-device Advertising PlatformException remain pending physical verification. The full exception code has not been supplied. The user's successful online map positioning does not prove offline GNSS reception.
- User reports the other tested Phase 4 flows work normally. Do not mark the two unresolved physical checks passed from the automated tests.

## Huawei GPS timeout fix — 2026-09-25

- Analyze: PASS, no issues. Full Flutter suite: PASS, 49 tests (8 new location-channel tests covering fresh fix metadata, permission denial, four native error codes, watchdog cancellation/retry, stale coordinate rejection).
- Debug APK build: PASS including native LocationCapture; `git diff --check`: PASS.
- Replaced SOS coordinate capture with Android LocationManager providers, 60-second native timeout, listener cleanup, foreground lifecycle cancellation, and Thai errors. Nearby still uses its existing transport dependencies.
- Native GPS reception on Huawei and S25: NOT RUN. The user's earlier S25 success and Huawei timeout describe the previous APK, not acceptance of this fix. Follow the GPS section of PHASE_4_TEST.md.

## Phase 4 physical-feedback fixes — 2026-09-25

- `tool/flutter.ps1 build apk --debug`: PASS, updated `build/app/outputs/flutter-apk/app-debug.apk` includes ConnectionService and notification/map channels.
- `tool/flutter.ps1 analyze`: PASS, no issues.
- `tool/flutter.ps1 test`: PASS, 41 tests. New tests verify that an active background session retains a connected peer and can send while paused, STOP releases that session, automatic mode requests discovered peers and keeps discovery running, and broadcast SOS updates the visible count/alerts only on new revisions rather than heartbeats.
- `git diff --check`: PASS.
- Native foreground service, screen-off/Doze/OEM behavior, notification delivery and automatic two-phone connection still require physical validation. The background-session test injects a fake service; it does not prove Android background delivery.
- User reported the map app opens but shows no map or pin. Coordinate handoff tests pass, but this does not verify the map app has offline data. Added copy coordinates; diagnosis on the physical map app remains open.
- See revised checklist at the top of PHASE_4_TEST.md. Original Phase 4 limitations/results below describe the earlier build.

## Phase 4 — 2026-09-25

| Check | Actual result |
| --- | --- |
| `tool/flutter.ps1 analyze` | PASS — No issues found on final source including the additional widget tests |
| `tool/flutter.ps1 test` | PASS — 36 tests, including broadcast without recipients, late peer, cancellation, persistence, sequence ordering, sender binding and expiry |
| `tool/flutter.ps1 test test/phase_4_widgets_test.dart` | PASS — 2 tests: red/blue/expired status and chat; map coordinates and missing-app handling |
| `tool/flutter.ps1 build apk --debug` | PASS — Android native map handler compiles; `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | PASS |
| Physical Phase 4 two-phone acceptance | NOT RUN — follow [Phase 4 test guide](PHASE_4_TEST.md) |

38 automated tests passed across two commands. Tests use fake Nearby and a mocked map channel; they do not prove physical radio delivery, native map-app behavior, or offline map availability. APK build completed with existing Java native-access, location plugin Kotlin and SDK XML warnings. No new package dependency was added. Phase 4 does not implement relay, media, cloud, background operation or automatic discovery/connection.

An initial sandbox validation attempt produced no result; an elevated attempt was temporarily blocked by the approval service usage limit. A subsequent authorized run completed normally; only completed checks are reported above.

## Phase 3 — 2026-09-24

| Check | Actual result |
| --- | --- |
| `tool/flutter.ps1 analyze` | PASS — No issues found |
| Message and Nearby tests | PASS — 32 tests, including 7 new SOS service tests |
| `tool/flutter.ps1 test test/sos_screen_test.dart` | PASS — 2 UI tests: recipient/confirmation gate and Rescue → sender chat |
| `tool/flutter.ps1 build apk --debug` | PASS — `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | PASS |
| Physical GPS and offline A ↔ B acceptance | PASS — user reported all five guided test sections passed on 2026-09-25; see [Phase 3 test record](PHASE_3_TEST.md) |

Debug compilation reports existing plugin/Kotlin and Android SDK/Java deprecation warnings, but completes successfully. No dependency versions changed. A temporary-drive native-hook cache issue during concurrent Flutter commands was resolved by clearing only the generated project hook cache and running validation sequentially. Future Flutter commands should use one temporary alias at a time.

The 34 passing tests comprise a 32-test service run and a separate 2-test UI run. They do not establish physical radio delivery or GPS performance. The APK was built from the final application code; subsequent edits affected only tests and documentation.

## Historical Phase 1 — 2026-09-23

Project: RescueLink Phase 1, Flutter stable 3.44.6 / Dart 3.12.2, Windows.

| Check | Actual result |
| --- | --- |
| Project inspection | Initial directory empty; created one Android-only rescuelink project |
| flutter doctor -v | Android SDK not found; Flutter/Dart not on PATH |
| flutter devices | Windows, Chrome, Edge only; zero physical Android devices |
| flutter pub get | PASS |
| flutter analyze (original Thai path) | SDK LSP FormatException; analyzer process exited 255 |
| flutter analyze (drive root alias) | SDK session logger FormatException |
| tool/flutter.ps1 analyze (ASCII parent alias, same source files) | PASS — No issues found! (9.5s) |
| tool/flutter.ps1 test | PASS — 13 tests; All tests passed! |
| flutter build apk --debug | BLOCKED — No Android SDK found |
| APK installation | NOT RUN — no APK/physical Android device |
| Offline A ↔ B physical phone acceptance | NOT RUN — must be recorded in PHYSICAL_TEST.md |

The 13 automated tests exercise permission selection, denied permission gating,
false native start results, endpoint deduplication/loss, outgoing/incoming
connections, UTF-8 English/Thai bytes, rejection/request failure, invalid sends,
invalid UTF-8/transfer failure, cleanup/late callbacks, cancellation during
permission prompt, foreground gating and connection timeout.

These tests use a fake Nearby transport. They do not validate Bluetooth, Wi-Fi,
Google Play services, OEM permission behavior, Gradle native compilation or
actual radio communication. No emulator/web/desktop run was used as a substitute
for physical Android testing.

No dependency downgrade, Flutter SDK edits or permanent drive mapping was made.
The helper removes its temporary alias after each run. Android SDK setup and
physical test instructions are in README.md. Phase 2 remains unimplemented.

## Later update — emulator build fix

Android SDK and NDK are now installed. Debug APK build, install and launch on emulator-5554 passed with Flutter 3.47.5. flutter analyze and all 13 tests passed. See EMULATOR_RUN_FIX.md for the compileSdk and Kotlin cache fixes. Physical two-phone offline acceptance remains NOT RUN.

