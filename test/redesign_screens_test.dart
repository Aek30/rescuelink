import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/member_screen.dart';
import 'package:rescuelink/screens/sync_screen.dart';
import 'package:rescuelink/services/member_service.dart';
import 'package:rescuelink/services/sos_sync_service.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'package:rescuelink/theme/rescue_theme.dart';

class StubMemberRepo implements MemberRepository {
  StubMemberRepo(this.profile);
  MemberProfile? profile;

  @override
  Future<MemberProfile> read() async {
    if (profile == null) throw StateError('ไม่มีข้อมูลสมาชิก');
    return profile!;
  }

  @override
  Future<MemberProfile> updateName(String name) async {
    return profile = MemberProfile(
      id: profile?.id ?? 'u-1',
      email: profile?.email ?? 'test@example.com',
      name: name,
    );
  }

  @override
  Future<void> deleteAccount(String password) async {}
}

class FakeSosStore implements SosStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<SosRecord>> list({bool includeDeleted = false}) async => [];

  @override
  Future<List<Map<String, Object?>>> queue() async => [];
}

void main() {
  group('MemberScreen redesign', () {
    testWidgets('renders properly with Guest (profile null)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = StubMemberRepo(null);
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          darkTheme: RescueTheme.dark,
          home: MemberScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ข้อมูลสมาชิก'), findsOneWidget); // AppBar
      expect(find.text('จัดการบัญชี'), findsOneWidget);
      expect(find.text('ออกจากระบบ'), findsOneWidget);
      expect(find.text('ลบบัญชีถาวร'), findsNothing); // Hidden for Guest
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders extremely long name without overflow and with ellipsis', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const veryLongName =
          'นายทดสอบชื่อและนามสกุลยาวมากๆเพื่อตรวจสอบการตัดบรรทัดและการแสดงผลแบบEllipsisที่ไม่ล้นหน้าจอ';
      final repo = StubMemberRepo(
        const MemberProfile(
          id: 'very-long-id-1234567890-abcdef',
          email: 'very_long_email_address_for_testing_overflow@example.com',
          name: veryLongName,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          home: MemberScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final headerNameFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == veryLongName && w.maxLines == 1,
      );
      expect(headerNameFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supports dark theme seamlessly', (tester) async {
      const name = 'สมชาย ผู้กล้าหาญ';
      final repo = StubMemberRepo(
        const MemberProfile(
          id: 'id-dark',
          email: 'dark@example.com',
          name: name,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.dark,
          themeMode: ThemeMode.dark,
          home: MemberScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final nameFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == name && w.maxLines == 1,
      );
      expect(nameFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SyncScreen redesign', () {
    test('syncAgo returns appropriate durations', () {
      expect(syncAgo(null), 'ยังไม่เคยซิงก์');
      expect(syncAgo(DateTime.now()), 'ซิงก์เมื่อสักครู่');
      expect(
        syncAgo(DateTime.now().subtract(const Duration(minutes: 5))),
        'ซิงก์ล่าสุด 5 นาทีที่แล้ว',
      );
      expect(
        syncAgo(DateTime.now().subtract(const Duration(hours: 3))),
        'ซิงก์ล่าสุด 3 ชั่วโมงที่แล้ว',
      );
      expect(
        syncAgo(DateTime.now().subtract(const Duration(days: 2))),
        'ซิงก์ล่าสุด 2 วันที่แล้ว',
      );
    });

    testWidgets('renders empty sync queue in light and dark mode', (
      tester,
    ) async {
      final store = FakeSosStore();
      final sync = SosSyncService(store, null);

      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          home: SyncScreen(service: sync),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('การซิงก์ข้อมูล'), findsOneWidget);
      expect(find.text('ทุกอย่างซิงก์แล้ว'), findsOneWidget);
      expect(find.text('ไม่มีรายการค้างอยู่'), findsOneWidget);
      expect(find.text('บันทึกในเครื่อง'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Dark mode check
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.dark,
          home: SyncScreen(service: sync),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
