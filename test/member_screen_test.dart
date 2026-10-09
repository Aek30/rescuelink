import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/member_screen.dart';
import 'package:rescuelink/services/member_service.dart';

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
  testWidgets('reads profile, blocks empty names and persists edited name', (
    tester,
  ) async {
    final repository = FakeMembers();
    await tester.pumpWidget(
      MaterialApp(home: MemberScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('อีเมล: a@example.com'), findsOneWidget);
    expect(find.text('User UID: owner-A'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('บันทึกข้อมูลสมาชิก'));
    await tester.pumpAndSettle();
    expect(repository.updates, 0);
    expect(find.text('กรุณาระบุชื่อสมาชิก'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' ชื่อใหม่ ');
    await tester.tap(find.text('บันทึกข้อมูลสมาชิก'));
    await tester.pumpAndSettle();
    expect(repository.profile.name, 'ชื่อใหม่');
    expect(find.text('บันทึกข้อมูลสมาชิกบน Supabase แล้ว'), findsOneWidget);
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
    expect(find.text('รหัสผ่านไม่ถูกต้อง บัญชียังไม่ถูกลบ'), findsOneWidget);
  });
}
