import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:uuid/uuid.dart';

// Explicit opt-in; does not create accounts or send email.
void main() {
  Map<String, dynamic> expiredCopy(String serialized) {
    final value = jsonDecode(serialized) as Map<String, dynamic>;
    final parts = (value['access_token'] as String).split('.');
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
    payload['exp'] = 1;
    // Force local expiry; this altered access token is never sent to the
    // server. setSession authenticates using the real refresh token.
    parts[1] = base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
    value['access_token'] = parts.join('.');
    expect(Session.fromJson(value)!.isExpired, isTrue);
    return value;
  }

  const live = bool.fromEnvironment('RUN_LIVE_AUTH');
  const member = bool.fromEnvironment('RUN_MEMBER_AUTH');
  test(
    'live Supabase rejects wrong credentials and anonymous profile access',
    () async {
      final config =
          jsonDecode(await File('config/supabase.local.json').readAsString())
              as Map<String, dynamic>;
      final backend = SupabaseAuthBackend(
        config['SUPABASE_URL'] as String,
        config['SUPABASE_PUBLISHABLE_KEY'] as String,
      );
      await expectLater(
        backend.authenticate(
          'phase2-nonexistent@example.invalid',
          'not-a-real-password',
          register: false,
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
      final client = SupabaseClient(
        config['SUPABASE_URL'] as String,
        config['SUPABASE_PUBLISHABLE_KEY'] as String,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        await expectLater(
          client.from('profiles').select(),
          throwsA(isA<PostgrestException>()),
        );
      } finally {
        await client.dispose();
        await backend.signOut();
      }
    },
    skip: !live,
  );
  test(
    'live member login, installation link, expired session refresh and logout',
    () async {
      final config =
          jsonDecode(await File('config/supabase.local.json').readAsString())
              as Map<String, dynamic>;
      final fixture =
          jsonDecode(
                await File('config/test-account.local.json').readAsString(),
              )
              as Map<String, dynamic>;
      final url = config['SUPABASE_URL'] as String;
      final key = config['SUPABASE_PUBLISHABLE_KEY'] as String;
      final backend = SupabaseAuthBackend(url, key);
      final session = await backend.authenticate(
        fixture['email'] as String,
        fixture['password'] as String,
        register: false,
      );
      expect(session, isNotNull);
      expect(session!.email, fixture['email']);
      final expired = expiredCopy(session.serialized);
      final refreshed = await backend.restore(jsonEncode(expired));
      expect(refreshed.userId, session.userId);
      expect(
        Session.fromJson(jsonDecode(refreshed.serialized))!.isExpired,
        isFalse,
      );
      final installation = const Uuid().v4(); // Random test-only UUID.
      final radio = const Uuid().v4();
      await backend.linkInstallation(refreshed, installation, radio);
      final client = SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        await client.auth.recoverSession(refreshed.serialized);
        final profiles = await client.from('profiles').select();
        expect(profiles.length, 1);
        expect(profiles.single['id'], session.userId);
        final links = await client
            .from('account_devices')
            .select()
            .eq('installation_id', installation);
        expect(links.single['radio_identity'], radio);
        // Remove only this test's metadata, preserving the member account.
        await client
            .from('account_devices')
            .delete()
            .eq('installation_id', installation);
        await backend.signOut();
        // A revoked refresh token must not restore an expired session.
        final revoked = expiredCopy(refreshed.serialized);
        await expectLater(
          backend.restore(jsonEncode(revoked)),
          throwsA(isA<AuthException>()),
        );
      } finally {
        await client.dispose();
        await backend.signOut();
      }
    },
    skip: !member,
  );
}
