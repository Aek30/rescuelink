import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/nearby_device.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/relay_packet.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'message_service_test.dart' show Transport;

class NetworkWire extends Transport {
  final outgoing = <(String, String)>[];
  final log = <(String, String)>[];
  @override
  Future<void> sendMessage(String endpointId, String payload) async {
    if (failedEndpoints.contains(endpointId)) throw StateError('Link down');
    outgoing.add((endpointId, payload));
    log.add((endpointId, payload));
  }
}

void main() {
  sqfliteFfiInit();
  late Directory temp;
  late List<LocalDatabaseService> databases;
  late List<NetworkWire> wires;
  late List<MessageService> nodes;
  late DateTime now;

  Future<void> receive(int to, int from, String raw) =>
      nodes[to].handleIncomingPayload(endpointId: '$from', rawPayload: raw);

  Future<void> connect(int a, int b) async {
    for (final (from, to) in [(a, b), (b, a)]) {
      wires[to].devices.removeWhere((d) => d.endpointId == '$from');
      wires[to].devices.add(
        NearbyDevice(endpointId: '$from', name: '$from')..isConnected = true,
      );
      await receive(
        to,
        from,
        MessageModel(
          id: 'intro-$from',
          senderId: nodes[from].myId!,
          senderName: wires[from].deviceName,
          receiverId: '',
          text: '',
          timestamp: now,
          type: MessageType.deviceInfo,
        ).toJson(),
      );
    }
  }

  Future<void> pump() async {
    var processed = 0;
    while (wires.any((w) => w.outgoing.isNotEmpty)) {
      for (var from = 0; from < wires.length; from++) {
        if (wires[from].outgoing.isEmpty) continue;
        final item = wires[from].outgoing.removeAt(0);
        final to = int.parse(item.$1);
        if (wires[from].devices.any((d) => d.endpointId == '$to') &&
            wires[to].devices.any((d) => d.endpointId == '$from')) {
          await receive(to, from, item.$2);
        }
        expect(
          ++processed,
          lessThan(1000),
          reason: 'network must settle without looping',
        );
      }
    }
  }

  Future<void> exchange() async {
    for (var round = 0; round < 2; round++) {
      for (final node in nodes) {
        await node.retry();
      }
      await pump();
    }
  }

  Future<void> restart(int i) async {
    nodes[i].dispose();
    await databases[i].close();
    wires[i].devices.clear();
    wires[i].outgoing.clear();
    nodes[i] = MessageService(
      nearbyService: wires[i],
      database: databases[i],
      clock: () => now,
    );
    await nodes[i].initialize();
  }

  Future<void> publish(
    int i, {
    Set<String> recipients = const {},
    String details = 'help',
  }) => nodes[i].publishSos(
    name: wires[i].deviceName,
    people: 2,
    category: EmergencyType.medical,
    details: details,
    recipients: recipients,
  );

  String directoryPacket(
    int from,
    int to,
    List<Map<String, dynamic>> entries, {
    int sequence = 10000,
  }) {
    final body =
        jsonDecode(
              PeerPresence(
                sequence: sequence,
                rescue: false,
                receivedAt: now,
              ).encode(),
            )
            as Map<String, dynamic>;
    return MessageModel(
      id: 'directory-$sequence',
      senderId: nodes[from].myId!,
      senderName: wires[from].deviceName,
      receiverId: nodes[to].myId!,
      type: MessageType.presence,
      timestamp: now,
      text: jsonEncode({...body, 'directoryVersion': 1, 'directory': entries}),
    ).toJson();
  }

  Map<String, dynamic> advertisement(
    String id,
    String via, {
    int age = 0,
    SosAlert? sos,
  }) => {
    'peerId': id,
    'name': id,
    'sequence': 1,
    'rescue': true,
    'sos': sos?.toJson(),
    'ageMs': age,
    'path': [id, via],
  };

  setUp(() async {
    now = DateTime.now().toUtc();
    temp = await Directory.systemTemp.createTemp('network-presence-');
    databases = List.generate(
      3,
      (i) => LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: '${temp.path}/$i.db',
      ),
    );
    wires = List.generate(
      3,
      (i) => NetworkWire()..deviceName = ['A', 'B', 'C'][i],
    );
    nodes = List.generate(
      3,
      (i) => MessageService(
        nearbyService: wires[i],
        database: databases[i],
        clock: () => now,
      ),
    );
    for (final node in nodes) {
      await node.initialize();
    }
    await connect(0, 1);
    await connect(1, 2);
    for (final wire in wires) {
      wire.outgoing.clear();
      wire.log.clear();
    }
  });

  tearDown(() async {
    for (final node in nodes) {
      node.dispose();
    }
    for (final wire in wires) {
      wire.dispose();
    }
    for (final db in databases) {
      await db.close();
    }
    await temp.delete(recursive: true);
  });

  test(
    'A discovers C through B without pairing and sends a chat with ACK',
    () async {
      final c = nodes[2].myId!;
      expect(nodes[0].peers.containsKey(c), isFalse);
      expect(wires[0].devices.map((d) => d.endpointId), ['1']);
      await exchange();
      expect(nodes[0].peers[c], 'C');
      expect(nodes[0].isOnline(c), isFalse);
      expect(nodes[0].isReachable(c), isTrue);
      expect(nodes[0].connectionLabel(c), contains('ผ่าน B'));
      await nodes[0].sendTextMessage(receiverId: c, text: 'discovered chat');
      await pump();
      expect(nodes[2].messages.single.text, 'discovered chat');
      expect(nodes[0].messages.single.status, MessageStatus.delivered);
      expect(nodes[1].messages, isEmpty);
    },
  );

  test(
    'Rescue changes cross B and old cached entries cannot renew after restart',
    () async {
      final c = nodes[2].myId!;
      await nodes[2].setRescueMode(true);
      await exchange();
      expect(nodes[0].presence[c]!.rescue, isTrue);
      final old = wires[1].log
          .lastWhere(
            (p) =>
                p.$1 == '0' &&
                MessageModel.fromJson(p.$2).type == MessageType.presence,
          )
          .$2;
      await nodes[2].setRescueMode(false);
      await exchange();
      expect(nodes[0].presence[c]!.rescue, isFalse);
      final seen = nodes[0].presence[c]!.receivedAt;
      now = now.add(const Duration(seconds: 31));
      await restart(0);
      await connect(0, 1);
      await receive(0, 1, old);
      expect(nodes[0].presence[c]!.rescue, isFalse);
      expect(nodes[0].presence[c]!.receivedAt, seen);
      expect(nodes[0].isReachable(c), isFalse);
      expect(nodes[0].peers[c], 'C');
    },
  );

  test(
    'stale age and a missing first hop do not advertise reachable users',
    () async {
      final b = nodes[1].myId!;
      await receive(
        0,
        1,
        directoryPacket(1, 0, [advertisement('remote', b, age: 31000)]),
      );
      expect(nodes[0].peers['remote'], 'remote');
      expect(nodes[0].isReachable('remote'), isFalse);
      await exchange();
      final c = nodes[2].myId!;
      expect(nodes[0].isReachable(c), isTrue);
      wires[0].devices.clear();
      expect(nodes[0].isReachable(c), isFalse);
      expect(nodes[0].peers[c], 'C');
    },
  );

  test(
    'looped, spoofed and invalid-age entries do not hide a valid entry',
    () async {
      final b = nodes[1].myId!;
      await receive(
        0,
        1,
        directoryPacket(1, 0, [
          {
            ...advertisement('loop', b),
            'path': ['loop', nodes[0].myId!, b],
          },
          {
            ...advertisement('spoof', b),
            'path': ['spoof', 'wrong-hop'],
          },
          advertisement('negative', b, age: -1),
          advertisement('valid', b),
        ]),
      );
      expect(nodes[0].peers.keys, contains('valid'));
      for (final id in ['loop', 'spoof', 'negative']) {
        expect(nodes[0].peers.keys, isNot(contains(id)));
      }
      expect(nodes[0].isReachable('valid'), isTrue);
    },
  );

  test(
    'large directories are split under the byte limit and all peers arrive',
    () async {
      for (var i = 0; i < 12; i++) {
        final alert = SosAlert(
          incidentId: 'incident-$i',
          revision: 1,
          active: true,
          name: 'remote-$i',
          people: 1,
          category: EmergencyType.other,
          details: List.filled(900, 'ก').join(),
          updatedAt: now,
        );
        await receive(
          1,
          2,
          directoryPacket(2, 1, [
            advertisement('remote-$i', nodes[2].myId!, sos: alert),
          ], sequence: 10000 + i),
        );
      }
      wires[1].log.clear();
      await nodes[1].retry();
      final packets = wires[1].log
          .where(
            (p) =>
                p.$1 == '0' &&
                MessageModel.fromJson(p.$2).type == MessageType.presence,
          )
          .toList();
      expect(packets.length, greaterThan(1));
      for (final packet in packets) {
        expect(utf8.encode(packet.$2).length, lessThanOrEqualTo(32768));
      }
      await pump();
      for (var i = 0; i < 12; i++) {
        expect(nodes[0].peers, contains('remote-$i'));
      }
    },
  );

  test(
    'broadcast SOS updates/cancellation cross B once per revision and persist',
    () async {
      final c = nodes[2].myId!;
      final notices = <String>[];
      await nodes[0].setRescueMode(true);
      nodes[0].onSosReceived = notices.add;
      await publish(2);
      await exchange();
      expect(nodes[0].activeSosCount, 1);
      expect(notices, ['C']);
      final old = wires[1].log
          .lastWhere(
            (p) =>
                p.$1 == '0' &&
                MessageModel.fromJson(p.$2).type == MessageType.presence,
          )
          .$2;
      await exchange();
      expect(notices, ['C']);
      now = now.add(const Duration(seconds: 1));
      await publish(2, details: 'updated');
      await exchange();
      expect(nodes[0].presence[c]!.sos!.revision, 2);
      expect(nodes[0].presence[c]!.sos!.details, 'updated');
      expect(notices, ['C', 'C']);
      await nodes[2].cancelSos();
      await exchange();
      expect(nodes[0].activeSosCount, 0);
      await restart(0);
      await connect(0, 1);
      await receive(0, 1, old);
      expect(nodes[0].presence[c]!.sos!.active, isFalse);
      expect(nodes[0].presence[c]!.sos!.revision, 3);
    },
  );

  test(
    'targeted SOS reaches remote user and receives an end-to-end ACK',
    () async {
      await exchange();
      await publish(0, recipients: {nodes[2].myId!});
      await pump();
      expect(nodes[2].receivedSos, hasLength(1));
      expect(nodes[0].messages.single.type, MessageType.sos);
      expect(nodes[0].messages.single.status, MessageStatus.delivered);
      expect(nodes[0].receivedRoutes[nodes[0].messages.single.id], [
        nodes[0].myId,
        nodes[1].myId,
        nodes[2].myId,
      ]);
      expect(nodes[1].messages, isEmpty);
    },
  );

  test(
    'offline relay keeps latest cancellation across restart and rejects old open',
    () async {
      await exchange();
      final recipients = {nodes[2].myId!};
      wires[1].devices.removeWhere((d) => d.endpointId == '2');
      wires[2].devices.clear();
      await publish(0, recipients: recipients);
      final open = wires[0].log.lastWhere((p) {
        final data = jsonDecode(p.$2) as Map;
        return data['type'] == 'sos' && data.containsKey('relayPath');
      }).$2;
      await pump();
      await publish(0, recipients: recipients, details: 'revision two');
      await pump();
      await nodes[0].cancelSos();
      await pump();
      await restart(1);
      await connect(0, 1);
      await connect(1, 2);
      await pump();
      final owner = nodes[0].myId!;
      expect(nodes[2].presence[owner]!.sos!.active, isFalse);
      expect(nodes[2].presence[owner]!.sos!.revision, 3);
      expect(nodes[0].messages.last.status, MessageStatus.delivered);
      wires[1].log.clear();
      await receive(1, 0, open);
      expect(
        wires[1].log.where(
          (p) => MessageModel.fromJson(p.$2).type == MessageType.sos,
        ),
        isEmpty,
      );
      final old = RelayPacket.fromMap(jsonDecode(open) as Map<String, dynamic>);
      await receive(
        2,
        1,
        RelayPacket(old.message, [owner, nodes[1].myId!]).toJson(),
      );
      expect(nodes[2].presence[owner]!.sos!.revision, 3);
      expect(
        SosAlert.fromJson(nodes[2].receivedSos.single.text).active,
        isFalse,
      );
    },
  );

  test(
    'presence expiry does not cancel SOS; SOS expires after 24 hours',
    () async {
      await publish(2);
      await exchange();
      final c = nodes[2].myId!;
      now = now.add(const Duration(seconds: 31));
      expect(nodes[0].presence[c]!.isFresh(now), isFalse);
      expect(nodes[0].activeSosCount, 1);
      now = now.add(const Duration(hours: 24));
      expect(nodes[0].activeSosCount, 0);
      expect(nodes[0].presence[c]!.sos!.isExpired(now), isTrue);
      await restart(0);
      expect(nodes[0].activeSosCount, 0);
    },
  );

  test(
    'new incident wins after rapid cancellation with an unchanged clock',
    () async {
      await publish(2);
      await exchange();
      await nodes[2].cancelSos();
      await exchange();
      final cancelled = nodes[2].mySos!;
      await publish(2);
      await exchange();
      final current = nodes[0].presence[nodes[2].myId]!.sos!;
      expect(current.incidentId, isNot(cancelled.incidentId));
      expect(current.active, isTrue);
      expect(current.updatedAt.isAfter(cancelled.updatedAt), isTrue);
      await restart(0);
      expect(nodes[0].activeSosCount, 1);
    },
  );

  test(
    'expired active SOS is removed from the intermediary forward queue',
    () async {
      await exchange();
      wires[1].devices.removeWhere((d) => d.endpointId == '2');
      wires[2].devices.clear();
      await publish(0, recipients: {nodes[2].myId!});
      await pump();
      expect(
        await databases[1].relayItem(nodes[0].messages.single.id),
        isNotNull,
      );
      now = now.add(const Duration(hours: 25));
      await nodes[1].retry();
      expect(await databases[1].relayItem(nodes[0].messages.single.id), isNull);
      await connect(1, 2);
      await pump();
      expect(nodes[2].receivedSos, isEmpty);
      expect(nodes[2].activeSosCount, 0);
    },
  );
}
