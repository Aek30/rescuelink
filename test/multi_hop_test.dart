import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/nearby_device.dart';
import 'package:rescuelink/models/relay_packet.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'message_service_test.dart' show Transport;

class Wire extends Transport {
  final sent = <(String, String)>[];
  @override
  Future<void> sendMessage(String endpointId, String payload) async {
    if (failedEndpoints.contains(endpointId)) throw StateError('Link down');
    sent.add((endpointId, payload));
  }
}

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late List<LocalDatabaseService> dbs;
  late List<Wire> wires;
  late List<MessageService> nodes;

  Future<void> link(int a, int b) async {
    for (final (from, to) in [(a, b), (b, a)]) {
      wires[to].devices.add(
        NearbyDevice(endpointId: '$from', name: '$from')..isConnected = true,
      );
      await nodes[to].handleIncomingPayload(
        endpointId: '$from',
        rawPayload: MessageModel(
          id: 'intro-$from',
          senderId: nodes[from].myId!,
          senderName: 'Phone $from',
          receiverId: '',
          text: '',
          timestamp: DateTime.utc(2026),
          type: MessageType.deviceInfo,
        ).toJson(),
      );
    }
    for (final wire in wires) {
      wire.sent.clear();
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('relay-test-');
    dbs = List.generate(
      3,
      (i) => LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: '${dir.path}/$i.db',
      ),
    );
    wires = List.generate(3, (_) => Wire());
    nodes = List.generate(
      3,
      (i) => MessageService(nearbyService: wires[i], database: dbs[i]),
    );
    for (final node in nodes) {
      await node.initialize();
    }
    // A knows C from previous pairing; remote directory discovery is not added.
    await dbs[0].savePeer(nodes[2].myId!, 'Phone C');
    await link(0, 1);
    await link(1, 2);
  });
  tearDown(() async {
    for (final node in nodes) {
      node.dispose();
    }
    for (final wire in wires) {
      wire.dispose();
    }
    for (final db in dbs) {
      await db.close();
    }
    await dir.delete(recursive: true);
  });

  List<(String, String)> relays(int i) => wires[i].sent
      .where((item) => (jsonDecode(item.$2) as Map).containsKey('relayPath'))
      .toList();
  Future<void> receive(int to, int from, String raw) =>
      nodes[to].handleIncomingPayload(endpointId: '$from', rawPayload: raw);
  Future<String> send() async {
    await nodes[0].sendTextMessage(
      receiverId: nodes[2].myId!,
      text: 'ช่วยด้วย 🌍',
    );
    return relays(0).single.$2;
  }

  test(
    'A to B to C preserves origin; duplicates, retries and restart do not reflood',
    () async {
      final raw = await send();
      await Future.wait([receive(1, 0, raw), receive(1, 0, raw)]);
      expect(relays(1), hasLength(1));
      expect(relays(1).single.$1, '2');
      expect(nodes[1].messages, isEmpty);
      final forwarded = relays(1).single.$2;
      await receive(2, 1, forwarded);
      await receive(2, 1, forwarded);
      expect(nodes[2].messages, hasLength(1));
      expect(nodes[2].messages.single.senderId, nodes[0].myId);
      expect(nodes[2].messages.single.text, 'ช่วยด้วย 🌍');
      expect(nodes[2].messages.single.status, MessageStatus.delivered);
      expect(nodes[0].messages.single.status, MessageStatus.sent);
      expect(nodes[2].peers[nodes[0].myId], isNotNull);
      expect(relays(2), isEmpty);
      await nodes[0].retry();
      expect(relays(0), hasLength(1));
      nodes[1].dispose();
      await dbs[1].close();
      nodes[1] = MessageService(nearbyService: wires[1], database: dbs[1]);
      await nodes[1].initialize();
      wires[1].devices.clear();
      wires[0].devices.clear();
      await link(0, 1);
      await receive(1, 0, raw);
      expect(relays(1), isEmpty);
    },
  );

  test(
    'looped path, wrong last hop, unsupported type and excessive hops are rejected',
    () async {
      final raw = await send();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final patch in <Map<String, dynamic>>[
        {
          'relayPath': [nodes[0].myId, nodes[1].myId, nodes[0].myId],
        },
        {
          'relayPath': [nodes[0].myId, 'wrong'],
        },
        {'type': 'sos'},
        {'relayVersion': 2},
        {
          'relayPath': [nodes[0].myId, ...List.generate(8, (i) => 'hop-$i')],
        },
      ]) {
        await receive(1, 0, jsonEncode({...data, ...patch}));
      }
      expect(relays(1), isEmpty);
      await receive(1, 0, raw);
      expect(relays(1), hasLength(1));
      await receive(0, 1, relays(1).single.$2);
      expect(relays(0), hasLength(1));
    },
  );

  test(
    'version 1 storage upgrades without losing identity or history',
    () async {
      final id = nodes[1].myId;
      final message = MessageModel(
        id: 'old',
        senderId: id!,
        senderName: 'B',
        receiverId: nodes[2].myId!,
        text: 'history',
        timestamp: DateTime.utc(2026),
        status: MessageStatus.delivered,
      );
      await dbs[1].insertMessage(message);
      nodes[1].dispose();
      final database = await dbs[1].database;
      await database.execute('DROP TABLE relay_seen');
      await database.setVersion(1);
      await dbs[1].close();
      nodes[1] = MessageService(nearbyService: wires[1], database: dbs[1]);
      await nodes[1].initialize();
      expect(nodes[1].myId, id);
      expect(nodes[1].messages.single.text, 'history');
      expect(await dbs[1].claimRelay('new'), isTrue);
      expect(await dbs[1].claimRelay('new'), isFalse);
    },
  );

  test('hop limit allows final delivery but no further forwarding', () async {
    final message = MessageModel(
      id: 'limit',
      senderId: 'origin',
      senderName: 'Origin',
      receiverId: nodes[2].myId!,
      text: 'limit',
      timestamp: DateTime.utc(2026),
    );
    final raw = RelayPacket(message, [
      'origin',
      ...List.generate(6, (i) => 'hop-$i'),
      nodes[0].myId!,
    ]).toJson();
    await receive(1, 0, raw);
    expect(relays(1), isEmpty);
    final atDestination = RelayPacket(message, [
      'origin',
      ...List.generate(6, (i) => 'hop-$i'),
      nodes[1].myId!,
    ]).toJson();
    await receive(2, 1, atDestination);
    expect(nodes[2].messages.single.id, 'limit');
  });

  test(
    'no relay queue: failed forward is not retried or acknowledged',
    () async {
      final raw = await send();
      wires[1].failedEndpoints.add('2');
      await receive(1, 0, raw);
      expect(nodes[1].error, contains('Relay failed'));
      wires[1].failedEndpoints.clear();
      await receive(1, 0, raw);
      await nodes[1].retry();
      expect(relays(1), isEmpty);
      expect(nodes[1].messages, isEmpty);
    },
  );
}
