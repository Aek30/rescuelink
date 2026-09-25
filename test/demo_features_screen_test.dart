import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/demo_features_screen.dart';

void main() {
  testWidgets(
    'demo sync requires online account and supports failure recovery',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DemoFeaturesScreen()));
      final sync = find.widgetWithText(
        OutlinedButton,
        'ซิงก์ตัวอย่าง / ลองใหม่',
      );
      expect(tester.widget<OutlinedButton>(sync).onPressed, isNull);
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(sync).onPressed, isNull);
      await tester.tap(find.text('ทดลองเข้าสู่ระบบ / สมัครบัญชี'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.ensureVisible(sync);
      await tester.tap(sync);
      await tester.pumpAndSettle();
      expect(find.textContaining('จำลองข้อผิดพลาด •'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.ensureVisible(sync);
      await tester.tap(sync);
      await tester.pumpAndSettle();
      expect(find.textContaining('ซิงก์ตัวอย่างครบ 3 รายการ'), findsOneWidget);
    },
  );

  testWidgets('media demo queues samples and discards them when closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DemoFeaturesScreen(media: true)),
    );
    await tester.tap(find.text('แนบรูปตัวอย่าง'));
    await tester.pumpAndSettle();
    expect(find.text('ค้างส่ง (จำลองเท่านั้น)'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('ส่งแล้ว (จำลองเท่านั้น)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(home: DemoFeaturesScreen(media: true)),
    );
    expect(find.text('ยังไม่มีสื่อแนบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
