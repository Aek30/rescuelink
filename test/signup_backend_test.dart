import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuelink/services/auth_service.dart';

class MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async => values.remove(key);
}

void main() {
  test(
    'duplicate obfuscated signup does not claim an email was sent',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final backend = SupabaseAuthBackend(
        'http://127.0.0.1:${server.port}',
        'local-key',
        pkceStorage: MemoryPkceStorage(),
      );
      addTearDown(() async {
        await backend.client.dispose();
        await server.close(force: true);
      });
      final handled = server.first.then((request) async {
        expect(request.uri.path, '/auth/v1/signup');
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': '00000000-0000-4000-8000-000000000001',
            'aud': 'authenticated',
            'email': 'member@example.com',
            'created_at': '2026-10-03T00:00:00Z',
            'identities': [],
            'app_metadata': {},
            'user_metadata': {},
          }),
        );
        await request.response.close();
      });
      await expectLater(
        backend.authenticate(
          'member@example.com',
          'Test@password1',
          register: true,
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'user_already_exists',
          ),
        ),
      );
      await handled;
    },
  );
  test(
    'real SDK signup sends PKCE challenge and name before awaiting confirmation',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final storage = MemoryPkceStorage();
      final backend = SupabaseAuthBackend(
        'http://127.0.0.1:${server.port}',
        'local-test-key',
        pkceStorage: storage,
      );
      addTearDown(() async {
        await backend.client.dispose();
        await server.close(force: true);
      });
      final requestHandled = server.first.then((request) async {
        expect(request.uri.path, '/auth/v1/signup');
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        expect(storage.values, isNotEmpty);
        expect(body['code_challenge_method'], 's256');
        expect(body['code_challenge'], isNotEmpty);
        expect(storage.values.values, isNot(contains(body['code_challenge'])));
        expect(body['data'], {'display_name': 'Test Member'});
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': '00000000-0000-4000-8000-000000000001',
            'aud': 'authenticated',
            'email': 'member@example.com',
            'created_at': '2026-10-03T00:00:00Z',
            'app_metadata': {},
            'user_metadata': body['data'],
          }),
        );
        await request.response.close();
      });
      final session = await backend
          .authenticate(
            'member@example.com',
            'test-only-password',
            register: true,
            displayName: ' Test Member ',
          )
          .timeout(const Duration(seconds: 5));
      await requestHandled;
      expect(session, isNull);
    },
  );
}
