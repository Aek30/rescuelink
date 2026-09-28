import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/login_screen.dart';

void main() {
  testWidgets('login fits a small screen and validates empty credentials', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(tester.takeException(), isNull);
    final submit = find.widgetWithText(FilledButton, 'เข้าสู่ระบบ');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
    expect(find.text('กรุณากรอกอีเมลหรือเบอร์โทรศัพท์'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password visibility and account availability are explicit', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.enterText(
      find.byType(TextFormField).first,
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'sample-password');
    await tester.tap(find.byTooltip('แสดงรหัสผ่าน'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    final submit = find.widgetWithText(FilledButton, 'เข้าสู่ระบบ');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('ระบบบัญชียังไม่พร้อมใช้งาน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
