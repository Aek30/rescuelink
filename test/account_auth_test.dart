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
  @override
  Future<AccountSession?> authenticate(
    String email,
    String password, {
    required bool register,
  }) async {
    calls++;
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
  test(
    'Guest can bypass slow recovery and late response cannot switch owner',
    () async {
      vault.value = 'session-A';
      backend.delay = Completer<void>();
      final startup = AuthService(
        storage: storage,
        vault: vault,
        backend: backend,
      );
      final recovery = startup.initialize();
      await startup.enterGuestFromStartup();
      await recovery;
      expect(startup.signedIn, isFalse);
      backend.delay!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(startup.signedIn, isFalse);
      expect(storage.owner, 'guest');
      startup.dispose();
    },
  );
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
        claimGuest: claim,
      );

  test(
    'legacy Guest ownership transfers once with SOS, queue and radio identity',
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
      expect(await login(claim: true), isTrue);
      final member = LocalDatabaseService.instance;
      expect(await member.getDeviceId(), radio);
      expect(await member.getSetting('mySos'), legacySos);
      expect((await member.getMessages()).single.id, 'pending');
      expect(await member.claimRelay('seen'), isFalse);
      await auth.signOut();
      final freshGuest = LocalDatabaseService.instance;
      expect(await freshGuest.getMessages(), isEmpty);
      expect(await freshGuest.getPeers(), isEmpty);
      expect(await freshGuest.getSetting('mySos'), isNull);
      expect(await freshGuest.getDeviceId(), isNot(radio));
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
      expect(
        (await LocalDatabaseService.instance.getMessages()).single.id,
        'pending',
      );
    },
  );

  test(
    'sign in without claim leaves Guest history private; existing owner cannot claim',
    () async {
      await LocalDatabaseService.instance.setSetting('mySos', 'guest');
      expect(await login(), isTrue);
      expect(await LocalDatabaseService.instance.getSetting('mySos'), isNull);
      await auth.signOut();
      expect(await login(claim: true), isFalse);
      expect(auth.signedIn, isFalse);
      expect(vault.value, isNull);
      expect(await LocalDatabaseService.instance.getSetting('mySos'), 'guest');
    },
  );

  test(
    'confirmation and invalid credentials do not adopt Guest data',
    () async {
      backend.result = null;
      expect(await login(claim: true), isFalse);
      expect(storage.owner, 'guest');
      expect(auth.error, contains('ยืนยันบัญชี'));
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
