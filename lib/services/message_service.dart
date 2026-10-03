import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/incoming_notice.dart';
import '../models/relay_packet.dart';
import '../models/sos_alert.dart';
import '../models/peer_presence.dart';
import 'local_database_service.dart';
import 'media_service.dart';
import 'nearby_service.dart';
import 'app_preferences.dart';

class MessageService extends ChangeNotifier {
  MessageService({
    required this.nearbyService,
    LocalDatabaseService? database,
    this.mediaService,
  }) : database = database ?? LocalDatabaseService.instance;
  final NearbyService nearbyService;
  final LocalDatabaseService database;
  final MediaService? mediaService;
  final _uuid = const Uuid();
  final Map<String, String> _endpointPeers = {};
  final Set<String> _relaySent = {};
  Set<String> _connectedEndpoints = {};
  Map<String, String> peers = {};
  List<MessageModel> messages = [];
  Map<String, List<String>> receivedRoutes = {};
  Map<String, int> unreadCounts = {};
  final Set<String> _markingRead = {};
  int get totalUnread =>
      unreadCounts.values.fold(0, (total, count) => total + count);

  String peerRoleLabel(String peerId) {
    final state = presence[peerId];
    if (state == null) return 'ยังไม่ทราบบทบาท';
    final role = state.rescue ? 'หน่วยกู้ภัย' : 'ผู้ใช้ทั่วไป';
    return state.isFresh(DateTime.now().toUtc()) ? role : '$role • สถานะล่าสุด';
  }

  String conversationPreview(String peerId) {
    final unread = (unreadCounts[peerId] ?? 0) > 0;
    final history = messages.where(
      (m) =>
          (m.senderId == peerId && m.receiverId == myId) ||
          (!unread && m.senderId == myId && m.receiverId == peerId),
    );
    if (history.isEmpty) return 'ยังไม่มีข้อความ';
    final latest = history.last;
    final prefix = latest.senderId == myId ? 'คุณ: ' : '';
    return prefix +
        switch (latest.type) {
          MessageType.media =>
            mediaService?.getCached(latest.text)?.isVideo == true
                ? 'วิดีโอ'
                : 'รูปภาพ / สื่อ',
          MessageType.sos => 'คำขอ SOS',
          _ => latest.text,
        };
  }

  Future<void> markConversationRead(String peerId, String messageId) async {
    if (!ready || _disposed || !_markingRead.add(peerId)) return;
    try {
      await database.markConversationRead(myId!, peerId, messageId);
      if (_disposed) return;
      unreadCounts = await database.getUnreadCounts(myId!);
      _notify();
    } finally {
      _markingRead.remove(peerId);
    }
  }

  String? myId, error;
  SosAlert? mySos;
  bool _publishingSos = false;
  bool rescueMode = false;

  /// คืน peerId (deviceId) ที่ตรงกับ endpointId — ใช้โดย MediaService
  String? getPeerForEndpoint(String endpointId) => _endpointPeers[endpointId];
  int _presenceSequence = 0;
  Map<String, PeerPresence> presence = {};
  void Function(String name)? onSosReceived;
  void Function(String name)? onMediaReceived;
  void Function(IncomingNotice notice)? onNotice;
  final Set<String> clockSkewPeers = {};

  void _notice(IncomingNotice notice) {
    if (_disposed || !AppPreferences.instance.alerts) return;
    onNotice?.call(notice);
  }

  void _sosNotice(String peer, SosAlert alert) {
    if (!rescueMode || !alert.active) return;
    onSosReceived?.call(alert.name);
    _notice(
      IncomingNotice(
        id: '${alert.incidentId}:${alert.revision}',
        peerId: peer,
        name: alert.name,
        body:
            '${alert.category.label} • ${alert.people} คน\n${alert.details}\n'
            '${alert.location == null ? 'ไม่ได้แนบพิกัด' : 'มีพิกัด • แตะดูรายละเอียด'}',
        sos: alert,
      ),
    );
  }

  int get activeSosCount => presence.values
      .where((p) => p.sos?.active == true && p.isFresh(DateTime.now().toUtc()))
      .length;
  Set<String> _sosRecipients = {};
  Set<String> get sosRecipients => Set.unmodifiable(_sosRecipients);
  List<MessageModel> get receivedSos {
    final latest = <String, MessageModel>{};
    for (final message in messages) {
      if (message.type != MessageType.sos || message.senderId == myId) continue;
      final alert = SosAlert.fromJson(message.text);
      final key = '${message.senderId}:${alert.incidentId}';
      final previous = latest[key];
      if (previous == null ||
          SosAlert.fromJson(previous.text).revision < alert.revision) {
        latest[key] = message;
      }
    }
    return latest.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> setRescueMode(bool value) async {
    if (!ready || _disposed) throw StateError('Message service is not ready');
    await database.setSetting('rescueMode', '$value');
    rescueMode = value;
    _notify();
    await retry();
  }

  Future<void> publishSos({
    required String name,
    required int people,
    required EmergencyType category,
    required String details,
    required Set<String> recipients,
    SosLocation? location,
    bool active = true,
  }) async {
    if (!ready || _disposed) throw StateError('Message service is not ready');
    if (_publishingSos) throw StateError('กำลังบันทึก SOS');
    if (!recipients.every(peers.containsKey)) {
      throw ArgumentError('กรุณาเลือกผู้รับที่เคยเชื่อมต่อ');
    }
    // Keep recipients fixed for an incident so cancellation reaches everyone.
    if (mySos?.active == true && !setEquals(recipients, _sosRecipients)) {
      throw ArgumentError('ยกเลิก SOS เดิมก่อนเปลี่ยนผู้รับ');
    }
    _publishingSos = true;
    try {
      await _reloadCurrentSos();
      final previous = mySos;
      if (!active && (previous == null || !previous.active)) return;
      final alert = SosAlert(
        incidentId: previous?.active == true
            ? previous!.incidentId
            : _uuid.v4(),
        revision: previous?.active == true ? previous!.revision + 1 : 1,
        active: active,
        name: name.trim(),
        people: people,
        category: category,
        details: details.trim(),
        location: location,
        updatedAt: DateTime.now().toUtc(),
      );
      await database.saveSos(
        jsonEncode({
          'alert': alert.toJson(),
          'recipients': recipients.toList(),
        }),
        [
          for (final peer in recipients)
            MessageModel(
              id: '${alert.incidentId}:${alert.revision}:$peer',
              senderId: myId!,
              senderName: alert.name,
              receiverId: peer,
              text: alert.toJson(),
              timestamp: alert.updatedAt,
              type: MessageType.sos,
            ),
        ],
      );
      mySos = alert;
      _sosRecipients = Set.of(recipients);
      await _refresh();
      await retry();
    } finally {
      _publishingSos = false;
    }
  }

  Future<void> cancelSos() async {
    final alert = mySos;
    if (alert == null) return;
    await publishSos(
      name: alert.name,
      people: alert.people,
      category: alert.category,
      details: alert.details,
      recipients: _sosRecipients,
      location: alert.location,
      active: false,
    );
  }

  Timer? _timer;
  bool _disposed = false, _ticking = false;
  Future<void> _incoming = Future.value();
  bool get ready => myId != null;
  bool isOnline(String peerId) => _endpointPeers.entries.any(
    (e) =>
        e.value == peerId &&
        nearbyService.connectedDevices.any((d) => d.endpointId == e.key),
  );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      myId = await database.getDeviceId();
      final savedSos = await database.getSetting('mySos');
      if (savedSos != null) {
        final saved = jsonDecode(savedSos) as Map<String, dynamic>;
        mySos = SosAlert.fromJson(saved['alert'] as String);
        _sosRecipients = (saved['recipients'] as List).cast<String>().toSet();
      }
      rescueMode = await database.getSetting('rescueMode') == 'true';
      _presenceSequence = int.parse(
        await database.getSetting('presenceSequence') ?? '0',
      );
      final savedPresence = await database.getSetting('peerPresence');
      if (savedPresence != null) {
        presence = (jsonDecode(savedPresence) as Map<String, dynamic>).map(
          (id, value) => MapEntry(id, PeerPresence.decode(value as String)),
        );
      }
      await _refresh();
      // เริ่มต้น MediaService และส่ง myId
      if (mediaService != null) {
        mediaService!.onMessagesChanged = _refresh;
        mediaService!.onReceived = (media) {
          if (!AppPreferences.instance.alerts) return;
          onMediaReceived?.call(media.senderName);
          _notice(
            IncomingNotice(
              id: media.messageId,
              peerId: media.senderId,
              name: media.senderName,
              body:
                  'ส่ง${media.isImage ? 'รูปภาพ' : 'วิดีโอ'}: ${media.fileName}',
            ),
          );
        };
        await mediaService!.initialize(myId!);
      }
      if (_disposed) return;
      nearbyService.onTextPayloadReceived = (endpoint, payload) {
        _incoming = _incoming.then(
          (_) =>
              handleIncomingPayload(endpointId: endpoint, rawPayload: payload),
        );
      };
      nearbyService.addListener(_connectionChanged);
      _timer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(retry()),
      );
      await retry();
    } catch (e) {
      myId = null;
      error = 'Cannot open message storage: $e';
      _notify();
    }
  }

  Future<void> _refresh() async {
    await _reloadCurrentSos();
    receivedRoutes = await database.getReceivedRoutes();
    messages = await database.getMessages();
    peers = await database.getPeers();
    unreadCounts = await database.getUnreadCounts(myId!);
    _notify();
  }

  Future<void> _reloadCurrentSos() async {
    final saved = await database.getSetting('mySos');
    if (saved == null) return;
    final state = jsonDecode(saved) as Map<String, dynamic>;
    mySos = SosAlert.fromJson(state['alert'] as String);
    _sosRecipients = (state['recipients'] as List).cast<String>().toSet();
  }

  void _connectionChanged() {
    final connected = nearbyService.connectedDevices
        .map((d) => d.endpointId)
        .toSet();
    if (setEquals(connected, _connectedEndpoints)) return;
    _connectedEndpoints = connected;
    // A relay peer may have restarted; permit unacknowledged packets again.
    _relaySent.clear();
    _endpointPeers.removeWhere((id, _) => !connected.contains(id));
    if (mediaService != null) unawaited(mediaService!.pauseDisconnected());
    _notify();
    unawaited(retry());
  }

  MessageModel _packet(
    MessageType type, {
    String receiver = '',
    String text = '',
    String? ackFor,
  }) => MessageModel(
    id: _uuid.v4(),
    senderId: myId!,
    senderName: nearbyService.deviceName,
    receiverId: receiver,
    text: text,
    timestamp: DateTime.now().toUtc(),
    type: type,
    ackFor: ackFor,
  );

  Future<void> sendTextMessage({
    required String receiverId,
    required String text,
  }) async {
    if (!ready || _disposed) throw StateError('Message service is not ready');
    if (!peers.containsKey(receiverId)) throw ArgumentError('Unknown peer');
    text = text.trim();
    if (text.isEmpty) throw ArgumentError('Enter a message');
    final message = _packet(
      MessageType.message,
      receiver: receiverId,
      text: text,
    );
    // Reserve room for the bounded relay path (including JSON escaping).
    if (utf8.encode(message.toJson()).length > 32768 - 8192) {
      throw ArgumentError(
        'Message exceeds 24 KB before the reserved relay path',
      );
    }
    await database.insertMessage(message);
    await _refresh();
    await retry();
  }

  Future<void> retry() async {
    if (!ready || _disposed || _ticking) return;
    _ticking = true;
    try {
      if (!_publishingSos) await _reloadCurrentSos();
      String? retryError;
      for (final device in nearbyService.connectedDevices) {
        try {
          if (_disposed) return;
          // Repeat introductions so a packet lost during connection setup recovers.
          await nearbyService.sendMessage(
            device.endpointId,
            _packet(MessageType.deviceInfo).toJson(),
          );
          final peer = _endpointPeers[device.endpointId];
          if (peer == null) continue;
          _presenceSequence++;
          await database.setSetting(
            'presenceSequence',
            _presenceSequence.toString(),
          );
          await nearbyService.sendMessage(
            device.endpointId,
            _packet(
              MessageType.presence,
              receiver: peer,
              text: PeerPresence(
                sequence: _presenceSequence,
                rescue: rescueMode,
                sos: mySos,
                receivedAt: DateTime.now().toUtc(),
              ).encode(),
            ).toJson(),
          );
          // ─── ส่งสื่อที่ค้างไว้ (MediaService) ─────────────────────────────
          if (mediaService != null) {
            try {
              await mediaService!.sendPendingForPeer(
                peerId: peer,
                endpointId: device.endpointId,
              );
            } catch (e) {
              retryError = 'Media retry failed for ${device.name}: $e';
            }
          }
          final history = await database.getMessages();
          final latestSos = <String, int>{};
          if (mySos != null) latestSos[mySos!.incidentId] = mySos!.revision;
          for (final m in history.where(
            (m) => m.type == MessageType.sos && m.senderId == myId,
          )) {
            final alert = SosAlert.fromJson(m.text);
            if ((latestSos[alert.incidentId] ?? 0) < alert.revision) {
              latestSos[alert.incidentId] = alert.revision;
            }
          }
          for (final message in history) {
            if (_disposed) return;
            if (message.type == MessageType.sos) {
              final alert = SosAlert.fromJson(message.text);
              if (alert.revision < (latestSos[alert.incidentId] ?? 0)) continue;
            }
            // ข้ามข้อความ media (จัดการโดย MediaService แยกต่างหาก)
            if (message.type == MessageType.media) continue;
            if (message.senderId != myId ||
                message.status.index >= MessageStatus.delivered.index) {
              continue;
            }
            if (message.receiverId != peer) {
              if (message.type != MessageType.message ||
                  isOnline(message.receiverId)) {
                continue;
              }
              final key = '${message.id}:$peer';
              if (_relaySent.contains(key)) continue;
              await nearbyService.sendMessage(
                device.endpointId,
                RelayPacket(message, [myId!]).toJson(),
              );
              _relaySent.add(key);
              await database.updateMessageStatus(
                message.id,
                MessageStatus.sent,
              );
              continue;
            }
            await nearbyService.sendMessage(
              device.endpointId,
              message.toJson(),
            );
            await database.updateMessageStatus(message.id, MessageStatus.sent);
          }
        } catch (e) {
          retryError = 'Waiting to retry ${device.name}: $e';
        }
      }
      error = retryError;
      await _refresh();
    } catch (e) {
      error = 'Waiting to retry: $e';
      _notify();
    } finally {
      _ticking = false;
    }
  }

  Future<void> handleIncomingPayload({
    required String endpointId,
    required String rawPayload,
  }) async {
    if (!ready || _disposed) return;
    try {
      if (utf8.encode(rawPayload).length > 32768) {
        throw const FormatException('Payload exceeds 32 KB');
      }
      if (!nearbyService.connectedDevices.any(
        (d) => d.endpointId == endpointId,
      )) {
        return;
      }
      final data = jsonDecode(rawPayload) as Map<String, dynamic>;
      if (data.containsKey('relayVersion') || data.containsKey('relayPath')) {
        await _receiveRelay(endpointId, RelayPacket.fromMap(data));
        return;
      }
      // ─── Media protocol packets (ไม่ถูก parse เป็น MessageModel) ─────────
      if (data.containsKey('packetType')) {
        await _receiveMediaPacket(endpointId, data);
        return;
      }
      final packet = MessageModel.fromMap(data);
      if (packet.senderId == myId) return;
      if (packet.type == MessageType.deviceInfo) {
        if (DateTime.now().toUtc().difference(packet.timestamp).abs() >
            const Duration(minutes: 5)) {
          clockSkewPeers.add(packet.senderId);
        } else {
          clockSkewPeers.remove(packet.senderId);
        }
        final existing = _endpointPeers[endpointId];
        if (existing != null && existing != packet.senderId) {
          throw const FormatException('Peer identity changed');
        }
        await database.savePeer(packet.senderId, packet.senderName);
        _endpointPeers[endpointId] = packet.senderId;
        await _refresh();
        if (existing == null) await retry();
        return;
      }
      if (packet.receiverId != myId ||
          _endpointPeers[endpointId] != packet.senderId) {
        return;
      }
      switch (packet.type) {
        case MessageType.message:
        case MessageType.sos:
          if (packet.type == MessageType.sos) SosAlert.fromJson(packet.text);
          final inserted = await database.insertMessage(
            packet.copyWith(status: MessageStatus.delivered),
          );
          await database.saveReceivedRoute(packet.id, [packet.senderId, myId!]);
          await _refresh();
          if (inserted && packet.type == MessageType.message) {
            _notice(
              IncomingNotice(
                id: packet.id,
                peerId: packet.senderId,
                name: packet.senderName,
                body: packet.text,
              ),
            );
          }
          await nearbyService.sendMessage(
            endpointId,
            _packet(
              MessageType.ack,
              receiver: packet.senderId,
              ackFor: packet.id,
            ).toJson(),
          );
        case MessageType.ack:
          final originals = await database.getMessages();
          if (originals.any(
            (m) =>
                m.id == packet.ackFor &&
                m.senderId == myId &&
                m.receiverId == packet.senderId,
          )) {
            await database.saveReceivedRoute(packet.ackFor!, [
              myId!,
              packet.senderId,
            ]);
            await database.updateMessageStatus(
              packet.ackFor!,
              MessageStatus.delivered,
            );
            await _refresh();
          }
        case MessageType.presence:
          // (presence handling unchanged)
          final state = PeerPresence.decode(
            packet.text,
            receivedAt: DateTime.now().toUtc(),
          );
          if (state.sequence > (presence[packet.senderId]?.sequence ?? 0)) {
            final previous = presence[packet.senderId]?.sos;
            final updated = {...presence, packet.senderId: state};
            await database.setSetting(
              'peerPresence',
              jsonEncode(
                updated.map((id, value) => MapEntry(id, value.encode())),
              ),
            );
            presence = updated;
            _notify();
            final alert = state.sos;
            if (alert != null &&
                alert.active &&
                (previous == null ||
                    previous.incidentId != alert.incidentId ||
                    previous.revision < alert.revision)) {
              _sosNotice(packet.senderId, alert);
            }
          }
        case MessageType.deviceInfo:
          break;
        case MessageType.media:
          break; // media messages ถูกสร้างโดย MediaService ไม่ใช่ผ่าน wire โดยตรง
      }
    } catch (e) {
      error = 'Receive failed: $e';
      _notify();
    }
  }

  Future<void> _receiveRelay(String endpointId, RelayPacket relay) async {
    final packet = relay.message;
    if (_endpointPeers[endpointId] != relay.path.last ||
        packet.senderId == myId ||
        relay.path.contains(myId)) {
      return;
    }
    if (packet.receiverId == myId) {
      // SQLite verifies duplicate content and keeps exactly one inbox row.
      final inserted = await database.insertMessage(
        packet.copyWith(status: MessageStatus.delivered),
      );
      await database.savePeer(packet.senderId, packet.senderName);
      await database.saveReceivedRoute(packet.id, [...relay.path, myId!]);
      await _refresh();
      if (inserted) {
        _notice(
          IncomingNotice(
            id: packet.id,
            peerId: packet.senderId,
            name: packet.senderName,
            body: packet.text,
          ),
        );
      }
      // End-to-end relay ACK is deliberately deferred to Phase 5 part 2.
      return;
    }
    if (relay.path.length >= RelayPacket.maxHops) return;
    if (!await database.claimRelay(packet.id)) return;
    final forwarded = RelayPacket(packet, [...relay.path, myId!]).toJson();
    if (utf8.encode(forwarded).length > 32768) {
      throw const FormatException('Relay payload exceeds 32 KB');
    }
    for (final device in nearbyService.connectedDevices.toList()) {
      if (_disposed) return;
      final peer = _endpointPeers[device.endpointId];
      if (peer == null ||
          device.endpointId == endpointId ||
          relay.path.contains(peer)) {
        continue;
      }
      try {
        await nearbyService.sendMessage(device.endpointId, forwarded);
      } catch (e) {
        // Try other neighbors even when one link fails. No relay queue yet.
        error = 'Relay failed: $e';
        _notify();
      }
    }
  }

  /// Route packetType packets ไปยัง MediaService
  Future<void> _receiveMediaPacket(
    String endpointId,
    Map<String, dynamic> data,
  ) async {
    final packetType = data['packetType'] as String?;
    switch (packetType) {
      case 'mediaInit':
        if (mediaService != null) {
          if (_endpointPeers[endpointId] != data['senderId']) return;
          await mediaService!.handleMediaInit(endpointId, data);
          await _refresh(); // อัพเดต chat list
        }
      case 'mediaAck':
        if (mediaService != null) {
          final peer = _endpointPeers[endpointId];
          if (peer != null) {
            await mediaService!.handleMediaAck(data, peerId: peer);
          }
          await _refresh();
        }
      default:
        debugPrint('[MessageService] Unknown packetType: $packetType');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    nearbyService.removeListener(_connectionChanged);
    nearbyService.onTextPayloadReceived = null;
    super.dispose();
  }
}
