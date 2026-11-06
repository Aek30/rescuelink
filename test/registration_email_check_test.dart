import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/register_screen.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'account_auth_test.dart' show FakeBackend, MemoryVault;

class EmailBackend extends FakeBackend implements RegistrationEmailChecker {
  final checked = <String>[];
  bool registered = true;
  bool fail = false;
  Completer<bool>? pending;
  @override
  Future<bool> emailRegistered(String email) async {
    checked.add(email);
    if (fail) throw StateError('Offline');
    return pending == null ? registered : await pending!.future;
  }
}

void main() {
  for (final exists in [true, false]) {
    testWidgets(
      'checks email before collecting personal data: exists=$exists',
      (tester) async {
        final backend = EmailBackend()..registered = exists;
        final auth = AuthService(
          storage: AccountStorage(),
          vault: MemoryVault(),
          backend: backend,
        );
        await tester.pumpWidget(MaterialApp(home: RegisterScreen(auth: auth)));
        await tester.enterText(
          find.byKey(const ValueKey('registration-email')),
          ' Member@Example.com ',
        );
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
        expect(backend.checked, ['member@example.com']);
        expect(backend.calls, 0);
        expect(backend.resendCalls, 0);
        expect(find.byType(EmailVerificationDialog), findsNothing);
        expect(
          find.text('อีเมลนี้มีบัญชีอยู่แล้ว'),
          exists ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('เข้าสู่ระบบด้วยบัญชีเดิม'),
          exists ? findsOneWidget : findsNothing,
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Test@password1',
        );
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'Test@password1',
        );
        final next = find.widgetWithText(FilledButton, 'ถัดไป  →');
        await tester.ensureVisible(next);
        if (exists) {
          expect(tester.widget<FilledButton>(next).onPressed, isNull);
        } else {
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(find.text('ชื่อ-นามสกุล *'), findsOneWidget);
          expect(backend.checked, hasLength(1));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
      },
    );
  }

  testWidgets('ignores old email results and allows retry after failure', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final backend = EmailBackend()..pending = pending;
    final auth = AuthService(
      storage: AccountStorage(),
      vault: MemoryVault(),
      backend: backend,
    );
    await tester.pumpWidget(MaterialApp(home: RegisterScreen(auth: auth)));
    final email = find.byKey(const ValueKey('registration-email'));
    await tester.enterText(email, 'first@example.com');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.enterText(email, 'second@example.com');
    pending.complete(true);
    backend.pending = null;
    backend.fail = true;
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('อีเมลนี้มีบัญชีอยู่แล้ว'), findsNothing);
    expect(find.text('ยังตรวจสอบอีเมลไม่ได้ กรุณาลองอีกครั้ง'), findsOneWidget);
    backend.fail = false;
    backend.registered = false;
    await tester.enterText(find.byType(TextFormField).at(1), 'Test@password1');
    await tester.enterText(find.byType(TextFormField).at(2), 'Test@password1');
    final next = find.widgetWithText(FilledButton, 'ถัดไป  →');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('ชื่อ-นามสกุล *'), findsOneWidget);
    expect(backend.calls, 0);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
