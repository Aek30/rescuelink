import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/chat_store.dart';
import 'package:rescuelink/services/chat_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MemoryChatCloud implements ChatCloud {
  final records = <String, Map<String, dynamic>>{};
  final receipts = <String, Map<String, dynamic>>{};
  bool offline = false, loseReply = false;
  @override
  Future<Map<String, dynamic>> push(Map<String, Object?> op) async {
    if (offline) throw const SocketException('offline');
    final operation = op['operation_id'] as String;
    if (receipts.containsKey(operation)) return receipts[operation]!;
    final id = op['record_id'] as String;
    final old = records[id];
    if ((old?['version'] ?? 0) != op['base_version'] || old?['deleted'] == true) {
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

MessageModel message([String id = 'message']) => MessageModel(
  id: id,
  senderId: 'sender',
  senderName: 'Tester',
  receiverId: 'receiver',
  text: 'offline hello',
  timestamp: DateTime.utc(2026, 10, 8),
);
void main() {
  sqfliteFfiInit();
  late Directory dir;
  late LocalDatabaseService db;
  late ChatStore store;
  late MemoryChatCloud cloud;
  late ChatSyncService sync;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rescuelink-chat-sync-');
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${dir.path}/chat.db',
    );
    store = ChatStore(db);
    cloud = MemoryChatCloud();
    sync = ChatSyncService(store, cloud);
  });
  tearDown(() async {
    sync.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'offline messages and edits survive restart and sync once online',
    () async {
      await db.insertMessage(message());
      await store.edit('message', text: 'edited offline');
      cloud.offline = true;
      await sync.sync();
      expect(sync.pending, 2);
      await db.close();
      sync.dispose();
      db = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: '${dir.path}/chat.db',
      );
      store = ChatStore(db);
      sync = ChatSyncService(store, cloud);
      cloud.offline = false;
      await sync.sync();
      expect(sync.pending, 0);
      expect(cloud.records['message']!['payload']['text'], 'edited offline');
      expect((await db.getMessages()).single.text, 'offline hello');
    },
  );

  test(
    'lost upload response replays idempotently and preserves radio delivery',
    () async {
      await db.insertMessage(message());
      cloud.loseReply = true;
      await sync.sync();
      expect(sync.pending, 1);
      await sync.sync();
      expect(sync.pending, 0);
      expect(cloud.records['message']!['version'], 1);
      expect((await db.getMessages()).single.status, MessageStatus.pending);
    },
  );

  test(
    'delete syncs tombstone and duplicate incoming packet cannot resurrect',
    () async {
      await db.insertMessage(message());
      await sync.sync();
      await store.edit('message', delete: true);
      await sync.sync();
      expect(cloud.records['message']!['deleted'], true);
      await db.insertMessage(message());
      expect(await store.list(), isEmpty);
      expect(await store.queue(), isEmpty);
    },
  );

  test(
    'remote restore goes into history without replaying old packets',
    () async {
      cloud.records['remote'] = {
        'id': 'remote',
        'version': 1,
        'payload': message('remote').toMap(),
        'deleted': false,
      };
      await sync.sync();
      expect((await store.list()).single['id'], 'remote');
      expect(await db.getMessages(), isEmpty);
    },
  );

  test(
    'concurrent edit blocks that record and local resolution rebases',
    () async {
      await db.insertMessage(message());
      await sync.sync();
      cloud.records['message'] = {...cloud.records['message']!, 'version': 2};
      await store.edit('message', text: 'local edit');
      await db.insertMessage(message('unrelated'));
      await sync.sync();
      expect(sync.conflicts, 1);
      expect(cloud.records.containsKey('unrelated'), true);
      await store.resolve('message', keepLocal: true);
      await sync.sync();
      expect(sync.conflicts, 0);
      expect(sync.pending, 0);
      expect(cloud.records['message']!['version'], 3);
    },
  );

  test('cloud deletion wins over stale local edit', () async {
    await db.insertMessage(message());
    await sync.sync();
    cloud.records['message'] = {
      ...cloud.records['message']!,
      'version': 2,
      'deleted': true,
    };
    await store.edit('message', text: 'stale edit');
    await sync.sync();
    await expectLater(
      store.resolve('message', keepLocal: true),
      throwsStateError,
    );
    await store.resolve('message', keepLocal: false);
    expect(await store.list(), isEmpty);
    expect(await store.queue(), isEmpty);
  });

  test(
    'guest history stays local and account databases are isolated',
    () async {
      sync.dispose();
      sync = ChatSyncService(store, null);
      await db.insertMessage(message());
      await sync.sync();
      expect(sync.pending, 1);
      expect(cloud.records, isEmpty);
      final other = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: '${dir.path}/other.db',
      );
      expect(await ChatStore(other).list(), isEmpty);
      await other.close();
    },
  );
  test(
    'v8 upgrade queues existing text history without duplicating messages',
    () async {
      await db.insertMessage(message());
      final raw = await db.database;
      await raw.execute('DROP TABLE chat_queue');
      await raw.execute('DROP TABLE chat_records');
      await raw.setVersion(8);
      await db.close();
      expect((await store.list()).single['id'], 'message');
      expect(await store.queue(), hasLength(1));
      expect(await db.getMessages(), hasLength(1));
      await sync.sync();
      expect(sync.pending, 0);
      expect(cloud.records['message']!['payload']['text'], 'offline hello');
    },
  );
}
