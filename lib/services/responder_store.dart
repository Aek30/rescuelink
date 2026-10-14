import 'dart:convert';
import '../models/sos_alert.dart';
import '../models/responder_update.dart';
import 'message_service.dart';

/// Local work notes, never an authoritative assignment or a delivery ACK.
class ResponderStore {
  ResponderStore(this.service);
  final MessageService service;
  String key(String owner, String incident) => 'responder:$owner:$incident';
  Future<Map<String, dynamic>?> read(String owner, String incident) async {
    final value = await service.database.getSetting(key(owner, incident));
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<void> update(String owner, SosAlert alert, String stage) async {
    if (!const ['pending', 'helping', 'completed'].contains(stage)) {
      throw ArgumentError('Invalid case stage');
    }
    if (!service.ready ||
        !service.rescueMode ||
        owner == service.myId ||
        !alert.isActiveAt(DateTime.now().toUtc())) {
      throw StateError('ต้องพร้อมรับเหตุ และเหตุยังเปิดอยู่');
    }
    final saved = await service.database.getRemoteSos();
    SosAlert? latest = saved[owner]?[alert.incidentId];
    for (final message in service.receivedSos.where(
      (m) => m.senderId == owner,
    )) {
      final candidate = SosAlert.fromJson(message.text);
      if (candidate.incidentId == alert.incidentId &&
          (latest == null || latest.revision < candidate.revision)) {
        latest = candidate;
      }
    }
    if (latest != null && !latest.isActiveAt(DateTime.now().toUtc())) {
      throw StateError('เหตุถูกยกเลิกหรือหมดอายุแล้ว');
    }
    final previous = await read(owner, alert.incidentId);
    if (previous == null && stage != 'pending') {
      throw StateError('กรุณารับเคสก่อน');
    }
    if (previous != null && stage == 'pending') return;
    if (previous?['stage'] == 'completed') {
      throw StateError('บันทึกเสร็จสิ้นแล้ว');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await service.database.setSetting(
      key(owner, alert.incidentId),
      jsonEncode({
        'responderId': service.myId,
        'incidentId': alert.incidentId,
        'ownerId': owner,
        'acceptedAt': previous?['acceptedAt'] ?? now,
        'updatedAt': now,
        'stage': stage,
      }),
    );
  }

  /// Human-readable update through the existing durable chat queue. A chat ACK
  /// proves receipt only, never exclusive assignment or reporter consent.
  Future<void> notifyReporter(String owner, String incident) async {
    final record = await read(owner, incident);
    if (record == null) throw StateError('ยังไม่มีบันทึกการรับเคส');
    final marker = '[SOS $incident / ${record['stage']}]';
    if (service.messages.any(
      (m) =>
          m.senderId == service.myId &&
          m.receiverId == owner &&
          m.text.startsWith(marker),
    )) {
      return;
    }
    await service.sendTextMessage(
      receiverId: owner,
      text: ResponderUpdate(incident, record['stage'] as String).toChatText(),
    );
  }
}
