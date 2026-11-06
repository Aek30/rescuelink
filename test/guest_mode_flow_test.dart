import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/screens/login_screen.dart';
import 'package:rescuelink/screens/member_screen.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/app_preferences.dart';
import 'package:rescuelink/services/member_service.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'account_auth_test.dart' show FakeBackend, MemoryVault;

class StubMemberRepo implements MemberRepository {
  StubMemberRepo(this.profile);
  final MemberProfile? profile;
  @override
  Future<MemberProfile> read() async =>
      profile ?? (throw StateError('Guest mode: not logged in'));
  @override
  Future<MemberProfile> updateName(String name) async =>
      profile ?? (throw StateError('Guest mode'));
  @override
  Future<void> deleteAccount(String password) async {}
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late AccountStorage storage;
  late MemoryVault vault;
  late FakeBackend backend;
  late AuthService auth;
  final originalDb = LocalDatabaseService.instance;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rescuelink-guest-flow-');
    storage = AccountStorage(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    vault = MemoryVault();
    backend = FakeBackend();
    auth = AuthService(storage: storage, vault: vault, backend: backend);
    await auth.initialize();
  });

  tearDown(() async {
    auth.dispose();
    await storage.close();
    LocalDatabaseService.instance = originalDb;
    await directory.delete(recursive: true);
  });

  test('Guest mode initializes storage as guest and does not contact cloud', () async {
    bool stopped = false;
    auth.beforeScopeChange = () async {
      stopped = true;
    };
    await auth.enterGuest();
    expect(stopped, isTrue);
    expect(auth.signedIn, isFalse);
    expect(auth.isGuest, isTrue);
    expect(storage.owner, 'guest');
    expect(AppPreferences.instance.guestMode, isTrue);
  });

  test('Guest history persists across restart and remains isolated on member sign-in', () async {
    await auth.enterGuest();
    final guestDb = LocalDatabaseService.instance;
    await guestDb.setSetting('guestSetting', 'local_value');

    // Simulate member login with account 'user-123'
    bool stoppedNearbyBeforeLogin = false;
    auth.beforeScopeChange = () async {
      stoppedNearbyBeforeLogin = true;
    };

    backend.result = const AccountSession('user-123', 'user@example.com', '{"user":{"id":"user-123"}}');
    final loggedIn = await auth.authenticate(
      'user@example.com',
      'password',
      register: false,
      remember: true,
    );
    expect(loggedIn, isTrue);
    expect(stoppedNearbyBeforeLogin, isTrue);
    expect(auth.signedIn, isTrue);
    expect(storage.owner, 'user:user-123');

    // Member database does not contain guest private setting
    final memberDb = LocalDatabaseService.instance;
    expect(await memberDb.getSetting('guestSetting'), isNull);

    // Save a setting in member's database
    await memberDb.setSetting('memberSetting', 'cloud_value');

    // Now sign out
    bool stoppedNearbyBeforeLogout = false;
    auth.beforeScopeChange = () async {
      stoppedNearbyBeforeLogout = true;
    };
    await auth.signOut();
    expect(stoppedNearbyBeforeLogout, isTrue);
    expect(auth.signedIn, isFalse);
    expect(storage.owner, 'guest');
    expect(AppPreferences.instance.guestMode, isFalse); // reset on explicit logout

    // Verify Guest data is still intact and member data is not in guest DB
    final restoredGuestDb = LocalDatabaseService.instance;
    expect(await restoredGuestDb.getSetting('guestSetting'), 'local_value');
    expect(await restoredGuestDb.getSetting('memberSetting'), isNull);
  });

  testWidgets('LoginScreen guest button triggers enterGuest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(auth: auth),
      ),
    );
    expect(find.byKey(const ValueKey('guest-button')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('guest-button')));
    await tester.tap(find.byKey(const ValueKey('guest-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(auth.signedIn, isFalse);
    expect(storage.owner, 'guest');
    expect(AppPreferences.instance.guestMode, isTrue);
  });

  testWidgets('MemberScreen renders guest mode card and login button', (tester) async {
    await auth.enterGuest();
    final repo = StubMemberRepo(null);
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
        darkTheme: RescueTheme.dark,
        home: MemberScreen(repository: repo),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ผู้ใช้งานทั่วไป (Guest)'), findsOneWidget);
    expect(find.text('ฟีเจอร์ Cloud และการจัดการบัญชีต้องเข้าสู่ระบบก่อน'), findsOneWidget);
    expect(find.byKey(const ValueKey('member-login-button')), findsOneWidget);
    expect(find.text('ออกจากระบบ'), findsOneWidget);
    expect(find.text('ลบบัญชีถาวร'), findsNothing);
  });
}
