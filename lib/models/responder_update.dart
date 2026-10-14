/// A responder's own status report sent through chat, not an assignment receipt.
class ResponderUpdate {
  const ResponderUpdate(this.incidentId, this.stage);
  final String incidentId, stage;

  static const _messages = {
    'pending':
        'พร้อมเข้าไปช่วยเหลือ • รอการยืนยันจากคุณ\n'
        'กรุณาตอบกลับเพื่อนัดหมายและยืนยันรายละเอียด',
    'helping':
        'กำลังให้ความช่วยเหลือ\n'
        'หากมีข้อมูลเพิ่มเติม กรุณาแจ้งในแชตนี้',
    'completed':
        'แจ้งว่าการช่วยเหลือเสร็จสิ้นแล้ว\n'
        'หากยังต้องการความช่วยเหลือ กรุณาตอบกลับในแชตนี้',
  };
  static const _legacyLabels = {
    'pending': 'ผู้ช่วยเหลือขอรับเคส — รอการยืนยันจากผู้แจ้ง',
    'helping': 'ผู้ช่วยเหลือแจ้งว่ากำลังช่วยเหลือ',
    'completed': 'ผู้ช่วยเหลือแจ้งว่าเสร็จสิ้น',
  };
  String get marker => '[SOS $incidentId / $stage]';
  String get displayText => _messages[stage]!;
  String toChatText() => '$marker\n$displayText';

  static ResponderUpdate? parse(String raw) {
    final text = raw.replaceAll('\r\n', '\n');
    final match = RegExp(
      r'^\[SOS ([^\]\r\n]+) / (pending|helping|completed)\]\n',
    ).firstMatch(text);
    if (match == null) return null;
    final stage = match.group(2)!;
    final content = text.substring(match.end);
    final legacy =
        '${_legacyLabels[stage]}\n'
        'เป็นการแจ้งผ่านแชต ไม่ใช่การยืนยันการจัดสรรเคส กรุณาติดต่อกลับ';
    if (content != _messages[stage] && content != legacy) return null;
    return ResponderUpdate(match.group(1)!, stage);
  }

  static String readableText(String raw) => parse(raw)?.displayText ?? raw;
}
