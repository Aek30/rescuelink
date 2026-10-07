import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/login_screen.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'account_auth_test.dart' show FakeBackend, MemoryVault;

void main() {
  testWidgets('confirmation dialog waits before switching to login', (
    tester,
  ) async {
    final backend = FakeBackend()..result = null;
    final auth = AuthService(
      storage: AccountStorage(),
      vault: MemoryVault(),
      backend: backend,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
    await tester.tap(find.text('สมัครใช้งาน'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('signup-name')), 'Member');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Test@password1');
    await tester.enterText(
      find.byKey(const ValueKey('signup-confirmation')),
      'Test@password1',
    );
    final submit = find.widgetWithText(FilledButton, 'สมัครใช้งาน');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('member@example.com'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('signup-name')), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('ไปหน้าเข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'member@example.com',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      isEmpty,
    );
    expect(backend.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'signup requires name and matching passwords and login stays simple',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.tap(find.text('สมัครใช้งาน'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(4));
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'sample-password',
      );
      await tester.enterText(
        find.byKey(const ValueKey('signup-confirmation')),
        'different-password',
      );
      final submit = find.widgetWithText(FilledButton, 'สมัครใช้งาน');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('กรุณากรอกชื่อที่แสดง'), findsOneWidget);
      expect(find.text('รหัสผ่านทั้งสองช่องไม่ตรงกัน'), findsOneWidget);
      final loginTab = find.text('เข้าสู่ระบบ');
      await tester.ensureVisible(loginTab);
      await tester.tap(loginTab);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);
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
