# Week 3 member CRUD - 2026-10-08

## Implemented

- Chrome login / session restoration opens `MemberScreen`, avoiding Android-only Nearby initialization in the account demonstration.
- `SupabaseMemberRepository.read()` reads the current user's `profiles` row using the real Supabase SDK. Email comes from the authenticated session.
- Profile update validates a trimmed 1-100 character display name, updates only the current owner's row, and displays the server-returned result.
- Existing profile RLS limits access to `auth.uid() = id` with both USING and WITH CHECK. No schema or policy relaxation was needed.
- `delete-account` Edge Function deployed to RescueLink, version 1, with `verify_jwt=true`.
- Deletion validates the JWT through Auth, reauthenticates the current password, compares verified identities, rejects a caller-supplied `user_id`, removes only the owner's flat `chat-media` objects, revokes sessions globally, then calls Admin deleteUser. Admin keys remain in the Edge environment.
- Existing ON DELETE CASCADE relationships remove the profile and dependent cloud rows. The client signs out and removes the owner's SQLite database / catalog entry; a retained retired database handle cannot recreate deleted storage.
- Android Settings offers the same member screen and stops Nearby before exiting the account. Native downloaded media files are not removed from disk by the database cleanup.

## Validation

- `flutter analyze --no-pub`: no issues.
- `flutter build web --no-pub`: succeeded. Nonfatal existing icon/font tree-shaking warning.
- Full `flutter test --no-pub`: 144 passed, 4 opt-in live tests skipped.
- Node Edge-function tests: 8 passed, including wrong password, invalid JWT, mismatched identity, supplied target account, revocation failure, CORS and successful owned-file cleanup / deletion sequence.
- SDK integration test uses the real Dart Supabase client against a local HTTP fixture, checking GET/PATCH owner filters and function body, plus local account cleanup.
- Live deployed endpoint: unauthenticated POST returned 401; OPTIONS returned 204 with CORS.
- Supabase security advisor returned no findings.
- Built web opened in Codex's in-app browser. SQLite startup, onboarding, Login and empty-field validation worked. Chrome was not available to the browser control tool.
- PDF rendered to six page images; all pages visually reviewed and text extraction checked.

## Remaining manual acceptance

Create a disposable account with a mailbox the user controls, verify email, login in Chrome, read/update the profile, delete that account through the app and confirm removal in Auth / profiles / account_devices. These live successful Auth and Delete paths were not exercised: no confirmed disposable account was available. Local fixtures and unauthenticated endpoint checks are not a replacement for that acceptance.

If live deletion fails after session revocation, the user may need to log in again to retry. Storage cleanup and Auth deletion are separate remote operations, not one atomic transaction.

Text-chat cloud sync is not implemented; SOS sync is unchanged. The report and script explicitly distinguish this scope.
