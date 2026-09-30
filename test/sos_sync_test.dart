import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'package:rescuelink/services/sos_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MemoryCloud implements SosCloud {
  final records = <String, Map<String, dynamic>>{};
  final receipts = <String, Map<String, dynamic>>{};
  bool offline = false, loseReply = false;
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> push(Map<String, Object?> op) async {
    await gate?.future;
    if (offline) throw const SocketException('offline');
    final operation = op['operation_id'] as String;
    if (receipts.containsKey(operation)) return receipts[operation]!;
    final id = op['record_id'] as String;
    final old = records[id];
    if ((old?['version'] ?? 0) != op['base_version'] ||
        old?['deleted'] == true) {
      return {'outcome': 'conflict', 'record': old};
    }
    final record = <String, dynamic>{
      'id': id,
      'version': (op['base_version'] as int) + 1,
      'payload': jsonDecode(op['payload'] as String),
      'deleted': op['deleted'] == 1,
    };
    records[id] = record;
    final result = <String, dynamic>{'outcome': 'applied', 'record': record};
    receipts[operation] = result;
    if (loseReply) {
      loseReply = false;
      throw const SocketException('reply lost');
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> pull() async {
    if (offline) throw const SocketException('offline');
    return records.values.toList();
  }
}

SosAlert alert(
  int revision, {
  bool active = false,
  String details = 'help',
  String id = 'incident',
}) => SosAlert(
  incidentId: id,
  revision: revision,
  active: active,
  name: 'Tester',
  people: 1,
  category: EmergencyType.medical,
  details: details,
  updatedAt: DateTime.utc(2026, 9, 29),
);
Future<void> publish(LocalDatabaseService db, SosAlert value) =>
    db.saveSos(jsonEncode({'alert': value.toJson(), 'recipients': []}), []);

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late LocalDatabaseService db;
  late SosStore store;
  late MemoryCloud cloud;
  late SosSyncService sync;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rescuelink-sync-');
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${dir.path}/test.db',
    );
    store = SosStore(db);
    cloud = MemoryCloud();
    sync = SosSyncService(store, cloud);
  });
  tearDown(() async {
    sync.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  test('CRUD and durable queue survive closing and reopening SQLite', () async {
    await publish(db, alert(1));
    await store.editClosed(alert(2, details: 'edited'));
    await db.close();
    expect((await store.list()).single.alert.details, 'edited');
    expect((await store.queue()).length, 2);
    await store.editClosed(alert(3), delete: true);
    await db.close();
    expect(await store.list(), isEmpty);
    expect((await store.queue()).length, 3);
    await sync.sync();
    expect(await store.queue(), isEmpty);
    expect(cloud.records['incident']!['deleted'], true);
  });
  test(
    'active incidents cannot be edited or deleted through history',
    () async {
      await publish(db, alert(1, active: true));
      await expectLater(store.editClosed(alert(2)), throwsStateError);
      await expectLater(
        store.editClosed(alert(2), delete: true),
        throwsStateError,
      );
      expect((await store.queue()).length, 1);
    },
  );
  test('offline then online drains persistent queue', () async {
    await publish(db, alert(1));
    cloud.offline = true;
    await sync.sync();
    expect(sync.error, isNotNull);
    expect((await store.queue()).single['attempts'], 1);
    await db.close();
    cloud.offline = false;
    await sync.sync();
    expect(sync.error, isNull);
    expect(await store.queue(), isEmpty);
  });
  test(
    'server commit with lost reply replays same operation after restart',
    () async {
      await publish(db, alert(1));
      cloud.loseReply = true;
      await sync.sync();
      expect(cloud.records.length, 1);
      expect((await store.queue()).length, 1);
      sync.dispose();
      await db.close();
      sync = SosSyncService(store, cloud);
      await sync.sync();
      expect(cloud.records['incident']!['version'], 1);
      expect(cloud.receipts.length, 1);
      expect(await store.queue(), isEmpty);
    },
  );
  test('concurrent local edit during push is retained and sent next', () async {
    await publish(db, alert(1));
    cloud.gate = Completer<void>();
    final flight = sync.sync();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await store.editClosed(alert(2, details: 'newest'));
    cloud.gate!.complete();
    await flight;
    expect((await store.list()).single.alert.details, 'newest');
    await sync.sync();
    expect(await store.queue(), isEmpty);
    expect(cloud.records['incident']!['payload']['details'], 'newest');
  });
  test('conflict keeps local content and explicit rebase applies it', () async {
    await publish(db, alert(1));
    await sync.sync();
    cloud.records['incident'] = {
      ...cloud.records['incident']!,
      'version': 2,
      'payload': jsonDecode(alert(2, details: 'remote').toJson()),
    };
    await store.editClosed(alert(2, details: 'local'));
    await sync.sync();
    expect(sync.conflicts, 1);
    expect((await store.list()).single.alert.details, 'local');
    await store.resolve('incident', keepLocal: true);
    await sync.sync();
    expect(cloud.records['incident']!['version'], 3);
    expect(cloud.records['incident']!['payload']['details'], 'local');
  });
  test(
    'remote deletion wins only after explicit choice and cannot resurrect',
    () async {
      await publish(db, alert(1));
      await sync.sync();
      cloud.records['incident'] = {
        ...cloud.records['incident']!,
        'version': 2,
        'deleted': true,
      };
      await store.editClosed(alert(2));
      await sync.sync();
      await expectLater(
        store.resolve('incident', keepLocal: true),
        throwsStateError,
      );
      await store.resolve('incident', keepLocal: false);
      expect(await store.list(), isEmpty);
      expect(await store.queue(), isEmpty);
    },
  );
  test('guest retains local data without contacting cloud', () async {
    sync.dispose();
    sync = SosSyncService(store, null);
    await publish(db, alert(1));
    await sync.sync();
    expect(sync.pending, 1);
    expect(sync.lastSuccess, isNull);
  });
  test('unknown server response never removes an operation', () async {
    await publish(db, alert(1));
    await expectLater(
      store.acknowledge((await store.queue()).single, {
        'outcome': 'unexpected',
      }),
      throwsFormatException,
    );
    expect((await store.queue()).length, 1);
  });
  test(
    'v2 migration preserves latest SOS and creates a durable command',
    () async {
      await publish(db, alert(1));
      final raw = await db.database;
      await raw.execute('DROP TABLE sos_queue');
      await raw.execute('DROP TABLE sos_records');
      await raw.setVersion(2);
      await db.close();
      expect((await store.list()).single.alert.incidentId, 'incident');
      expect((await store.queue()).length, 1);
      expect(await (await db.database).getVersion(), 3);
    },
  );
  test('late response cannot restore a resolved conflict', () async {
    await publish(db, alert(1));
    final op = (await store.queue()).single;
    await sync.sync();
    await store.acknowledge(op, {'outcome': 'conflict', 'record': null});
    expect((await store.list()).single.conflict, isNull);
  });
  test(
    'cloud merge updates current SOS without broadcasting a different incident',
    () async {
      await publish(db, alert(1, active: true));
      await sync.sync();
      cloud.records['incident'] = {
        ...cloud.records['incident']!,
        'version': 2,
        'payload': jsonDecode(alert(2).toJson()),
      };
      await sync.sync();
      final current =
          jsonDecode((await db.getSetting('mySos'))!) as Map<String, dynamic>;
      expect(SosAlert.fromJson(current['alert'] as String).active, false);
      await expectLater(publish(db, alert(2, active: true)), throwsStateError);
      expect(await store.queue(), isEmpty);
    },
  );
}
