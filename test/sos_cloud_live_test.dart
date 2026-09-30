import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'package:rescuelink/services/sos_sync_service.dart';

class TestVault implements SessionVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  sqfliteFfiInit();
  test(
    'live authenticated SQLite -> RPC -> pull -> conflict -> delete',
    () async {
      final config =
          jsonDecode(await File('config/supabase.local.json').readAsString())
              as Map<String, dynamic>;
      final fixture =
          jsonDecode(
                await File('config/test-account.local.json').readAsString(),
              )
              as Map<String, dynamic>;
      final dir = await Directory.systemTemp.createTemp('rescuelink-live-');
      final storage = AccountStorage(
        factory: databaseFactoryFfi,
        directory: dir.path,
      );
      final auth = AuthService(
        storage: storage,
        vault: TestVault(),
        backend: SupabaseAuthBackend(
          config['SUPABASE_URL'],
          config['SUPABASE_PUBLISHABLE_KEY'],
        ),
      );
      SosSyncService? sync;
      try {
        await auth.initialize();
        expect(
          await auth.authenticate(
            fixture['email'],
            fixture['password'],
            register: false,
            remember: false,
            claimGuest: false,
          ),
          isTrue,
        );
        final db = LocalDatabaseService.instance;
        final store = SosStore(db);
        final cloud = SupabaseSosCloud(auth, auth.session!.userId);
        sync = SosSyncService(store, cloud);
        final id = const Uuid().v4();
        SosAlert record(
          int revision, {
          String details = 'Synthetic Phase 3 validation',
          bool active = false,
        }) => SosAlert(
          incidentId: id,
          revision: revision,
          active: active,
          name: 'Phase 3 automated test',
          people: 1,
          category: EmergencyType.other,
          details: details,
          updatedAt: DateTime.now().toUtc(),
        );
        await db.saveSos(
          jsonEncode({
            'alert': record(1, active: true).toJson(),
            'recipients': [],
          }),
          [],
        );
        final first = (await store.queue()).single;
        final reply = await cloud.push(first);
        expect(reply['outcome'], 'applied');
        // Leave the command queued to simulate process death after server commit.
        await db.close();
        await sync.sync();
        expect(sync.error, isNull);
        expect(await store.queue(), isEmpty);
        expect(
          (await cloud.pull()).singleWhere((r) => r['id'] == id)['version'],
          1,
        );
        await db.saveSos(
          jsonEncode({'alert': record(2).toJson(), 'recipients': []}),
          [],
        );
        await sync.sync();
        expect(sync.error, isNull);
        await store.editClosed(record(3, details: 'Local edit'));
        final remote = record(3, details: 'Other device edit');
        final external = await cloud.push({
          'operation_id': const Uuid().v4(),
          'record_id': id,
          'base_version': 2,
          'payload': remote.toJson(),
          'deleted': 0,
        });
        expect(external['outcome'], 'applied');
        await sync.sync();
        expect(sync.conflicts, 1);
        await store.resolve(id, keepLocal: true);
        await sync.sync();
        expect(sync.error, isNull);
        expect(await store.queue(), isEmpty);
        final current = (await store.list()).singleWhere(
          (r) => r.alert.incidentId == id,
        );
        await store.editClosed(
          record(current.alert.revision + 1),
          delete: true,
        );
        await sync.sync();
        expect(sync.error, isNull);
        expect(
          (await cloud.pull()).singleWhere((r) => r['id'] == id)['deleted'],
          true,
        );
        expect(
          (await store.list()).where((r) => r.alert.incidentId == id),
          isEmpty,
        );
      } finally {
        sync?.dispose();
        await auth.signOut();
        await storage.close();
        auth.dispose();
        await dir.delete(recursive: true);
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_SYNC'),
  );
}
