import 'sos_alert.dart';

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
  String get title => sos == null ? 'ข้อความจาก $name' : 'SOS จาก $name';
  Map<String, String> toMap() => {
    'id': id,
    'peerId': peerId,
    'name': name,
    'body': body,
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
