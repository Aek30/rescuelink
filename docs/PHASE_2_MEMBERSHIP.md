# Phase 2 — สมาชิกและโครงสร้างข้อมูล

This phase is separate from the historical Phase 2 offline messaging POC.

## Ownership and schema

| Data | Owner / relationship |
| --- | --- |
| Supabase `auth.users` | Authentication provider owns password hashes and sessions. The app never stores passwords. |
| `profiles` | One profile per `auth.users.id`; created by a trigger. |
| `account_devices` | Many-to-many account / app-install relationship, composite key `(user_id, installation_id)`. A link never gives access to another account. |
| `owned_records` | Future message/SOS sync envelope; composite owner/record key and composite FK to the owner's installation link. Not uploaded by this phase. |
| Local `accounts.db` | Random installation ID and owner → database filename catalog. No access/refresh tokens. |
| Local owner database | `settings`, `peers`, `messages`, `relay_seen`; includes private history, pending outbox, SOS, rescue mode, received routes, presence and preferences. Existing schema version 2 remains compatible. |
| Secure storage | Project-scoped serialized session with access/refresh tokens; never SQLite or application logs. Android backup is disabled. |

`installation_id` is stable for the app installation, not a hardware identifier. The existing wire `deviceId` becomes a radio identity for one local owner scope. Fresh Guest, A and B have distinct radio identities, so ACKs and replies cannot be routed to a different account's queue. Nearby identities remain unauthenticated peer identifiers, not verified Supabase identities.

## Guest adoption and switching

- Existing `rescuelink.db` is registered as Guest without copying, deleting or rewriting history.
- Login defaults to a separate account database. Guest adoption requires the checkbox on the login form and a successful session (email verification alone does not claim anything).
- Adoption atomically assigns the Guest database to that account and creates a fresh Guest mapping. History, SOS, outbox, peers and radio identity transfer together without rewriting packet IDs.
- Adoption is available only before that account has a local database. An existing account cannot overwrite/merge its data with Guest; login without adoption remains available. General history merge is future work.
- Logging out stops the Nearby session before returning to login, removes the persisted session, then selects Guest. The previous account's data remains private and is available when that account logs in again.
- Service instances capture immutable database handles. Late callbacks may finish against the original owner's handle but cannot write into the next owner's database.
- The owner catalog transaction is crash-safe. An interrupted activation can be recovered by logging into the account without claiming again.

## Supabase setup

1. Create the RescueLink project. Keep email confirmation enabled and configure a valid Site URL / SMTP service for verification email delivery.
2. Apply migrations in filename order. The membership migration creates tables, constraints, trigger, RLS policies and explicit grants. The hardening migration revokes public execution of the Dashboard-created `rls_auto_enable()` event trigger (applicable when automatic RLS was enabled during project creation). No anonymous cloud table access is granted.
3. Copy `config/supabase.example.json` to ignored `config/supabase.local.json` and fill Project URL + publishable key. Never use `service_role`, secret API key or database password in the app.
4. Build/run:

```powershell
.\tool\flutter.ps1 run --dart-define-from-file=config/supabase.local.json
.\tool\flutter.ps1 build apk --debug --dart-define-from-file=config/supabase.local.json
```

Without configuration, Guest SOS and offline chat remain available; login reports that accounts are not configured. Email/password is the supported login method. Google, phone login and password-reset UI are not exposed.

The configured project is **RescueLink**, ref `yrpqhupqbzymesknalnq`, region Singapore. Both migrations are already applied there, and local migration versions match the remote history. A successful login upserts the account/installation/radio link through RLS; failure to register metadata does not disable local functionality. No chat/SOS payload is uploaded.

This Windows machine resolves dependencies but `pub get` reports a desktop symlink-support warning. Android tests/builds work with the resolved packages and `--no-pub`; Windows desktop builds require the machine's Developer Mode/symlink support. The Flutter helper now uses the real path for ASCII workspaces, avoiding stale temporary-drive paths in Gradle caches.

## Sessions and errors

Remember me writes to platform secure storage; unchecked means session lasts only until process exit. Cold launch restores the session via Supabase SDK, refreshing an expired token when possible. Failed restore stays Guest and does not expose the old owner's data. A currently open local account can continue offline even if its cloud token expires; future cloud operations must refresh/revalidate before accessing server data. There is no cloud synchronization in this phase.

The startup screen offers immediate Guest access while network recovery is pending; a late recovery response cannot change the active owner. Catalog-read failure blocks data access instead of falling back to the legacy file, which may already belong to a member. Preferences reload per owner and discard late results from the previous scope.

Invalid credentials, unconfirmed email, duplicate account, password policy, rate limits, timeout and local storage failures have user-facing messages. Repeated taps do not start concurrent login operations. Logout fails closed if secure session deletion fails; the user can retry. Server revocation is best effort, so offline logout cannot revoke an already issued access token on the server until its expiry.

## Validation

Automated tests in `test/account_auth_test.dart` cover Guest adoption, fresh Guest after claim, account A/B isolation, retained late handles, duplicate claim rejection, verification-required signup, invalid credentials, secure-storage failure, duplicate submit, remember-off and successful/failed session restoration. The full Flutter suite also exercises Guest SOS, ACK/outbox retry, reconnect and multi-hop messaging.

Manual acceptance on real Android devices:

1. Guest with internet off: send SOS, reconnect to another phone, send chat, restart and check persistence.
2. Create two real test accounts through the app, confirm their emails, test wrong password and unconfirmed email.
3. A logs in with Guest adoption: inspect old history/SOS/outbox. Log out offline: fresh Guest must not show A's data.
4. B logs in: no A history, SOS, preferences or pending packets. Connect to the other phone and confirm no A packets are sent.
5. A logs back in: A history returns. With Remember me, restart restores A; without it, restart goes to Guest.
6. Revoke/expire the refresh session, restart offline and verify Guest is accessible and A stays hidden.
7. RLS: anonymous table requests must be denied; A's JWT must not select/insert/update/delete B's rows, including when supplying B's owner ID or installation ID.

Passing local tests is not proof of production email delivery, native secure storage or two-phone radio behavior. Record live Supabase and Android results separately.

### Verified on 2026-09-28

- `flutter analyze --no-pub`: no issues.
- Local Flutter regression suite: 81 passed; 2 live tests skipped by default.
- Live opt-in tests: wrong credentials rejected, anonymous profile access rejected, confirmed member login succeeds, installation metadata is owned correctly, refresh succeeds for a simulated expired access JWT using a real refresh token, and the refresh token is rejected after logout.
- Normal signup API sent the verification email; the user confirmed it. The profile trigger created the account profile successfully. No direct inserts into internal Auth tables were used to create a persistent test account.
- `supabase/tests/ownership.sql`: passed against the live database, with all fixtures rolled back. B cannot read/update/delete A's records or insert a link as A; anonymous reads are denied.
- Supabase security and performance advisors: zero findings after hardening.
- Two-phone Android acceptance for this membership build remains a manual check.

Live tests use only the publishable key and normal Auth/Data APIs:

```powershell
.\tool\flutter.ps1 test test/supabase_live_test.dart --no-pub --dart-define=RUN_LIVE_AUTH=true --dart-define=RUN_MEMBER_AUTH=true
```

The member test reads the ignored `config/test-account.local.json` (email/password); keep it private. It deletes only its own temporary installation metadata, logs out its session, and preserves the member account. The regular test suite does not use these credentials, connect to Supabase or send mail.

### Signup form update — 2026-10-03

- Fixed a real SDK initialization bug: `AuthClientOptions` defaults to PKCE, but standalone clients lacked `pkceAsyncStorage`. Email signup failed before its HTTP request. All backend clients now use an explicit PKCE flow with project-scoped secure verifier storage, separate from remembered sessions.
- Added a local HTTP-server regression test using the real Supabase SDK to verify signup sends the S256 challenge and display name and handles confirmation-pending responses. Auth/form/backend suite: 14 tests passed. No real signup email is sent by this suite.

- Registration requires a display name, email, password (8+ characters), and matching password confirmation. Login remains email/password only.
- Display name is stored in Auth user metadata on signup and copied to an empty owned profile on a subsequent successful installation link. It is never used for authorization.
- A response awaiting email confirmation is an informational message and returns the form to Login without adopting Guest data. Use a real inbox; a plausible email format does not prove mailbox ownership.
- Network, email delivery restrictions, rate limits and secure-storage failures have separate messages. Default Supabase mail delivery may require custom SMTP before accepting arbitrary new email addresses; see [SMTP setup](https://supabase.com/docs/guides/auth/auth-smtp).
- Verification: analyzer passed; 13 Auth/form tests passed. New-inbox email delivery and Android manual signup still require device testing.

References: [Supabase Flutter Auth](https://supabase.com/docs/reference/dart/auth-signup), [session recovery](https://supabase.com/docs/reference/dart/auth-recoversession), [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).
