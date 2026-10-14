import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/incoming_notice.dart';

void main() {
  IncomingNotice notice(String body) =>
      IncomingNotice(id: 'message', peerId: 'peer', name: 'B', body: body);

  test(
    'responder preview summarizes the status while preserving the message',
    () {
      const original =
          '[SOS 302d7f97-1c66-4b20-8832-5d593f7e31f5 / completed]\n'
          'ผู้ช่วยเหลือแจ้งว่าเสร็จสิ้น\n'
          'เป็นการแจ้งผ่านแชต ไม่ใช่การยืนยันการจัดสรรเคส กรุณาติดต่อกลับ';
      final value = notice(original);
      expect(value.title, 'อัปเดตการช่วยเหลือจาก B');
      expect(value.preview, 'แจ้งว่าเสร็จสิ้น • เปิดแชตเพื่อตรวจสอบ');
      expect(value.toMap()['body'], original);
      expect(value.toMap()['preview'], value.preview);
      expect(IncomingNotice.fromMap(value.toMap()).body, original);
    },
  );

  test('a user message with an SOS marker is not mistaken for a status', () {
    final value = notice('[SOS incident / completed]\nยังต้องการความช่วยเหลือ');
    expect(value.title, 'ข้อความจาก B');
    expect(value.preview, contains('ยังต้องการความช่วยเหลือ'));
  });

  test(
    'long previews normalize whitespace and preserve unicode characters',
    () {
      final value = notice('  สวัสดี\n${List.filled(110, '😀').join()}  ');
      expect(value.preview, startsWith('สวัสดี '));
      expect(value.preview, endsWith('…'));
      expect(value.preview.runes.length, 101);
      expect(value.preview, isNot(contains('\n')));
      expect(value.preview, isNot(contains('\uFFFD')));
      expect(value.body.runes.length, greaterThan(101));
    },
  );
}
