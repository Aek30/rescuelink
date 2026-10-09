import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/incoming_notice.dart';
import '../models/relay_packet.dart';
import '../models/sos_alert.dart';
import '../models/peer_presence.dart';
import '../models/peer_advertisement.dart';
import 'local_database_service.dart';
import 'media_service.dart';
import 'nearby_service.dart';
import 'app_preferences.dart';

class MessageService extends ChangeNotifier {
  MessageService({
    required this.nearbyService,
    LocalDatabaseService? database,
    this.mediaService,
    DateTime Function()? clock,
  }) : database = database ?? LocalDatabaseService.instance,
       _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  DateTime _now() => _clock().toUtc();
  final NearbyService nearbyService;
  final LocalDatabaseService database;
  final MediaService? mediaService;
  final _uuid = const Uuid();
  final Map<String, String> _endpointPeers = {};
  bool _relayDraining = false;
  bool _resetRelayBackoff = true;
  DateTime? _lastRelayCleanup;
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
    return state.isFresh(_now()) ? role : '$role • สถานะล่าสุด';
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
  bool _changingRescue = false;

  /// คืน peerId (deviceId) ที่ตรงกับ endpointId — ใช้โดย MediaService
  String? getPeerForEndpoint(String endpointId) => _endpointPeers[endpointId];
  int _presenceSequence = 0;
  Map<String, PeerPresence> presence = {};
  final Map<String, PeerAdvertisement> _directory = {};
  Map<String, Map<String, SosAlert>> _remoteSos = {};

  bool isReachable(String peerId) {
    if (isOnline(peerId)) return true;
    final entry = _directory[peerId];
    return entry != null &&
        entry.path.length > 2 &&
        entry.state.isFresh(_now()) &&
        isOnline(entry.path[entry.path.length - 2]);
  }

  String connectionLabel(String peerId) {
    if (isOnline(peerId)) return 'เชื่อมต่อโดยตรง';
    final entry = _directory[peerId];
    if (entry != null && isReachable(peerId)) {
      final via = entry.path[entry.path.length - 2];
      return 'ส่งต่อผ่าน ${peers[via] ?? 'เครื่องกลาง'} • เครื่องกลาง ${entry.path.length - 2} เครื่อง';
    }
    return 'ยังติดต่อไม่ได้ • รอเชื่อมต่อ';
  }

  /// Origin to destination route when the first radio link is currently up.
  List<String>? relayPathForPeer(String peerId) {
    final entry = _directory[peerId];
    if (entry == null || !entry.state.isFresh(_now()) || !isReachable(peerId)) {
      return null;
    }
    return entry.path.reversed.toList();
  }

  void Function(String name)? onSosReceived;
  void Function(String name)? onMediaReceived;
  void Function(IncomingNotice notice)? onNotice;
  final Set<String> clockSkewPeers = {};

  void _notice(IncomingNotice notice) {
    if (_disposed || !AppPreferences.instance.alerts) return;
    onNotice?.call(notice);
  }

  void _sosNotice(String peer, SosAlert alert) {
    if (!rescueMode || !alert.isActiveAt(_now())) return;
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

  int get activeSosCount =>
      presence.values.where((p) => p.sos?.isActiveAt(_now()) == true).length;
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
    if (_publishingSos || _changingRescue) {
      throw StateError('กำลังเปลี่ยนโหมด กรุณารอสักครู่');
    }
    _changingRescue = true;
    try {
      // Use the existing cancellation revision and outbox for every recipient.
      if (value && mySos?.isActiveAt(_now()) == true) await cancelSos();
      await database.setSetting('rescueMode', '$value');
      rescueMode = value;
      _notify();
      await retry();
    } finally {
      _changingRescue = false;
    }
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
    if (active && _changingRescue) throw StateError('กำลังเปลี่ยนโหมด');
    if (!recipients.every(peers.containsKey)) {
      throw ArgumentError('กรุณาเลือกผู้รับจากรายชื่อที่รู้จัก');
    }
    // Keep recipients fixed for an incident so cancellation reaches everyone.
    if (mySos?.isActiveAt(_now()) == true &&
        !setEquals(recipients, _sosRecipients)) {
      throw ArgumentError('ยกเลิก SOS เดิมก่อนเปลี่ยนผู้รับ');
    }
    _publishingSos = true;
    try {
      await _reloadCurrentSos();
      final previous = mySos;
      if (!active && (previous == null || !previous.active)) return;
      final sameIncident =
          previous?.active == true && (!active || previous!.isActiveAt(_now()));
      final now = _now();
      final updatedAt = previous != null && !now.isAfter(previous.updatedAt)
          ? previous.updatedAt.add(const Duration(microseconds: 1))
          : now;
      final alert = SosAlert(
        incidentId: sameIncident ? previous!.incidentId : _uuid.v4(),
        revision: sameIncident ? previous!.revision + 1 : 1,
        active: active,
        name: name.trim(),
        people: people,
        category: category,
        details: details.trim(),
        location: location,
        updatedAt: updatedAt,
      );
      if (active && rescueMode) {
        await database.setSetting('rescueMode', 'false');
        rescueMode = false;
        _notify();
      }
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
      if (rescueMode && mySos?.isActiveAt(_now()) == true) {
        rescueMode = false;
        await database.setSetting('rescueMode', 'false');
      }
      _presenceSequence = int.parse(
        await database.getSetting('presenceSequence') ?? '0',
      );
      final savedPresence = await database.getSetting('peerPresence');
      if (savedPresence != null) {
        presence = (jsonDecode(savedPresence) as Map<String, dynamic>).map(
          (id, value) => MapEntry(id, PeerPresence.decode(value as String)),
        );
      }
      final savedDirectory = await database.getSetting('peerDirectory');
      if (savedDirectory != null) {
        for (final value
            in (jsonDecode(savedDirectory) as Map<String, dynamic>).values) {
          final entry = PeerAdvertisement.fromStored(
            value as Map<String, dynamic>,
          );
          _directory[entry.peerId] = entry;
          presence[entry.peerId] = entry.state;
        }
      }
      // Seed revision tombstones from presence saved by older app versions.
      for (final entry in presence.entries) {
        if (entry.value.sos != null) {
          await database.recordRemoteSos(entry.key, entry.value.sos!);
        }
      }
      _remoteSos = await database.getRemoteSos();
      for (final owner in _remoteSos.keys) {
        _projectSos(owner);
      }
      await _refresh();
      // เริ่มต้น MediaService และส่ง myId
      if (mediaService != null) {
        mediaService!.onMessagesChanged = _refresh;
        mediaService!.onRelayReceived = (media, route) async {
          await _sendOrQueueRelayAck(
            messageId: media.messageId,
            senderId: media.senderId,
            receivedPath: route,
          );
        };
        mediaService!.onRelayFileReady = _drainRelayQueues;
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
        unawaited(
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

  SosAlert? _latestSos(String owner) {
    final incidents = _remoteSos[owner]?.values.toList();
    if (incidents == null || incidents.isEmpty) return null;
    incidents.sort((a, b) {
      final order = b.updatedAt.compareTo(a.updatedAt);
      return order != 0 ? order : b.incidentId.compareTo(a.incidentId);
    });
    return incidents.first;
  }

  void _projectSos(String owner) {
    final alert = _latestSos(owner);
    if (alert == null) return;
    final previous = presence[owner];
    presence[owner] = PeerPresence(
      sequence: previous?.sequence ?? 1,
      rescue: previous?.rescue ?? false,
      // A targeted SOS does not prove that a cached Rescue role is current.
      receivedAt:
          previous?.receivedAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sos: alert,
    );
  }

  Future<void> _learnSos(String owner, String name, SosAlert alert) async {
    final changed = await database.recordRemoteSos(owner, alert);
    if (!peers.containsKey(owner)) {
      await database.savePeer(owner, name);
      peers[owner] = name;
    }
    if (changed) _remoteSos = await database.getRemoteSos();
    _projectSos(owner);
    final latest = _latestSos(owner);
    if (changed &&
        latest?.incidentId == alert.incidentId &&
        latest?.revision == alert.revision) {
      _sosNotice(owner, alert);
    }
  }

  Future<void> _saveDirectory() async {
    await database.setSetting(
      'peerDirectory',
      jsonEncode(_directory.map((id, entry) => MapEntry(id, entry.toStored()))),
    );
    await database.setSetting(
      'peerPresence',
      jsonEncode(presence.map((id, state) => MapEntry(id, state.encode()))),
    );
  }

  Future<void> _acceptAdvertisement(PeerAdvertisement entry) async {
    if (entry.peerId == myId) return;
    final previous = _directory[entry.peerId];
    if (entry.state.sos != null) {
      await _learnSos(entry.peerId, entry.name, entry.state.sos!);
    }
    if (previous != null && entry.state.sequence <= previous.state.sequence) {
      // An equal sequence may offer a better route, but never a fresh lease.
      if (entry.state.sequence == previous.state.sequence &&
          (entry.path.length < previous.path.length ||
              !isOnline(previous.path[previous.path.length - 2]))) {
        _directory[entry.peerId] = PeerAdvertisement(
          peerId: entry.peerId,
          name: previous.name,
          state: previous.state,
          path: entry.path,
        );
      }
      return;
    }
    _directory[entry.peerId] = entry;
    presence[entry.peerId] = entry.state;
    _projectSos(entry.peerId);
    await database.savePeer(entry.peerId, entry.name);
    peers[entry.peerId] = entry.name;
  }

  Future<void> _receivePresence(MessageModel packet) async {
    final now = _now();
    if (packet.senderId.length > 128 ||
        packet.senderName.trim().isEmpty ||
        packet.senderName.length > 128) {
      throw const FormatException('Invalid presence identity');
    }
    await _acceptAdvertisement(
      PeerAdvertisement(
        peerId: packet.senderId,
        name: packet.senderName,
        state: PeerPresence.decode(packet.text, receivedAt: now),
        path: [packet.senderId, myId!],
      ),
    );
    final body = jsonDecode(packet.text) as Map<String, dynamic>;
    if (body.containsKey('directory')) {
      final entries = body['directory'];
      if (body['directoryVersion'] != 1 ||
          entries is! List ||
          entries.length > 64) {
        throw const FormatException('Invalid peer directory');
      }
      for (final data in entries) {
        try {
          final entry = PeerAdvertisement.fromWire(
            data as Map<String, dynamic>,
            advertiser: packet.senderId,
            receiver: myId!,
            now: now,
          );
          await _acceptAdvertisement(entry);
        } on FormatException {
          // One bad/looped advertisement cannot hide other valid peers.
          continue;
        } on TypeError {
          continue;
        }
      }
    }
    await _saveDirectory();
    await _refresh();
  }

  Iterable<String> _presencePackets(String receiver, PeerPresence local) sync* {
    final now = _now();
    final body = jsonDecode(local.encode()) as Map<String, dynamic>;
    String encode(List<Map<String, Object?>> entries) => _packet(
      MessageType.presence,
      receiver: receiver,
      text: jsonEncode({...body, 'directoryVersion': 1, 'directory': entries}),
    ).toJson();
    var chunk = <Map<String, Object?>>[];
    for (final entry in _directory.values.toList()) {
      if (entry.path.contains(receiver) ||
          entry.path.length > RelayPacket.maxHops ||
          now.isBefore(entry.state.receivedAt) ||
          now.difference(entry.state.receivedAt) >=
              PeerAdvertisement.retention) {
        continue;
      }
      final state = entry.state;
      final wire = PeerAdvertisement(
        peerId: entry.peerId,
        name: entry.name,
        path: entry.path,
        state: PeerPresence(
          sequence: state.sequence,
          rescue: state.rescue,
          receivedAt: state.receivedAt,
          sos: _latestSos(entry.peerId) ?? state.sos,
        ),
      ).toWire(now);
      if (chunk.isNotEmpty &&
          (chunk.length >= 32 ||
              utf8.encode(encode([...chunk, wire])).length > 24 * 1024)) {
        yield encode(chunk);
        chunk = [];
      }
      if (utf8.encode(encode([wire])).length <= 24 * 1024) chunk.add(wire);
    }
    yield encode(chunk);
  }

  bool _mayForwardSos(String owner, SosAlert alert) =>
      !alert.isExpired(_now()) &&
      alert.revision >= (_remoteSos[owner]?[alert.incidentId]?.revision ?? 0);

  void _connectionChanged() {
    final connected = nearbyService.connectedDevices
        .map((d) => d.endpointId)
        .toSet();
    if (setEquals(connected, _connectedEndpoints)) return;
    _connectedEndpoints = connected;
    _resetRelayBackoff = true;
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
    timestamp: _now(),
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
      await _drainRelayQueues();
      if (!_publishingSos) await _reloadCurrentSos();
      String? retryError;
      _presenceSequence++;
      await database.setSetting('presenceSequence', '$_presenceSequence');
      final localState = PeerPresence(
        sequence: _presenceSequence,
        rescue: rescueMode,
        sos: mySos,
        receivedAt: _now(),
      );
      for (final device in nearbyService.connectedDevices.toList()) {
        try {
          if (_disposed) return;
          // Repeat introductions so a packet lost during connection setup recovers.
          await nearbyService.sendMessage(
            device.endpointId,
            _packet(MessageType.deviceInfo).toJson(),
          );
          final peer = _endpointPeers[device.endpointId];
          if (peer == null) continue;
          for (final payload in _presencePackets(peer, localState)) {
            await nearbyService.sendMessage(device.endpointId, payload);
          }
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
              if (alert.isExpired(_now())) continue;
              if (alert.revision < (latestSos[alert.incidentId] ?? 0)) continue;
            }
            // ข้ามข้อความ media (จัดการโดย MediaService แยกต่างหาก)
            if (message.type == MessageType.media) continue;
            if (message.senderId != myId ||
                message.status.index >= MessageStatus.delivered.index) {
              continue;
            }
            if (message.receiverId != peer) {
              if ((message.type != MessageType.message &&
                      message.type != MessageType.sos) ||
                  isOnline(message.receiverId)) {
                continue;
              }
              // Keep retrying until the destination ACK arrives, including
              // when a previous native send succeeded but the packet was lost.
              await nearbyService.sendMessage(
                device.endpointId,
                RelayPacket(message, [myId!]).toJson(),
              );
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
  }) {
    _incoming = _incoming.then(
      (_) => _handleIncomingPayload(
        endpointId: endpointId,
        rawPayload: rawPayload,
      ),
    );
    return _incoming;
  }

  Future<void> _handleIncomingPayload({
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
        if (existing == null) {
          _resetRelayBackoff = true;
          await retry();
        }
        return;
      }
      if (packet.receiverId != myId ||
          _endpointPeers[endpointId] != packet.senderId) {
        return;
      }
      switch (packet.type) {
        case MessageType.message:
        case MessageType.sos:
          final alert = packet.type == MessageType.sos
              ? SosAlert.fromJson(packet.text)
              : null;
          final inserted = await database.insertMessage(
            packet.copyWith(status: MessageStatus.delivered),
          );
          await database.saveReceivedRoute(packet.id, [packet.senderId, myId!]);
          if (alert != null) {
            await _learnSos(packet.senderId, packet.senderName, alert);
            await _saveDirectory();
          }
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
          await _receivePresence(packet);
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
    if (packet.type == MessageType.ack) {
      await _receiveRelayAck(relay);
      return;
    }
    SosAlert? sos;
    if (packet.type == MessageType.sos) {
      sos = SosAlert.fromJson(packet.text);
      await _learnSos(packet.senderId, packet.senderName, sos);
      await _saveDirectory();
    }
    if (packet.type == MessageType.media) {
      final metadata = jsonDecode(packet.text) as Map<String, dynamic>;
      final route = [...relay.path, myId!];
      await mediaService?.handleRelayMediaInit(endpointId, metadata, route);
      if (packet.receiverId == myId) {
        await database.savePeer(packet.senderId, packet.senderName);
        await database.saveReceivedRoute(packet.id, route);
        return; // The media service sends the end-to-end ACK after verification.
      }
    }
    if (packet.receiverId == myId) {
      // SQLite verifies duplicate content and keeps exactly one inbox row.
      final inserted = await database.insertMessage(
        packet.copyWith(status: MessageStatus.delivered),
      );
      await database.savePeer(packet.senderId, packet.senderName);
      final receivedPath = [...relay.path, myId!];
      await database.saveReceivedRoute(packet.id, receivedPath);
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
      await _sendOrQueueRelayAck(
        messageId: packet.id,
        senderId: packet.senderId,
        receivedPath: receivedPath,
      );
      return;
    }
    if (relay.path.length >= RelayPacket.maxHops) return;
    if (sos != null && !_mayForwardSos(packet.senderId, sos)) return;
    final forwarded = RelayPacket(packet, [...relay.path, myId!]).toJson();
    if (utf8.encode(forwarded).length > 32768) {
      throw const FormatException('Relay payload exceeds 32 KB');
    }
    await database.enqueueRelay(
      packetId: packet.id,
      payload: forwarded,
      destPeer: packet.receiverId,
    );
    final job = await database.relayItem(packet.id);
    final receipt = job?['ack_payload'] as String?;
    if (receipt != null) {
      final cached = RelayPacket.fromMap(
        jsonDecode(receipt) as Map<String, dynamic>,
      );
      // Reuse the proven ACK origin, but return along this incoming path.
      final route = [...cached.path, ...relay.path.reversed];
      final ack = RelayPacket(cached.message, cached.path, ackRoute: route);
      RelayPacket.fromMap(jsonDecode(ack.toJson()) as Map<String, dynamic>);
      await database.enqueueRelayAck(
        ackFor: packet.id,
        payload: ack.toJson(),
        destPeer: route[cached.path.length],
      );
    }
    await _drainRelayQueues();
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

  // ─── Phase 5 Part 2: Relay ACK helpers ──────────────────────────────────

  /// C ส่ง relay ACK กลับ A ตาม path ที่บันทึกไว้
  /// ถ้าเส้นทางขาดให้ enqueue รอ reconnect
  Future<void> _sendOrQueueRelayAck({
    required String messageId,
    required String senderId,
    required List<String> receivedPath,
  }) async {
    if (!ready || _disposed) return;
    final ackPath = receivedPath.reversed.toList();
    if (ackPath.length < 2) return; // direct link — ไม่ใช้ relay ACK
    final nextHopId = ackPath[1];
    final ack = MessageModel(
      id: _uuid.v4(),
      senderId: myId!,
      senderName: nearbyService.deviceName,
      receiverId: senderId,
      text: '',
      timestamp: DateTime.now().toUtc(),
      type: MessageType.ack,
      ackFor: messageId,
    );
    final ackPacket = RelayPacket(ack, [myId!], ackRoute: ackPath).toJson();
    await database.enqueueRelayAck(
      ackFor: messageId,
      payload: ackPacket,
      destPeer: nextHopId,
    );
    await _drainRelayQueues();
  }

  Future<void> _receiveRelayAck(RelayPacket relay) async {
    final ack = relay.message;
    final route = relay.ackRoute!;
    if (route[relay.path.length] != myId) return;
    if (ack.receiverId == myId) {
      final originals = await database.getMessages();
      final original = originals
          .where(
            (m) =>
                m.id == ack.ackFor &&
                m.senderId == myId &&
                m.receiverId == ack.senderId &&
                (m.type == MessageType.message ||
                    m.type == MessageType.sos ||
                    m.type == MessageType.media),
          )
          .firstOrNull;
      if (original == null) return;
      await database.saveReceivedRoute(ack.ackFor!, route.reversed.toList());
      if (original.status.index < MessageStatus.delivered.index) {
        await database.updateMessageStatus(
          ack.ackFor!,
          MessageStatus.delivered,
        );
      }
      if (original.type == MessageType.media) {
        await mediaService?.acceptOriginRelayMediaAck(original.id);
      }
      await _refresh();
      return; // Never ACK an ACK or insert it into chat history.
    }
    final job = await database.relayItem(ack.ackFor!);
    if (job == null) return;
    final data = RelayPacket.fromMap(
      jsonDecode(job['payload'] as String) as Map<String, dynamic>,
    );
    // The ACK must return along the path on which this node accepted the data.
    final forwardPrefix = route.sublist(relay.path.length).reversed.toList();
    if (!listEquals(data.path, forwardPrefix)) return;
    final forwarded = RelayPacket(ack, [...relay.path, myId!], ackRoute: route);
    if (await database.acceptRelayAck(
      ack: ack,
      payload: forwarded.toJson(),
      destPeer: route[relay.path.length + 1],
    )) {
      if (data.message.type == MessageType.media) {
        await mediaService?.acceptRelayMediaAck(data.message.id);
      }
      await _drainRelayQueues();
    }
  }

  /// One serialized drain serves receipt callbacks, the five-second timer,
  /// reconnections and restarts. Failed jobs never silently exhaust retries.
  Future<void> _drainRelayQueues() async {
    if (!ready || _disposed || _relayDraining) return;
    _relayDraining = true;
    try {
      final now = DateTime.now().toUtc();
      if (_lastRelayCleanup == null ||
          now.difference(_lastRelayCleanup!) >= const Duration(hours: 6)) {
        await database.cleanupExpiredRelayItems();
        _lastRelayCleanup = now;
      }
      if (_resetRelayBackoff) {
        _resetRelayBackoff = false;
        await database.resetRelayBackoff();
      }
      final neighbors = {
        for (final device in nearbyService.connectedDevices.toList())
          if (_endpointPeers[device.endpointId] != null)
            device.endpointId: _endpointPeers[device.endpointId]!,
      };
      // ACKs go only to their prescribed next hop.
      for (final entry in neighbors.entries) {
        final acks = await database.pendingRelayAcks(entry.value);
        for (final item in acks) {
          if (_disposed) return;
          final seq = item['seq'] as int;
          try {
            await nearbyService.sendMessage(
              entry.key,
              item['payload'] as String,
            );
            await database.deleteRelayAckItem(seq);
          } catch (e) {
            await database.markRelayAckAttempt(seq, item['attempts'] as int);
            error = 'Relay ACK retry failed: $e';
            _notify();
          }
        }
      }
      final jobs = await database.retryableRelayItems();
      for (final job in jobs) {
        if (_disposed) return;
        final payload = job['payload'] as String;
        final relay = RelayPacket.fromMap(
          jsonDecode(payload) as Map<String, dynamic>,
        );
        if (relay.message.type == MessageType.sos &&
            !_mayForwardSos(
              relay.message.senderId,
              SosAlert.fromJson(relay.message.text),
            )) {
          await database.deleteRelayItem(job['seq'] as int);
          continue;
        }
        final eligible = neighbors.entries
            .where((e) => !relay.path.contains(e.value))
            .toList();
        final direct = eligible
            .where((e) => e.value == relay.message.receiverId)
            .toList();
        final mediaRoute = relay.message.type == MessageType.media
            ? relayPathForPeer(relay.message.receiverId)
            : null;
        final targets = relay.message.type == MessageType.media
            ? mediaRoute != null && mediaRoute.length > 1
                  ? eligible.where((e) => e.value == mediaRoute[1]).toList()
                  : direct
            : direct.isEmpty
            ? eligible
            : direct;
        if (targets.isEmpty) continue; // Keep the job even without a next hop.
        var sentAny = false;
        for (final target in targets) {
          try {
            if (relay.message.type == MessageType.media) {
              final sent = await mediaService?.forwardRelayMedia(
                target.key,
                relay,
              );
              if (sent != true) continue;
              sentAny = true;
            } else {
              await nearbyService.sendMessage(target.key, payload);
              sentAny = true;
            }
          } catch (e) {
            error = 'Relay failed (queued): $e';
            _notify();
          }
        }
        // Keep successful native sends too, until a destination ACK is proven.
        if (sentAny || relay.message.type != MessageType.media) {
          await database.markRelayAttempt(
            job['seq'] as int,
            job['attempts'] as int,
          );
        }
      }
    } finally {
      _relayDraining = false;
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
