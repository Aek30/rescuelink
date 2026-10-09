import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'signup_backend_test.dart' show MemoryPkceStorage;

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_AUTH');
  test(
    'live verified member can read own personal and medical rows; anonymous access is denied',
    () async {
      final config = jsonDecode(
        await File('config/supabase.local.json').readAsString(),
      );
      final fixture = jsonDecode(
        await File('config/test-account.local.json').readAsString(),
      );
      final backend = SupabaseAuthBackend(
        config['SUPABASE_URL'],
        config['SUPABASE_PUBLISHABLE_KEY'],
        pkceStorage: MemoryPkceStorage(),
      );
      final anon = SupabaseClient(
        config['SUPABASE_URL'],
        config['SUPABASE_PUBLISHABLE_KEY'],
      );
      try {
        final session = await backend.authenticate(
          fixture['email'],
          fixture['password'],
          register: false,
        );
        expect(session, isNotNull);
        expect(backend.client.auth.currentUser!.emailConfirmedAt, isNotNull);
        final profiles = await backend.client
            .from('profiles')
            .select('id, full_name, phone, date_of_birth, terms_version');
        expect(profiles.length, 1);
        expect(profiles.single['id'], session!.userId);
        final health = await backend.client
            .from('emergency_medical_profiles')
            .select('id');
        expect(health.every((row) => row['id'] == session.userId), isTrue);
        await expectLater(
          anon.from('emergency_medical_profiles').select('id'),
          throwsA(isA<PostgrestException>()),
        );
      } finally {
        await anon.dispose();
        await backend.signOut();
      }
    },
    skip: !live,
  );
}
