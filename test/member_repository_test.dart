import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/member_service.dart';

class TestVault implements SessionVault {
  String? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class TestAuth extends AuthService {
  TestAuth(AccountStorage storage, this.testClient)
    : super(storage: storage, vault: TestVault());
  final SupabaseClient testClient;
  @override
  Future<SupabaseClient> cloudClient(String owner) async {
    if (session?.userId != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
    return testClient;
  }
}

void main() {
  sqfliteFfiInit();
  test(
    'real SDK reads and updates owned profile, then calls guarded deletion and clears owner storage',
    () async {
      final directory = await Directory.systemTemp.createTemp('member-sdk-');
      final storage = AccountStorage(
        factory: databaseFactoryFfi,
        directory: directory.path,
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'local-public-key',
      );
      final auth = TestAuth(storage, client);
      final old = await storage.select('owner-A');
      auth.session = const AccountSession(
        'owner-A',
        'a@example.com',
        'local-session',
      );
      final repository = SupabaseMemberRepository(auth);
      var name = 'Original';
      final methods = <String>[];
      final subscription = server.listen((request) async {
        methods.add(request.method);
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/rest/v1/profiles') {
          expect(request.uri.queryParameters['id'], 'eq.owner-A');
          if (request.method == 'PATCH') {
            final body = jsonDecode(await utf8.decoder.bind(request).join());
            expect(body.keys.toList(), ['display_name']);
            name = body['display_name'];
          }
          request.response.write(
            jsonEncode({'id': 'owner-A', 'display_name': name}),
          );
        } else {
          expect(request.uri.path, '/functions/v1/delete-account');
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          expect(body, {'password': 'test-password', 'confirmation': 'DELETE'});
          request.response.write('{"deleted":true}');
        }
        await request.response.close();
      });
      try {
        expect((await repository.read()).name, 'Original');
        await expectLater(repository.updateName(' '), throwsStateError);
        expect((await repository.updateName(' Updated ')).name, 'Updated');
        expect((await repository.read()).name, 'Updated');
        await repository.deleteAccount('test-password');
        expect(auth.session, isNull);
        await expectLater(old.database, throwsStateError);
        expect(methods, ['GET', 'PATCH', 'GET', 'POST']);
      } finally {
        await subscription.cancel();
        await client.dispose();
        await server.close(force: true);
        auth.dispose();
        await storage.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
