import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/onboarding_screen.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/screens/login_screen.dart';

void main() {
  testWidgets('three introduction pages lead to login on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: RescueTheme.light, home: const OnboardingScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('เชื่อมต่อผู้คน ในทุกสถานการณ์'), findsOneWidget);
    expect(tester.takeException(), isNull);
    var button = find.widgetWithText(FilledButton, 'เริ่มใช้งาน').hitTestable();
    // The minimum-height layout scrolls vertically on compact devices.
    await tester.drag(find.byType(PageView), const Offset(0, -250));
    await tester.pumpAndSettle();
    button = find.widgetWithText(FilledButton, 'เริ่มใช้งาน').hitTestable();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('แม้ไม่มีสัญญาณ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(PageView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('ส่งความช่วยเหลือ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(PageView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'เริ่มใช้งาน').hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping and skip open login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: RescueTheme.light, home: const OnboardingScreen()),
    );
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ข้าม').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
