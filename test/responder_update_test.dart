import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/responder_update.dart';
import 'package:rescuelink/models/incoming_notice.dart';

void main() {
  test(
    'legacy updates display readable text without exposing incident IDs',
    () {
      const old =
          '[SOS case-123 / completed]\n'
          'ผู้ช่วยเหลือแจ้งว่าเสร็จสิ้น\n'
          'เป็นการแจ้งผ่านแชต ไม่ใช่การยืนยันการจัดสรรเคส กรุณาติดต่อกลับ';
      final readable = ResponderUpdate.readableText(old);
      expect(readable, contains('หากยังต้องการความช่วยเหลือ'));
      expect(readable, isNot(contains('case-123')));
      expect(readable, isNot(contains('completed')));
      expect(
        ResponderUpdate.parse(old.replaceAll('\n', '\r\n'))?.stage,
        'completed',
      );
    },
  );

  test(
    'new status updates retain their incident identity and compact notices',
    () {
      for (final stage in ['pending', 'helping', 'completed']) {
        final update = ResponderUpdate('case-123', stage);
        final raw = update.toChatText();
        final parsed = ResponderUpdate.parse(raw)!;
        expect(parsed.incidentId, 'case-123');
        expect(parsed.stage, stage);
        expect(ResponderUpdate.readableText(raw), update.displayText);
        final notice = IncomingNotice(
          id: 'm',
          peerId: 'p',
          name: 'B',
          body: raw,
        );
        expect(notice.title, 'อัปเดตการช่วยเหลือจาก B');
        expect(notice.preview, isNot(contains('case-123')));
        expect(notice.toMap()['body'], raw);
      }
    },
  );

  test('ordinary chat text and custom content are preserved', () {
    for (final raw in [
      'ช่วยด้วย',
      '[SOS case-123 / completed]\nยังต้องการความช่วยเหลือ',
    ]) {
      expect(ResponderUpdate.readableText(raw), raw);
      expect(ResponderUpdate.parse(raw), isNull);
    }
  });
}
