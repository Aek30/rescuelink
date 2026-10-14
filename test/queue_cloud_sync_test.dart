import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/nearby_device.dart';
import 'package:rescuelink/services/chat_store.dart';
import 'package:rescuelink/services/chat_sync_service.dart';
import 'package:rescuelink/services/cloud_sync_receipts.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'package:rescuelink/services/sos_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'chat_sync_test.dart' show MemoryChatCloud, message;
import 'message_service_test.dart' show Transport;
import 'sos_sync_test.dart' show MemoryCloud, alert, publish;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late LocalDatabaseService db;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('queue-cloud-');
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${dir.path}/db',
    );
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<Set<String>> synced() async =>
      CloudSyncReceipts.messageIds(await db.database, await db.getMessages());

  test(
    'only acknowledged chat uploads count, persist, and preserve delivery',
    () async {
      await db.insertMessage(message());
      final cloud = MemoryChatCloud()..offline = true;
      final sync = ChatSyncService(ChatStore(db), cloud);
      addTearDown(sync.dispose);
      await sync.sync();
      expect(await synced(), isEmpty);
      cloud.offline = false;
      cloud.loseReply = true;
      await sync.sync();
      expect(await synced(), isEmpty);
      await sync.sync();
      expect(await synced(), {'message'});
      expect((await db.getMessages()).single.status, MessageStatus.pending);
      await db.updateMessageStatus('message', MessageStatus.delivered);
      expect(await synced(), {'message'});
      await db.close();
      expect(await synced(), {'message'});
    },
  );

  test('conflicts and invalid results never create receipts', () async {
    await db.insertMessage(message());
    final store = ChatStore(db);
    final op = (await store.queue()).single;
    await expectLater(
      store.acknowledge(op, {'outcome': 'unknown'}),
      throwsFormatException,
    );
    expect(await synced(), isEmpty);
    await store.acknowledge(op, {'outcome': 'conflict', 'record': null});
    expect(await synced(), isEmpty);
  });

  test(
    'restored cloud history matches exact content, not just message ID',
    () async {
      await db.insertMessage(message());
      final store = ChatStore(db);
      final op = (await store.queue()).single;
      await (await db.database).delete('chat_queue');
      await store.mergeRemote([
        {
          'id': 'message',
          'version': 1,
          'deleted': false,
          'payload': {...message().toMap(), 'text': 'different archive'},
        },
      ]);
      expect(await synced(), isEmpty);
      await store.mergeRemote([
        {
          'id': 'message',
          'version': 1,
          'deleted': false,
          'payload': message().toMap(),
        },
      ]);
      expect(await synced(), {'message'});
      // A response to an operation already removed cannot create new evidence.
      await db.insertMessage(message('late'));
      await store.acknowledge(
        {...op, 'payload': message('late').toJson()},
        {'outcome': 'applied'},
      );
      expect(await synced(), {'message'});
    },
  );

  test(
    'SOS receipt covers matching revision and all recipients only',
    () async {
      final original = alert(1);
      final newer = alert(2);
      MessageModel sos(String id, String receiver, String payload) =>
          MessageModel(
            id: id,
            senderId: 'sender',
            senderName: 'Tester',
            receiverId: receiver,
            text: payload,
            timestamp: DateTime.utc(2026, 10, 8),
            type: MessageType.sos,
          );
      await publish(db, original);
      await db.insertMessage(sos('a', 'one', original.toJson()));
      await db.insertMessage(sos('b', 'two', original.toJson()));
      await db.insertMessage(sos('new', 'one', newer.toJson()));
      final cloud = MemoryCloud()..offline = true;
      final sync = SosSyncService(SosStore(db), cloud);
      addTearDown(sync.dispose);
      await sync.sync();
      expect(await synced(), isEmpty);
      cloud.offline = false;
      await sync.sync();
      expect(await synced(), {'a', 'b'});
      await publish(db, newer);
      await sync.sync();
      expect(await synced(), {'a', 'b', 'new'});
    },
  );

  test(
    'live MessageService receives cloud changes without radio retry',
    () async {
      final wire = Transport();
      final service = MessageService(nearbyService: wire, database: db);
      var serviceDisposed = false;
      addTearDown(() {
        if (!serviceDisposed) service.dispose();
        wire.dispose();
      });
      await service.initialize();
      await db.insertMessage(
        MessageModel(
          id: 'message',
          senderId: service.myId!,
          senderName: 'Tester',
          receiverId: 'receiver',
          text: 'offline hello',
          timestamp: DateTime.utc(2026, 10, 8),
        ),
      );
      await service.retry();
      expect(service.cloudSyncedMessageIds, isEmpty);
      final changed = Completer<void>();
      service.addListener(() {
        if (service.cloudSyncedMessageIds.contains('message') &&
            !changed.isCompleted) {
          changed.complete();
        }
      });
      final sync = ChatSyncService(ChatStore(db), MemoryChatCloud());
      addTearDown(sync.dispose);
      await sync.sync();
      await changed.future.timeout(const Duration(seconds: 3));
      expect(service.messages.single.status, MessageStatus.pending);
      wire.devices.add(
        NearbyDevice(endpointId: 'endpoint', name: 'Receiver')
          ..isConnected = true,
      );
      await service.handleIncomingPayload(
        endpointId: 'endpoint',
        rawPayload: MessageModel(
          id: 'intro',
          senderId: 'receiver',
          senderName: 'Receiver',
          receiverId: '',
          text: '',
          timestamp: DateTime.now(),
          type: MessageType.deviceInfo,
        ).toJson(),
      );
      final sends = wire.packets.where((m) => m.id == 'message').length;
      expect(sends, greaterThan(0));
      await service.retry();
      expect(
        wire.packets.where((m) => m.id == 'message').length,
        greaterThan(sends),
      );
      expect(service.messages.single.status, MessageStatus.sent);
      expect(service.cloudSyncedMessageIds, {'message'});
      service.dispose();
      serviceDisposed = true;
    },
  );
}
