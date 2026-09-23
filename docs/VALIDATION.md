# Validation — 2026-09-23

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

