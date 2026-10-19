import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/member_screen.dart';
import 'package:rescuelink/services/member_service.dart';
import 'package:rescuelink/theme/rescue_theme.dart';

class FakeMembers implements MemberRepository {
  MemberProfile profile = const MemberProfile(
    id: 'owner-A',
    email: 'a@example.com',
    name: 'ชื่อเดิม',
  );
  int updates = 0, deletions = 0;
  bool rejectDelete = false;
  @override
  Future<MemberProfile> read() async => profile;
  @override
  Future<MemberProfile> updateName(String name) async {
    updates++;
    return profile = MemberProfile(
      id: profile.id,
      email: profile.email,
      name: name.trim(),
    );
  }

  @override
  Future<void> deleteAccount(String password) async {
    if (password.isEmpty || rejectDelete) {
      throw StateError('รหัสผ่านไม่ถูกต้อง บัญชียังไม่ถูกลบ');
    }
    deletions++;
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('name sheet fits small screens with keyboard dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeMembers();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? RescueTheme.dark : RescueTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: MemberScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byTooltip('แก้ไขชื่อสมาชิก'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField), 'New name');
      await tester.ensureVisible(find.text('บันทึกการเปลี่ยนแปลง'));
      await tester.tap(find.text('บันทึกการเปลี่ยนแปลง'));
      await tester.pumpAndSettle();
      expect(repository.updates, 1);
      expect(repository.profile.name, 'New name');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pending member status is not reported as synced and offers details',
    (tester) async {
      final repository = FakeMembers()
        ..profile = const MemberProfile(
          id: 'owner-A',
          email: 'a@example.com',
          name: 'Local name',
          pending: true,
          offline: true,
          syncError: 'Offline test details',
        );
      await tester.pumpWidget(
        MaterialApp(home: MemberScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('บันทึกในเครื่องแล้ว · รอซิงก์'), findsOneWidget);
      expect(find.text('ซิงก์ข้อมูลสมาชิกแล้ว'), findsNothing);
      expect(find.text('Offline test details'), findsNothing);
      await tester.tap(find.text('รายละเอียด'));
      await tester.pumpAndSettle();
      expect(find.text('Offline test details'), findsOneWidget);
    },
  );

  testWidgets('reads profile, blocks empty names and persists edited name', (
    tester,
  ) async {
    final repository = FakeMembers();
    await tester.pumpWidget(
      MaterialApp(home: MemberScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.byTooltip('แก้ไขชื่อสมาชิก'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('บันทึกการเปลี่ยนแปลง'));
    await tester.pumpAndSettle();
    expect(repository.updates, 0);
    expect(find.text('กรุณาระบุชื่อสมาชิก'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' ชื่อใหม่ ');
    await tester.tap(find.text('บันทึกการเปลี่ยนแปลง'));
    await tester.pumpAndSettle();
    expect(repository.profile.name, 'ชื่อใหม่');
    expect(find.text('ซิงก์ข้อมูลสมาชิกแล้ว'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('ชื่อใหม่'), findsOneWidget);
  });

  testWidgets('delete cancellation and incorrect password preserve account', (
    tester,
  ) async {
    final repository = FakeMembers()..rejectDelete = true;
    await tester.pumpWidget(
      MaterialApp(home: MemberScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ลบบัญชีถาวร'));
    await tester.tap(find.text('ลบบัญชีถาวร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(repository.deletions, 0);
    await tester.tap(find.text('ลบบัญชีถาวร'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'wrong-password',
    );
    await tester.tap(find.text('ยืนยันลบบัญชี'));
    await tester.pumpAndSettle();
    expect(repository.deletions, 0);
    await tester.tap(find.text('รายละเอียด'));
    await tester.pumpAndSettle();
    expect(find.text('รหัสผ่านไม่ถูกต้อง บัญชียังไม่ถูกลบ'), findsOneWidget);
  });
}
