import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/forgot_password_screen.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'account_auth_test.dart' show FakeBackend, MemoryVault;

void main() {
  testWidgets('forgot password screen validates email and moves to otp step', (
    tester,
  ) async {
    final backend = FakeBackend();
    final auth = AuthService(
      storage: AccountStorage(),
      vault: MemoryVault(),
      backend: backend,
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ForgotPasswordScreen(auth: auth)),
    );
    expect(find.text('ลืมรหัสผ่าน'), findsOneWidget);
    expect(find.text('ส่งรหัสยืนยัน'), findsOneWidget);

    // Empty email submission
    await tester.tap(find.text('ส่งรหัสยืนยัน'));
    await tester.pumpAndSettle();
    expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);

    // Enter valid email and submit
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.tap(find.text('ส่งรหัสยืนยัน'));
    await tester.pumpAndSettle();

    // Verify step 2 appears
    expect(find.textContaining('รหัสยืนยัน'), findsWidgets);
    expect(find.text('รหัสผ่านใหม่'), findsOneWidget);
    expect(find.text('ยืนยันรหัสผ่านใหม่'), findsOneWidget);
    expect(find.text('บันทึกรหัสผ่านใหม่'), findsOneWidget);
  });
}
