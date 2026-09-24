import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import 'local_database_service.dart';
import 'nearby_service.dart';

class MessageService extends ChangeNotifier {
  MessageService({required this.nearbyService, LocalDatabaseService? database})
    : database = database ?? LocalDatabaseService.instance;
  final NearbyService nearbyService;
  final LocalDatabaseService database;
  final _uuid = const Uuid();
  final Map<String, String> _endpointPeers = {};
  Set<String> _connectedEndpoints = {};
  Map<String, String> peers = {};
  List<MessageModel> messages = [];
  String? myId, error;
  SosAlert? mySos;
  bool _publishingSos = false;
  bool rescueMode = false;
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
    await database.setSetting('rescueMode', '$value');
    rescueMode = value;
    _notify();
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
    if (recipients.isEmpty || !recipients.every(peers.containsKey)) {
      throw ArgumentError('กรุณาเลือกผู้รับที่เคยเชื่อมต่อ');
    }
    // Keep recipients fixed for an incident so cancellation reaches everyone.
    if (mySos?.active == true && !setEquals(recipients, _sosRecipients)) {
      throw ArgumentError('ยกเลิก SOS เดิมก่อนเปลี่ยนผู้รับ');
    }
    _publishingSos = true;
    try {
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
      await _refresh();
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
    messages = await database.getMessages();
    peers = await database.getPeers();
    _notify();
  }

  void _connectionChanged() {
    final connected = nearbyService.connectedDevices
        .map((d) => d.endpointId)
        .toSet();
    if (setEquals(connected, _connectedEndpoints)) return;
    _connectedEndpoints = connected;
    _endpointPeers.removeWhere((id, _) => !connected.contains(id));
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
    if (utf8.encode(message.toJson()).length > 32768) {
      throw ArgumentError('Message exceeds 32 KB including envelope');
    }
    await database.insertMessage(message);
    await _refresh();
    await retry();
  }

  Future<void> retry() async {
    if (!ready || _disposed || _ticking) return;
    _ticking = true;
    try {
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
          final history = await database.getMessages();
          final latestSos = <String, int>{};
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
            if (message.senderId != myId ||
                message.receiverId != peer ||
                message.status.index >= MessageStatus.delivered.index) {
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
      final packet = MessageModel.fromJson(rawPayload);
      if (packet.senderId == myId) return;
      if (packet.type == MessageType.deviceInfo) {
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
          await database.insertMessage(
            packet.copyWith(status: MessageStatus.delivered),
          );
          await _refresh();
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
            await database.updateMessageStatus(
              packet.ackFor!,
              MessageStatus.delivered,
            );
            await _refresh();
          }
        case MessageType.deviceInfo:
          break;
      }
    } catch (e) {
      error = 'Receive failed: $e';
      _notify();
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
