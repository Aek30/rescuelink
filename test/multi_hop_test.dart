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

  Future<void> link(int a, int b, {bool clear = true}) async {
    for (final (from, to) in [(a, b), (b, a)]) {
      wires[to].devices.removeWhere((d) => d.endpointId == '$from');
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
    if (clear) {
      for (final wire in wires) {
        wire.sent.clear();
      }
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

  List<(String, String)> relays(int i) => wires[i].sent.where((item) {
    final data = jsonDecode(item.$2) as Map;
    return data.containsKey('relayPath') && data['type'] == 'message';
  }).toList();
  List<(String, String)> acks(int i) => wires[i].sent.where((item) {
    final data = jsonDecode(item.$2) as Map;
    return data.containsKey('relayPath') && data['type'] == 'ack';
  }).toList();

  Future<void> makeDue(int i) async {
    final db = await dbs[i].database;
    await db.update('relay_queue', {'next_attempt': null});
    await db.update('relay_ack_queue', {'next_attempt': null});
  }

  Future<void> restart(int i) async {
    nodes[i].dispose();
    await dbs[i].close();
    nodes[i] = MessageService(nearbyService: wires[i], database: dbs[i]);
    await nodes[i].initialize();
    wires[i].devices.clear();
  }

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
    'A to B to C and ACK preserve origin; duplicates and restart do not add chat rows',
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
      final route = [nodes[0].myId!, nodes[1].myId!, nodes[2].myId!];
      expect(nodes[2].receivedRoutes[nodes[2].messages.single.id], route);
      final messageId = nodes[2].messages.single.id;
      await dbs[2].close();
      expect((await dbs[2].getReceivedRoutes())[messageId], route);
      expect(nodes[0].messages.single.status, MessageStatus.sent);
      expect(nodes[2].peers[nodes[0].myId], isNotNull);
      expect(relays(2), isEmpty);
      expect(acks(2), hasLength(2));
      await receive(1, 2, acks(2).first.$2);
      expect(acks(1).single.$1, '0');
      await receive(0, 1, acks(1).single.$2);
      await receive(0, 1, acks(1).single.$2);
      expect(nodes[0].messages.single.status, MessageStatus.delivered);
      expect(nodes[0].receivedRoutes[messageId], route);
      expect(nodes[1].messages, isEmpty);
      expect(nodes[0].messages, hasLength(1));
      expect(acks(0), isEmpty);
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
        {'type': 'media'},
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
      await database.execute('DROP TABLE sos_records');
      await database.execute('DROP TABLE sos_queue');
      await database.execute('DROP TABLE media_files');
      await database.execute('DROP TABLE relay_queue');
      await database.execute('DROP TABLE relay_ack_queue');
      await database.execute('DROP TABLE chat_queue');
      await database.execute('DROP TABLE chat_records');
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
    'failed native send remains queued and retries without reconnect after backoff',
    () async {
      final raw = await send();
      wires[1].failedEndpoints.add('2');
      await receive(1, 0, raw);
      expect(nodes[1].error, contains('Relay failed'));
      wires[1].failedEndpoints.clear();
      await receive(1, 0, raw);
      await nodes[1].retry();
      expect(relays(1), isEmpty);
      await makeDue(1);
      await nodes[1].retry();
      expect(relays(1), hasLength(1));
      expect(
        await dbs[1].relayItem((jsonDecode(raw) as Map)['id'] as String),
        isNotNull,
      );
      await receive(2, 1, relays(1).single.$2);
      await receive(1, 2, acks(2).single.$2);
      await receive(0, 1, acks(1).single.$2);
      expect(nodes[0].messages.single.status, MessageStatus.delivered);
      expect(nodes[1].messages, isEmpty);
    },
  );

  test(
    'B queues with no C link and sends after restart and reconnect',
    () async {
      final raw = await send();
      final id = (jsonDecode(raw) as Map)['id'] as String;
      wires[1].devices.removeWhere((d) => d.endpointId == '2');
      await receive(1, 0, raw);
      expect(relays(1), isEmpty);
      expect(await dbs[1].relayItem(id), isNotNull);
      expect(await dbs[1].claimRelay(id), isFalse);
      await restart(1);
      await link(0, 1);
      await link(1, 2, clear: false);
      expect(relays(1), hasLength(1));
      await receive(2, 1, relays(1).single.$2);
      await receive(1, 2, acks(2).single.$2);
      await receive(0, 1, acks(1).single.$2);
      expect(nodes[0].messages.single.status, MessageStatus.delivered);
    },
  );

  test(
    'successful native send without reception stays pending and retries',
    () async {
      final raw = await send();
      await receive(1, 0, raw);
      expect(nodes[0].messages.single.status, MessageStatus.sent);
      await makeDue(1);
      await nodes[1].retry();
      expect(relays(1), hasLength(2));
      expect(
        (jsonDecode(relays(1).first.$2) as Map)['id'],
        (jsonDecode(relays(1).last.$2) as Map)['id'],
      );
      await receive(2, 1, relays(1).last.$2);
      expect(nodes[2].messages, hasLength(1));
    },
  );

  test('C queues ACK before send and recovers it after restart', () async {
    final raw = await send();
    await receive(1, 0, raw);
    wires[2].failedEndpoints.add('1');
    await receive(2, 1, relays(1).single.$2);
    final db = await dbs[2].database;
    expect(await db.query('relay_ack_queue'), hasLength(1));
    expect(nodes[0].messages.single.status, MessageStatus.sent);
    await restart(2);
    wires[2].failedEndpoints.clear();
    await link(1, 2, clear: false);
    expect(acks(2), hasLength(1));
    await receive(1, 2, acks(2).single.$2);
    await receive(0, 1, acks(1).single.$2);
    expect(nodes[0].messages.single.status, MessageStatus.delivered);
  });

  test(
    'B caches receipt and recovers pending return ACK after restart',
    () async {
      final raw = await send();
      await receive(1, 0, raw);
      await receive(2, 1, relays(1).single.$2);
      wires[1].failedEndpoints.add('0');
      await receive(1, 2, acks(2).single.$2);
      final db = await dbs[1].database;
      expect(await db.query('relay_ack_queue'), hasLength(1));
      expect(
        (await dbs[1].relayItem(nodes[0].messages.single.id))!['ack_payload'],
        isNotNull,
      );
      await restart(1);
      wires[1].failedEndpoints.clear();
      await link(0, 1, clear: false);
      expect(acks(1), hasLength(1));
      await receive(0, 1, acks(1).single.$2);
      expect(nodes[0].messages.single.status, MessageStatus.delivered);
      expect(nodes[1].messages, isEmpty);
    },
  );

  test(
    'lost return ACK is replayed from durable receipt on origin retry',
    () async {
      final raw = await send();
      await receive(1, 0, raw);
      await receive(2, 1, relays(1).single.$2);
      await receive(1, 2, acks(2).single.$2);
      // B's native ACK send succeeded, but A never received it.
      expect(nodes[0].messages.single.status, MessageStatus.sent);
      await restart(1);
      await link(0, 1);
      await nodes[0].retry();
      await receive(1, 0, relays(0).last.$2);
      expect(relays(1), isEmpty);
      expect(acks(1), hasLength(1));
      await receive(0, 1, acks(1).single.$2);
      expect(nodes[0].messages.single.status, MessageStatus.delivered);
    },
  );

  test(
    'unrelated ACK sender and invalid routes cannot mark delivered',
    () async {
      await send();
      final wrong = MessageModel(
        id: 'wrong-ack',
        senderId: nodes[1].myId!,
        senderName: 'B',
        receiverId: nodes[0].myId!,
        text: '',
        timestamp: DateTime.now().toUtc(),
        type: MessageType.ack,
        ackFor: nodes[0].messages.single.id,
      );
      await receive(
        0,
        1,
        RelayPacket(
          wrong,
          [nodes[1].myId!],
          ackRoute: [nodes[1].myId!, nodes[0].myId!],
        ).toJson(),
      );
      expect(nodes[0].messages.single.status, MessageStatus.sent);
      expect(acks(0), isEmpty);
      final raw = RelayPacket(
        wrong,
        [nodes[1].myId!],
        ackRoute: [nodes[1].myId!, nodes[0].myId!, nodes[1].myId!],
      ).toJson();
      await receive(0, 1, raw);
      expect(nodes[0].error, contains('Invalid relay ACK route'));
      expect(nodes[0].messages, hasLength(1));
    },
  );

  test(
    'claim and queue insertion roll back together on storage failure',
    () async {
      final raw = await send();
      final id = nodes[0].messages.single.id;
      final db = await dbs[1].database;
      await db.execute('''CREATE TRIGGER fail_relay BEFORE INSERT ON relay_queue
      BEGIN SELECT RAISE(ABORT, 'test queue storage failure'); END''');
      await receive(1, 0, raw);
      expect(
        await db.query('relay_seen', where: 'id = ?', whereArgs: [id]),
        isEmpty,
      );
      expect(await db.query('relay_queue'), isEmpty);
      await db.execute('DROP TRIGGER fail_relay');
      await receive(1, 0, raw);
      expect(relays(1), hasLength(1));
    },
  );

  test(
    'same ID with changed content is rejected without changing queued job',
    () async {
      final raw = await send();
      await receive(1, 0, raw);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data['text'] = 'changed';
      await receive(1, 0, jsonEncode(data));
      expect(nodes[1].error, contains('Conflicting relay packet ID'));
      expect(relays(1), hasLength(1));
      final job = await dbs[1].relayItem(data['id'] as String);
      expect(
        MessageModel.fromJson(job!['payload'] as String).text,
        'ช่วยด้วย 🌍',
      );
    },
  );

  test(
    'legacy seen-only entries can recover instead of losing a retried packet',
    () async {
      final raw = await send();
      await dbs[1].claimRelay(nodes[0].messages.single.id);
      await receive(1, 0, raw);
      expect(relays(1), hasLength(1));
      expect(await dbs[1].relayItem(nodes[0].messages.single.id), isNotNull);
    },
  );

  test(
    'retry continues beyond five attempts rather than abandoning work',
    () async {
      final raw = await send();
      await receive(1, 0, raw);
      final db = await dbs[1].database;
      await db.update('relay_queue', {'attempts': 6, 'next_attempt': null});
      await nodes[1].retry();
      expect(relays(1), hasLength(2));
      expect((await db.query('relay_queue')).single['attempts'], 7);
    },
  );

  test('ACK retry waits for backoff then sends without reconnect', () async {
    final raw = await send();
    await receive(1, 0, raw);
    await receive(2, 1, relays(1).single.$2);
    wires[1].failedEndpoints.add('0');
    await receive(1, 2, acks(2).single.$2);
    wires[1].failedEndpoints.clear();
    await nodes[1].retry();
    expect(acks(1), isEmpty);
    await makeDue(1);
    await nodes[1].retry();
    expect(acks(1), hasLength(1));
    await receive(0, 1, acks(1).single.$2);
    expect(nodes[0].messages.single.status, MessageStatus.delivered);
  });

  test('v7 migration preserves pending job, identity and history', () async {
    final raw = await send();
    wires[1].devices.removeWhere((d) => d.endpointId == '2');
    await receive(1, 0, raw);
    final before = (await dbs[1].relayItem(nodes[0].messages.single.id))!;
    final identity = nodes[1].myId;
    await dbs[1].insertMessage(
      MessageModel(
        id: 'history',
        senderId: identity!,
        senderName: 'B',
        receiverId: nodes[0].myId!,
        text: 'keep history',
        timestamp: DateTime.now().toUtc(),
      ),
    );
    nodes[1].dispose();
    final db = await dbs[1].database;
    await db.execute('ALTER TABLE relay_queue DROP COLUMN ack_payload');
    await db.execute('ALTER TABLE relay_ack_queue DROP COLUMN next_attempt');
    await db.execute('DROP TABLE chat_queue');
    await db.execute('DROP TABLE chat_records');
    await db.setVersion(7);
    await dbs[1].close();
    final after = (await dbs[1].relayItem(nodes[0].messages.single.id))!;
    expect(after['seq'], before['seq']);
    expect(after['payload'], before['payload']);
    expect(after['created_at'], before['created_at']);
    expect(after['ack_payload'], isNull);
    expect(await dbs[1].getDeviceId(), identity);
    expect((await dbs[1].getMessages()).single.text, 'keep history');
    expect(await (await dbs[1].database).getVersion(), 9);
    nodes[1] = MessageService(nearbyService: wires[1], database: dbs[1]);
    wires[1].devices.clear();
    await nodes[1].initialize();
  });

  test('v7 pending full-path ACK is upgraded without dropping it', () async {
    await send();
    final route = [nodes[2].myId!, nodes[1].myId!, nodes[0].myId!];
    final ack = MessageModel(
      id: 'legacy-ack',
      senderId: route.first,
      senderName: 'C',
      receiverId: route.last,
      text: '',
      timestamp: DateTime.now().toUtc(),
      type: MessageType.ack,
      ackFor: nodes[0].messages.single.id,
    );
    await dbs[2].enqueueRelayAck(
      ackFor: ack.ackFor!,
      payload: RelayPacket(ack, route).toJson(),
      destPeer: route[1],
    );
    nodes[2].dispose();
    final db = await dbs[2].database;
    await db.execute('ALTER TABLE relay_queue DROP COLUMN ack_payload');
    await db.execute('ALTER TABLE relay_ack_queue DROP COLUMN next_attempt');
    await db.execute('DROP TABLE chat_queue');
    await db.execute('DROP TABLE chat_records');
    await db.setVersion(7);
    await dbs[2].close();
    final rows = await dbs[2].pendingRelayAcks(route[1]);
    expect(rows, hasLength(1));
    final upgraded = RelayPacket.fromMap(
      jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>,
    );
    expect(upgraded.path, [route.first]);
    expect(upgraded.ackRoute, route);
    expect(upgraded.message.id, 'legacy-ack');
    nodes[2] = MessageService(nearbyService: wires[2], database: dbs[2]);
    wires[2].devices.clear();
    await nodes[2].initialize();
  });
}
