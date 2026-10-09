import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/sos_alert.dart';

class MemoryVault implements SessionVault {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Storage unavailable');
    this.value = value;
  }

  @override
  Future<void> clear() async {
    if (fail) throw StateError('Storage unavailable');
    value = null;
  }
}

class FakeBackend implements AuthBackend {
  @override
  Future<void> linkInstallation(
    AccountSession session,
    String installationId,
    String radioIdentity,
  ) async {}
  AccountSession? result = const AccountSession(
    'A',
    'a@example.com',
    'session-A',
  );
  Object? failure;
  Completer<void>? delay;
  int calls = 0;
  String? receivedName;
  Map<String, dynamic>? receivedMetadata;
  int resendCalls = 0;
  @override
  Future<AccountSession?> authenticate(
    String email,
    String password, {
    required bool register,
    String? displayName,
    Map<String, dynamic>? extraMetadata,
  }) async {
    calls++;
    receivedName = displayName;
    receivedMetadata = extraMetadata;
    await delay?.future;
    if (failure != null) throw failure!;
    return result;
  }

  @override
  Future<AccountSession> restore(String serialized) async {
    await delay?.future;
    if (failure != null) throw failure!;
    return result!;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> resendConfirmation(String email) async {
    resendCalls++;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {}
}

class BrokenCatalog extends AccountStorage {
  BrokenCatalog() : super(factory: databaseFactoryFfi);
  @override
  Future<LocalDatabaseService> select(
    String? userId, {
    bool claimGuest = false,
  }) async {
    throw StateError('Catalog unreadable');
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late AccountStorage storage;
  late MemoryVault vault;
  late FakeBackend backend;
  late AuthService auth;
  final original = LocalDatabaseService.instance;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rescuelink-auth-');
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
    LocalDatabaseService.instance = original;
    await directory.delete(recursive: true);
  });
  test('resend calls backend and throttles repeated attempts', () async {
    await auth.resendConfirmation('a@example.com');
    expect(backend.resendCalls, 1);
    await expectLater(
      auth.resendConfirmation('a@example.com'),
      throwsStateError,
    );
    expect(backend.resendCalls, 1);
  });
  test(
    'catalog failure never falls back to previously claimed legacy data',
    () async {
      final broken = AuthService(
        storage: BrokenCatalog(),
        vault: vault,
        backend: backend,
      );
      await broken.initialize();
      expect(broken.signedIn, isFalse);
      await expectLater(
        LocalDatabaseService.instance.getMessages(),
        throwsStateError,
      );
      broken.dispose();
    },
  );
  Future<bool> login({bool claim = false, bool remember = true}) =>
      auth.authenticate(
        'a@example.com',
        'password-123',
        register: false,
        remember: remember,
      );

  test(
    'sign in creates user-specific storage without transferring Guest data',
    () async {
      final guest = LocalDatabaseService.instance;
      final radio = await guest.getDeviceId();
      final message = MessageModel(
        id: 'pending',
        senderId: radio,
        senderName: 'Guest',
        receiverId: 'peer',
        text: 'help',
        timestamp: DateTime.utc(2026),
        type: MessageType.message,
      );
      await guest.savePeer('peer', 'Neighbor');
      final legacySos = jsonEncode({
        'alert': SosAlert(
          incidentId: 'legacy',
          revision: 1,
          active: true,
          name: 'Guest',
          people: 1,
          category: EmergencyType.medical,
          details: 'help',
          updatedAt: DateTime.utc(2026),
        ).toJson(),
        'recipients': ['peer'],
      });
      await guest.saveSos(legacySos, [message]);
      await guest.claimRelay('seen');
      // claimGuest is always false now — sign in creates a fresh user DB.
      expect(await login(), isTrue);
      final member = LocalDatabaseService.instance;
      // User gets their own device ID (separate from guest).
      expect(await member.getDeviceId(), isNot(radio));
      // User storage is empty — guest data is NOT transferred.
      expect(await member.getSetting('mySos'), isNull);
      expect(await member.getMessages(), isEmpty);
      await auth.signOut();
      // After sign-out, guest storage is still intact and separate.
      final freshGuest = LocalDatabaseService.instance;
      expect(await freshGuest.getSetting('mySos'), legacySos);
      expect((await freshGuest.getMessages()).single.id, 'pending');
      backend.result = const AccountSession('B', 'b@example.com', 'session-B');
      expect(await login(), isTrue);
      expect(await LocalDatabaseService.instance.getMessages(), isEmpty);
      // A late callback retaining A's handle cannot write into B's storage.
      await member.setSetting('late-write', 'A');
      expect(
        await LocalDatabaseService.instance.getSetting('late-write'),
        isNull,
      );
      await auth.signOut();
      backend.result = const AccountSession('A', 'a@example.com', 'session-A');
      expect(await login(), isTrue);
      // Account A's own data (written while signed in) is preserved across sessions.
      expect(await LocalDatabaseService.instance.getMessages(), isEmpty);
    },
  );

  test(
    'sign in without claim leaves Guest history private; accounts are isolated',
    () async {
      await LocalDatabaseService.instance.setSetting('mySos', 'guest');
      expect(await login(), isTrue);
      // User DB is a new separate storage — guest data is private.
      expect(await LocalDatabaseService.instance.getSetting('mySos'), isNull);
      await auth.signOut();
      // Guest data is still intact after sign-out.
      expect(await LocalDatabaseService.instance.getSetting('mySos'), 'guest');
      // Second sign-in succeeds (existing owner just re-opens their storage).
      expect(await login(), isTrue);
      expect(auth.signedIn, isTrue);
    },
  );

  test(
    'confirmation and invalid credentials do not adopt Guest data',
    () async {
      backend.result = null;
      expect(await login(claim: true), isFalse);
      expect(storage.owner, 'guest');
      expect(auth.notice, contains('ยืนยันบัญชี'));
      expect(auth.error, isNull);
      backend.failure = const AuthException(
        'Invalid',
        code: 'invalid_credentials',
      );
      expect(await login(), isFalse);
      expect(auth.error, 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
      expect(vault.value, isNull);
    },
  );

  test(
    'secure-storage failure prevents Guest claim and logout fails closed',
    () async {
      vault.fail = true;
      expect(await login(claim: true), isFalse);
      expect(storage.owner, 'guest');
      vault.fail = false;
      expect(await login(), isTrue);
      vault.fail = true;
      await expectLater(auth.signOut(), throwsStateError);
      expect(auth.signedIn, isTrue);
      expect(storage.owner, 'user:A');
    },
  );

  test('signup passes trimmed name and confirmation is not an error', () async {
    backend.result = null;
    expect(
      await auth.authenticate(
        'new@example.com',
        'sample-password',
        register: true,
        remember: true,
        displayName: '  Rescue Member  ',
      ),
      isFalse,
    );
    expect(backend.receivedName, 'Rescue Member');
    expect(auth.notice, contains('ยืนยันบัญชี'));
    expect(auth.error, isNull);
    expect(storage.owner, 'guest');
    expect(vault.value, isNull);
  });

  test(
    'network and email delivery restrictions have actionable errors',
    () async {
      backend.failure = const SocketException('Offline');
      expect(await login(), isFalse);
      expect(auth.error, contains('ข้อมูลมือถือ'));
      backend.failure = const AuthException(
        'Email address not authorized',
        code: 'email_address_not_authorized',
      );
      expect(await login(), isFalse);
      expect(auth.error, contains('บริการส่งอีเมล'));
      expect(storage.owner, 'guest');
    },
  );

  test('remember off does not persist; duplicate submit is ignored', () async {
    backend.delay = Completer<void>();
    final first = login(remember: false);
    expect(await login(), isFalse);
    backend.delay!.complete();
    expect(await first, isTrue);
    expect(backend.calls, 1);
    expect(vault.value, isNull);
  });

  test(
    'restart restores the same owner; expired/offline recovery stays Guest',
    () async {
      expect(await login(), isTrue);
      await LocalDatabaseService.instance.setSetting('mySos', 'A');
      final restored = AuthService(
        storage: storage,
        vault: vault,
        backend: backend,
      );
      await restored.initialize();
      expect(restored.session?.userId, 'A');
      expect(await LocalDatabaseService.instance.getSetting('mySos'), 'A');
      backend.failure = const AuthException('Invalid refresh token');
      final expired = AuthService(
        storage: storage,
        vault: vault,
        backend: backend,
      );
      await expired.initialize();
      expect(expired.signedIn, isFalse);
      expect(await LocalDatabaseService.instance.getSetting('mySos'), isNull);
      restored.dispose();
      expired.dispose();
    },
  );
}
