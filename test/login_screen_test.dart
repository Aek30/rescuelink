import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/login_screen.dart';
import 'package:rescuelink/screens/register_screen.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'account_auth_test.dart' show FakeBackend, MemoryVault;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (find.byType(EmailVerificationDialog).evaluate().isEmpty) {
    await tester.pumpAndSettle();
  }
}

Future<void> fillRegistration(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('register-button')));
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'member@example.com',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'Test@password1');
  await tester.enterText(find.byType(TextFormField).at(2), 'Test@password1');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'ถัดไป  →'));
  await tester.enterText(find.byType(TextFormField).at(0), 'Test Member');
  await tester.enterText(find.byType(TextFormField).at(1), 'Member');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'ถัดไป  →'));
}

void main() {
  testWidgets(
    'signup collects all steps and resends without repeating signup',
    (tester) async {
      final backend = FakeBackend()..result = null;
      final auth = AuthService(
        storage: AccountStorage(),
        vault: MemoryVault(),
        backend: backend,
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
      await fillRegistration(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Asthma');
      await tapVisible(tester, find.byType(Checkbox).at(0));
      await tapVisible(tester, find.byType(Checkbox).at(1));
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'สมัครสมาชิก'),
      );
      expect(backend.receivedMetadata?['medical_conditions'], 'Asthma');
      expect(backend.receivedMetadata?['full_name'], 'Test Member');
      expect(find.byType(EmailVerificationDialog), findsOneWidget);
      expect(find.text('m****r@example.com'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(EmailVerificationDialog), findsOneWidget);
      await tester.tap(find.text('ส่งอีเมลยืนยันอีกครั้ง'));
      await tester.pump();
      expect(backend.resendCalls, 1);
      expect(backend.calls, 1);
      expect(find.textContaining('ส่งอีเมลยืนยันแล้ว'), findsOneWidget);
      await tester.tap(find.text('กลับไปหน้าเข้าสู่ระบบ'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsNothing);
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
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('skip removes health even when consent was checked', (
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
    await fillRegistration(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Private');
    await tapVisible(tester, find.byType(Checkbox).at(0));
    await tapVisible(tester, find.byType(Checkbox).at(1));
    await tapVisible(tester, find.text('ข้ามข้อมูลสุขภาพและสมัครทันที'));
    expect(
      backend.receivedMetadata!.containsKey('medical_conditions'),
      isFalse,
    );
    expect(backend.receivedMetadata!.containsKey('health_consent'), isFalse);
    await tester.tap(find.text('กลับไปหน้าเข้าสู่ระบบ'));
    await tester.pumpAndSettle();
  });

  testWidgets('signup validates password match and required names', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    expect(find.byType(TextFormField), findsNWidgets(3));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Test@password1');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Different@password1',
    );
    await tapVisible(tester, find.widgetWithText(FilledButton, 'ถัดไป  →'));
    expect(find.text('รหัสผ่านทั้งสองช่องไม่ตรงกัน'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), 'Test@password1');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'ถัดไป  →'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'ถัดไป  →'));
    expect(find.text('กรุณากรอกชื่อ-นามสกุล'), findsOneWidget);
    expect(find.text('กรุณากรอกชื่อที่แสดง'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login has no guest and fits small screens', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.textContaining('Guest'), findsNothing);
    expect(find.textContaining('ผู้เยี่ยมชม'), findsNothing);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
    expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resend failure never shows success and masks short emails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationDialog(
          email: 'a@example.com',
          onResend: () async => throw StateError('กรุณารอ 60 วินาที'),
        ),
      ),
    );
    await tester.tap(find.text('ส่งอีเมลยืนยันอีกครั้ง'));
    await tester.pump();
    expect(find.textContaining('ส่งอีเมลยืนยันแล้ว'), findsNothing);
    expect(find.text('กรุณารอ 60 วินาที'), findsOneWidget);
    expect(find.text('*@example.com'), findsOneWidget);
  });

  testWidgets('password visibility and unavailable backend are explicit', (
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
    await tapVisible(tester, find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    expect(find.text('ระบบบัญชียังไม่พร้อมใช้งาน'), findsOneWidget);
  });
}
