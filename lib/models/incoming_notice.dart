import 'sos_alert.dart';
import 'responder_update.dart';

class IncomingNotice {
  const IncomingNotice({
    required this.id,
    required this.peerId,
    required this.name,
    required this.body,
    this.sos,
  });
  final String id, peerId, name, body;
  final SosAlert? sos;
  String get notificationId =>
      sos == null ? 'chat:$peerId' : 'sos:${sos!.incidentId}';
  String? get _responderStage => ResponderUpdate.parse(body)?.stage;

  String get title => sos != null
      ? 'SOS จาก $name'
      : _responderStage != null
      ? 'อัปเดตการช่วยเหลือจาก $name'
      : 'ข้อความจาก $name';

  /// Compact display text; keep the complete chat message for opening/review.
  String get preview {
    if (sos != null) {
      return '${sos!.categoriesLabel} • ${sos!.people} คน • '
          '${sos!.location == null ? 'ไม่แนบพิกัด' : 'มีพิกัด'}';
    }
    final summary = switch (_responderStage) {
      'pending' => 'ขอรับเคส • รอคุณยืนยันผ่านแชต',
      'helping' => 'แจ้งว่ากำลังช่วยเหลือ • เปิดแชตเพื่อตรวจสอบ',
      'completed' => 'แจ้งว่าเสร็จสิ้น • เปิดแชตเพื่อตรวจสอบ',
      _ => body.replaceAll(RegExp(r'\s+'), ' ').trim(),
    };
    final characters = summary.runes.toList();
    return characters.length <= 100
        ? summary
        : '${String.fromCharCodes(characters.take(100))}…';
  }

  Map<String, String> toMap() => {
    'id': id,
    'peerId': peerId,
    'name': name,
    'body': body,
    'preview': preview,
    'title': title,
    if (sos != null) 'sos': sos!.toJson(),
  };
  factory IncomingNotice.fromMap(Map<dynamic, dynamic> map) => IncomingNotice(
    id: map['id'] as String,
    peerId: map['peerId'] as String,
    name: map['name'] as String,
    body: map['body'] as String,
    sos: map['sos'] == null ? null : SosAlert.fromJson(map['sos'] as String),
  );
}
