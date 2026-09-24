import 'dart:io';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/nearby_device.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';

class NativeStub extends Fake implements Nearby {}

class Transport extends NearbyService {
  Transport() : super(nearby: NativeStub());
  final devices = <NearbyDevice>[];
  final packets = <MessageModel>[];
  bool fail = false;
  final failedEndpoints = <String>{};
  Future<void> Function(MessageModel)? onSend;
  @override
  List<NearbyDevice> get connectedDevices => devices;
  @override
  Future<void> sendMessage(String endpointId, String payload) async {
    if (fail || failedEndpoints.contains(endpointId)) {
      throw StateError('Disconnected');
    }
    final packet = MessageModel.fromJson(payload);
    packets.add(packet);
    await onSend?.call(packet);
  }

  @override
  Future<void> stopAll() async {}
  void changed() => notifyListeners();
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late LocalDatabaseService db;
  late Transport transport;
  late MessageService service;
  MessageModel packet(
    MessageType type, {
    String? ackFor,
    String id = 'incoming',
    String sender = 'peer',
  }) => MessageModel(
    id: id,
    senderId: sender,
    senderName: 'Phone B',
    receiverId: service.myId!,
    text: 'สวัสดี 🌍',
    timestamp: DateTime.utc(2026),
    type: type,
    ackFor: ackFor,
  );
  Future<void> receive(MessageModel message) => service.handleIncomingPayload(
    endpointId: 'endpoint',
    rawPayload: message.toJson(),
  );
  Future<void> connect() async {
    transport.devices.add(
      NearbyDevice(endpointId: 'endpoint', name: 'Phone B')..isConnected = true,
    );
    await receive(packet(MessageType.deviceInfo));
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rescuelink-test-');
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${directory.path}/test.db',
    );
    transport = Transport();
    service = MessageService(nearbyService: transport, database: db);
    await service.initialize();
  });
  tearDown(() async {
    service.dispose();
    transport.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });
  test('transport log notifications do not trigger a resend loop', () async {
    await connect();
    transport.changed();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    transport.packets.clear();
    transport.changed();
    transport.changed();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.packets, isEmpty);
  });
  test(
    'identity, history and queued messages survive reopening SQLite',
    () async {
      await connect();
      transport.devices.clear();
      await service.sendTextMessage(receiverId: 'peer', text: 'offline');
      final myId = service.myId;
      expect(service.messages.single.status, MessageStatus.pending);
      service.dispose();
      await db.close();
      db = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: '${directory.path}/test.db',
      );
      service = MessageService(nearbyService: transport, database: db);
      await service.initialize();
      expect(service.myId, myId);
      expect(service.peers['peer'], 'Phone B');
      expect(service.messages.single.text, 'offline');
      await connect();
      expect(service.messages.single.status, MessageStatus.sent);
    },
  );
  test(
    'failed send stays pending; lost ACK retries same ID; ACK completes delivery',
    () async {
      await connect();
      transport.fail = true;
      await service.sendTextMessage(receiverId: 'peer', text: 'hello');
      expect(service.messages.single.status, MessageStatus.pending);
      transport.fail = false;
      await service.retry();
      final id = service.messages.single.id;
      expect(service.messages.single.status, MessageStatus.sent);
      await service.retry();
      expect(
        transport.packets
            .where((p) => p.type == MessageType.message)
            .map((p) => p.id),
        [id, id],
      );
      await receive(packet(MessageType.ack, ackFor: id));
      expect(service.messages.single.status, MessageStatus.delivered);
      transport.packets.clear();
      await service.retry();
      expect(
        transport.packets.where((p) => p.type == MessageType.message),
        isEmpty,
      );
    },
  );
  test('duplicates are stored once and acknowledged again', () async {
    await connect();
    await receive(packet(MessageType.message));
    await receive(packet(MessageType.message));
    expect(service.messages, hasLength(1));
    expect(service.messages.single.text, 'สวัสดี 🌍');
    expect(
      transport.packets.where((p) => p.type == MessageType.ack),
      hasLength(2),
    );
  });
  test(
    'same ID with different content is not acknowledged or overwritten',
    () async {
      await connect();
      final original = packet(MessageType.message);
      await receive(original);
      transport.packets.clear();
      final conflicting = MessageModel.fromMap({
        ...original.toMap(),
        'text': 'different text',
      });
      await receive(conflicting);
      expect(
        transport.packets.where((p) => p.type == MessageType.ack),
        isEmpty,
      );
      expect((await db.getMessages()).single.text, original.text);
      expect(service.error, contains('Conflicting message ID'));
    },
  );
  test('a failing endpoint cannot starve another peer outbox', () async {
    await connect();
    transport.devices.add(
      NearbyDevice(endpointId: 'second', name: 'Phone C')..isConnected = true,
    );
    await service.handleIncomingPayload(
      endpointId: 'second',
      rawPayload: packet(MessageType.deviceInfo, sender: 'peer-c').toJson(),
    );
    transport.failedEndpoints.add('endpoint');
    await service.sendTextMessage(receiverId: 'peer-c', text: 'to C');
    expect(service.messages.single.status, MessageStatus.sent);
    expect(
      transport.packets
          .where((p) => p.type == MessageType.message)
          .single
          .receiverId,
      'peer-c',
    );
  });
  test(
    'reconnect with a new endpoint routes old pending messages to the same peer',
    () async {
      await connect();
      transport.devices.clear();
      transport.changed();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.sendTextMessage(receiverId: 'peer', text: 'queued');
      expect(service.isOnline('peer'), isFalse);
      transport.devices.add(
        NearbyDevice(endpointId: 'replacement', name: 'New name')
          ..isConnected = true,
      );
      await service.handleIncomingPayload(
        endpointId: 'replacement',
        rawPayload: packet(MessageType.deviceInfo).toJson(),
      );
      expect(service.isOnline('peer'), isTrue);
      expect(service.messages.single.status, MessageStatus.sent);
      expect(service.peers, hasLength(1));
    },
  );
  test('fast ACK cannot regress from delivered to sent', () async {
    await connect();
    transport.onSend = (p) async {
      if (p.type == MessageType.message) {
        await receive(packet(MessageType.ack, ackFor: p.id));
      }
    };
    await service.sendTextMessage(receiverId: 'peer', text: 'fast ACK');
    expect(service.messages.single.status, MessageStatus.delivered);
  });
  test(
    'malformed packets and mismatched ACK sender cannot change delivery',
    () async {
      await connect();
      await service.sendTextMessage(receiverId: 'peer', text: 'hello');
      await service.handleIncomingPayload(
        endpointId: 'endpoint',
        rawPayload: 'not JSON',
      );
      expect(service.error, contains('Receive failed'));
      await receive(
        packet(
          MessageType.ack,
          sender: 'other',
          ackFor: service.messages.single.id,
        ),
      );
      expect(service.messages.single.status, MessageStatus.sent);
      expect(
        () => MessageModel.fromJson('{"type":"unknown"}'),
        throwsA(anything),
      );
    },
  );
  test('empty and oversized encoded messages never enter the outbox', () async {
    await connect();
    await expectLater(
      service.sendTextMessage(receiverId: 'peer', text: '  '),
      throwsArgumentError,
    );
    await expectLater(
      service.sendTextMessage(receiverId: 'peer', text: 'ก' * 11000),
      throwsArgumentError,
    );
    expect(await db.getMessages(), isEmpty);
  });
}
