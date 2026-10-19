import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/member_service.dart';
import 'package:rescuelink/services/member_profile_sync.dart';
import 'member_repository_test.dart' show TestAuth;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // These repository tests intentionally exercise the SDK over local HTTP.
  HttpOverrides.global = null;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late AccountStorage storage;
  late LocalDatabaseService database;
  late HttpServer server;
  late SupabaseClient client;
  late TestAuth auth;
  late SupabaseMemberRepository repository;
  late StreamSubscription<HttpRequest> subscription;
  late Future<void> Function(HttpRequest) respond;
  String cloudName = 'Cloud name';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('member-draft-');
    storage = AccountStorage(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    database = await storage.select('owner-A');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'public-test-key',
    );
    auth = TestAuth(storage, client)
      ..session = const AccountSession('owner-A', 'a@example.com', 'session');
    repository = SupabaseMemberRepository(auth, localDatabase: database);
    cloudName = 'Cloud name';
    respond = (request) async {
      expect(request.uri.path, '/rest/v1/profiles');
      expect(request.uri.queryParameters['id'], 'eq.owner-A');
      if (request.method == 'PATCH') {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body.keys, ['display_name']);
        cloudName = body['display_name'];
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'id': 'owner-A', 'display_name': cloudName}),
      );
      await request.response.close();
    };
    subscription = server.listen((request) async => respond(request));
  });

  tearDown(() async {
    await subscription.cancel();
    await client.dispose();
    await server.close(force: true);
    auth.dispose();
    await storage.close();
    await directory.delete(recursive: true);
  });

  test(
    'offline save survives reopening; only an acknowledged upload clears draft',
    () async {
      auth.offline = true;
      final result = await repository.updateName(' Offline name ');
      expect(result.name, 'Offline name');
      expect(result.pending, isTrue);
      expect(result.offline, isTrue);
      expect(await database.getSetting('profileNameDraft'), 'Offline name');
      expect(await database.getSetting('profileDisplayName'), isNull);
      final reopened = SupabaseMemberRepository(auth, localDatabase: database);
      expect((await reopened.read()).name, 'Offline name');
      expect(await database.getSetting('profileNameDraft'), 'Offline name');
      auth.offline = false;
      final synced = await reopened.syncPending();
      expect(synced.pending, isFalse);
      expect(cloudName, 'Offline name');
      expect(await database.getSetting('profileNameDraft'), isNull);
      expect(await database.getSetting('profileNameDraftRevision'), isNull);
      expect(await database.getSetting('profileDisplayName'), 'Offline name');
    },
  );

  test('server failure and mismatched confirmation retain the draft', () async {
    respond = (request) async {
      await request.drain<void>();
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"message":"unavailable"}');
      await request.response.close();
    };
    expect((await repository.updateName('Keep me')).pending, isTrue);
    expect(await database.getSetting('profileNameDraft'), 'Keep me');
    respond = (request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"id":"owner-A","display_name":"Different"}');
      await request.response.close();
    };
    expect((await repository.syncPending()).pending, isTrue);
    expect(await database.getSetting('profileNameDraft'), 'Keep me');
    expect(await database.getSetting('profileDisplayName'), isNull);
  });

  test(
    'late confirmation cannot delete a newer draft from another repository',
    () async {
      final firstStarted = Completer<void>(), firstRelease = Completer<void>();
      final secondStarted = Completer<void>(),
          secondRelease = Completer<void>();
      var requests = 0;
      respond = (request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        final value = body['display_name'];
        if (++requests == 1) {
          firstStarted.complete();
          await firstRelease.future;
        } else {
          secondStarted.complete();
          await secondRelease.future;
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'id': 'owner-A', 'display_name': value}),
        );
        await request.response.close();
      };
      final first = repository.updateName('First');
      await firstStarted.future;
      final other = SupabaseMemberRepository(auth, localDatabase: database);
      final second = other.updateName('Second');
      for (var i = 0; i < 100; i++) {
        if (await database.getSetting('profileNameDraft') == 'Second') break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(await database.getSetting('profileNameDraft'), 'Second');
      firstRelease.complete();
      final oldResult = await first;
      expect(oldResult.pending, isTrue);
      expect(oldResult.name, 'Second');
      await secondStarted.future;
      expect(await database.getSetting('profileNameDraft'), 'Second');
      secondRelease.complete();
      expect((await second).pending, isFalse);
      expect(await database.getSetting('profileDisplayName'), 'Second');
    },
  );

  test(
    'account switch rejects late upload and preserves both account drafts',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      final defaultRespond = respond;
      respond = (request) async {
        started.complete();
        await release.future;
        await defaultRespond(request);
      };
      final saving = repository.updateName('A draft');
      final rejected = expectLater(saving, throwsStateError);
      await started.future;
      final otherDatabase = await storage.select('owner-B');
      await otherDatabase.setSetting('profileNameDraft', 'B draft');
      auth.session = const AccountSession('owner-B', 'b@example.com', 'B');
      release.complete();
      await rejected;
      expect(await database.getSetting('profileNameDraft'), 'A draft');
      expect(await otherDatabase.getSetting('profileNameDraft'), 'B draft');
      expect(await otherDatabase.getSetting('profileDisplayName'), isNull);
    },
  );

  test(
    'legacy draft is uploaded rather than overwritten by Cloud read',
    () async {
      await database.setSetting('profileNameDraft', 'Legacy draft');
      final result = await repository.read();
      expect(result.name, 'Legacy draft');
      expect(result.pending, isFalse);
      expect(cloudName, 'Legacy draft');
    },
  );

  test(
    'member drafts retry automatically when Cloud is reachable again',
    () async {
      final previousDatabase = LocalDatabaseService.instance;
      LocalDatabaseService.instance = database;
      auth.offline = true;
      await database.setSetting('profileNameDraft', 'Background name');
      final sync = MemberProfileSync(
        auth: auth,
        retryInterval: const Duration(milliseconds: 30),
      );
      final offlineStatus = Completer<void>(), syncedStatus = Completer<void>();
      sync.addListener(() {
        if (sync.profile?.offline == true && !offlineStatus.isCompleted) {
          offlineStatus.complete();
        }
        if (sync.profile?.name == 'Background name' &&
            sync.profile?.pending == false &&
            !syncedStatus.isCompleted) {
          syncedStatus.complete();
        }
      });
      try {
        sync.start();
        await offlineStatus.future.timeout(const Duration(seconds: 5));
        expect(
          await database.getSetting('profileNameDraft'),
          'Background name',
        );
        auth.offline = false;
        await syncedStatus.future.timeout(const Duration(seconds: 5));
        expect(cloudName, 'Background name');
        expect(await database.getSetting('profileNameDraft'), isNull);
      } finally {
        sync.dispose();
        LocalDatabaseService.instance = previousDatabase;
      }
    },
  );
}
