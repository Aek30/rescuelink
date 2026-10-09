import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/emergency_profile_store.dart';
import 'package:rescuelink/services/emergency_profile_service.dart';
import 'account_auth_test.dart' show MemoryVault;
import 'signup_backend_test.dart' show MemoryPkceStorage;

const ownerA = '00000000-0000-4000-8000-000000000001';
const ownerB = '00000000-0000-4000-8000-000000000002';
final sampleProfile = <String, dynamic>{
  'display_name': 'Member',
  'full_name': 'Test Member',
  'phone': '0812345678',
  'date_of_birth': '2000-01-01',
  'terms_version': privacyVersion,
  'health_consent': true,
  'blood_group': 'O',
  'rh_factor': 'Positive (+)',
  'medical_conditions': 'Asthma',
  'allergies': 'Peanuts',
  'medications': 'Inhaler',
  'medical_notes': 'Self reported',
  'emergency_contact_name': 'Contact',
  'emergency_contact_phone': '0891234567',
  'emergency_contact_relation': 'Parent',
};

class MemoryProfileVault implements ProfileVault {
  final values = <String, String>{};
  @override
  Future<String?> read(String owner) async => values[owner];
  @override
  Future<void> write(String owner, String value) async => values[owner] = value;
  @override
  Future<void> remove(String owner) async => values.remove(owner);
}

String sessionFixture({bool expired = false, bool verified = true}) {
  final exp = expired
      ? 1
      : DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String part(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'exp': exp, 'sub': ownerA})}.test',
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': ownerA,
      'aud': 'authenticated',
      'email': 'member@example.com',
      'created_at': '2026-01-01T00:00:00Z',
      if (verified) 'email_confirmed_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
      'is_anonymous': false,
    },
  });
}

class ProfileTestAuth extends AuthService {
  ProfileTestAuth(this.testClient)
    : super(storage: AccountStorage(), vault: MemoryVault());
  final SupabaseClient? testClient;
  @override
  Future<SupabaseClient> cloudClient(String owner) async {
    if (session?.userId != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
    if (testClient == null) throw const SocketException('Offline');
    return testClient!;
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('no health consent strips every medical field; limits are enforced', () {
    final data = normalizeProfile({...sampleProfile, 'health_consent': false});
    expect(data.containsKey('allergies'), isFalse);
    expect(data.containsKey('blood_group'), isFalse);
    expect(data['full_name'], 'Test Member');
    expect(
      () => normalizeProfile({...sampleProfile, 'allergies': 'a' * 2001}),
      throwsStateError,
    );
    expect(
      () => normalizeProfile({...sampleProfile, 'blood_group': 'X'}),
      throwsStateError,
    );
  });

  test(
    'SDK signup keeps medical data out of Auth/JWT and duplicate signup cannot overwrite it',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final vault = MemoryProfileVault();
      final store = EmergencyProfileStore(vault);
      final backend = SupabaseAuthBackend(
        'http://127.0.0.1:${server.port}',
        'test-key',
        pkceStorage: MemoryPkceStorage(),
        profiles: store,
      );
      var duplicate = false;
      final sub = server.listen((request) async {
        expect(request.uri.path, '/auth/v1/signup');
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['data'].keys.toSet(), {
          'display_name',
          'full_name',
          'phone',
          'date_of_birth',
          'terms_version',
        });
        expect(body['data'].containsKey('medical_conditions'), isFalse);
        final user = jsonDecode(sessionFixture())['user'] as Map;
        user['identities'] = duplicate
            ? []
            : [
                {
                  'id': ownerA,
                  'user_id': ownerA,
                  'identity_id': ownerA,
                  'provider': 'email',
                  'created_at': '2026-01-01T00:00:00Z',
                },
              ];
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(user));
        await request.response.close();
      });
      try {
        expect(
          await backend.authenticate(
            'member@example.com',
            'Test@password1',
            register: true,
            displayName: 'Member',
            extraMetadata: sampleProfile,
          ),
          isNull,
        );
        expect((await store.record(ownerA))!['data']['allergies'], 'Peanuts');
        duplicate = true;
        await backend.authenticate(
          'member@example.com',
          'Test@password1',
          register: true,
          displayName: 'Member',
          extraMetadata: {...sampleProfile, 'allergies': 'Wrong'},
        );
        expect((await store.record(ownerA))!['data']['allergies'], 'Peanuts');
        expect(await store.record(ownerB), isNull);
      } finally {
        await sub.cancel();
        await backend.signOut();
        await server.close(force: true);
      }
    },
  );

  test(
    'late upload cannot mark a newer consent withdrawal as synced',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth.recoverSession(sessionFixture());
      final store = EmergencyProfileStore(MemoryProfileVault());
      await store.save(ownerA, sampleProfile);
      final entered = Completer<void>(), release = Completer<void>();
      final sub = server.listen((request) async {
        expect(request.uri.path, '/rest/v1/rpc/save_rescue_profile');
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['p_data']['allergies'], 'Peanuts');
        entered.complete();
        await release.future;
        request.response.headers.contentType = ContentType.json;
        request.response.write('null');
        await request.response.close();
      });
      try {
        final uploading = store.sync(client, ownerA, () => true);
        await entered.future;
        await store.save(ownerA, {...sampleProfile, 'health_consent': false});
        release.complete();
        await uploading;
        final record = (await store.record(ownerA))!;
        expect(record['pending'], isTrue);
        expect(record['data'].containsKey('allergies'), isFalse);
        await store.save(ownerB, sampleProfile);
        await expectLater(
          store.sync(client, ownerB, () => true),
          throwsStateError,
        );
      } finally {
        await sub.cancel();
        await client.dispose();
        await server.close(force: true);
      }
    },
  );

  test(
    'offline health deletion wipes A immediately and leaves B and account fields intact',
    () async {
      final store = EmergencyProfileStore(MemoryProfileVault());
      await store.save(ownerA, sampleProfile, pending: false);
      await store.save(ownerB, {
        ...sampleProfile,
        'allergies': 'B only',
      }, pending: false);
      final auth = ProfileTestAuth(null)
        ..session = AccountSession(ownerA, 'a@example.com', sessionFixture());
      final repo = SupabaseEmergencyProfileRepository(auth, store: store);
      final result = await repo.deleteHealth();
      expect(result.pending, isTrue);
      expect(result.data.containsKey('allergies'), isFalse);
      expect(result.data['health_consent'], isFalse);
      expect(result.data['full_name'], 'Test Member');
      expect((await store.record(ownerB))!['data']['allergies'], 'B only');
      auth.session = const AccountSession(ownerB, 'b@example.com', 'B');
      expect((await repo.read()).data['allergies'], 'B only');
      auth.dispose();
    },
  );

  test('offline edits flush to RPC after connectivity returns', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.recoverSession(sessionFixture());
    final store = EmergencyProfileStore(MemoryProfileVault());
    final auth = ProfileTestAuth(null)
      ..session = AccountSession(ownerA, 'a@example.com', sessionFixture());
    final repo = SupabaseEmergencyProfileRepository(auth, store: store);
    expect((await repo.save(sampleProfile)).pending, isTrue);
    final sub = server.listen((request) async {
      expect(request.uri.path, '/rest/v1/rpc/save_rescue_profile');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body['p_data'], normalizeProfile(sampleProfile));
      request.response.headers.contentType = ContentType.json;
      request.response.write('null');
      await request.response.close();
    });
    try {
      await store.sync(client, ownerA, () => auth.session?.userId == ownerA);
      expect((await store.record(ownerA))!['pending'], isFalse);
    } finally {
      auth.dispose();
      await sub.cancel();
      await client.dispose();
      await server.close(force: true);
    }
  });

  test(
    'SDK resend calls confirmation endpoint and propagates rate-limit errors',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final backend = SupabaseAuthBackend(
        'http://127.0.0.1:${server.port}',
        'test-key',
        pkceStorage: MemoryPkceStorage(),
      );
      var requests = 0;
      final sub = server.listen((request) async {
        requests++;
        expect(request.uri.path, '/auth/v1/resend');
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['type'], 'signup');
        expect(body['email'], 'member@example.com');
        request.response.headers.contentType = ContentType.json;
        if (requests > 1) {
          request.response.statusCode = 429;
          request.response.write(
            '{"error_code":"over_email_send_rate_limit","msg":"Rate limit"}',
          );
        } else {
          request.response.write('{}');
        }
        await request.response.close();
      });
      try {
        await backend.resendConfirmation('member@example.com');
        await expectLater(
          backend.resendConfirmation('member@example.com'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              'over_email_send_rate_limit',
            ),
          ),
        );
        expect(requests, 2);
      } finally {
        await sub.cancel();
        await backend.signOut();
        await server.close(force: true);
      }
    },
  );

  test(
    'expired verified session permits local offline use; rejected refresh does not',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final backend = SupabaseAuthBackend(
        'http://127.0.0.1:${server.port}',
        'test-key',
        pkceStorage: MemoryPkceStorage(),
      );
      var reject = false;
      final sub = server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = reject ? 400 : 503;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          reject
              ? '{"error_code":"refresh_token_not_found","msg":"Revoked"}'
              : '{"msg":"Unavailable"}',
        );
        await request.response.close();
      });
      try {
        final restored = await backend.restore(sessionFixture(expired: true));
        expect(restored.userId, ownerA);
        expect(
          Session.fromJson(jsonDecode(restored.serialized))!.isExpired,
          isTrue,
        );
        reject = true;
        final originalDatabase = LocalDatabaseService.instance;
        final vault = MemoryVault()..value = restored.serialized;
        final auth = AuthService(
          storage: AccountStorage(),
          vault: vault,
          backend: backend,
        )..session = restored;
        try {
          await expectLater(
            auth.cloudClient(ownerA),
            throwsA(isA<AuthException>()),
          );
          expect(auth.signedIn, isFalse);
          expect(vault.value, isNull);
          await expectLater(
            LocalDatabaseService.instance.database,
            throwsStateError,
          );
        } finally {
          auth.dispose();
          LocalDatabaseService.instance = originalDatabase;
        }
        await expectLater(
          backend.restore(sessionFixture(expired: true)),
          throwsA(isA<AuthException>()),
        );
        reject = false;
        await expectLater(
          backend.restore(sessionFixture(expired: true, verified: false)),
          throwsA(
            anyOf(isA<AuthRetryableFetchException>(), isA<TimeoutException>()),
          ),
        );
      } finally {
        await sub.cancel();
        await backend.signOut();
        await server.close(force: true);
      }
    },
  );
}
