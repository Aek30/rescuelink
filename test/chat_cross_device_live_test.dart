import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/chat_attachment_restore.dart';
import 'package:rescuelink/services/chat_store.dart';
import 'package:rescuelink/services/chat_sync_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/media_upload_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'message_service_test.dart' show Transport;
import 'sos_cloud_live_test.dart' show TestVault;

/// Exercise the real paginated API while limiting restoration to synthetic IDs.
class FixtureChatCloud extends SupabaseChatCloud {
  FixtureChatCloud(
    super.auth,
    super.owner,
    this.ids, {
    required super.database,
    required super.attachments,
  });
  final Set<String> ids;
  @override
  Future<List<Map<String, dynamic>>> pull() async =>
      (await super.pull()).where((r) => ids.contains(r['id'])).toList();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test(
    'live same-account login on two installations restores text, SOS and image in the same conversation',
    () async {
      final config = jsonDecode(
        await File('config/supabase.local.json').readAsString(),
      );
      final fixture = jsonDecode(
        await File('config/test-account.local.json').readAsString(),
      );
      final dir = await Directory.systemTemp.createTemp(
        'rescuelink-chat-live-',
      );
      final originalDatabase = LocalDatabaseService.instance;
      final storages = <AccountStorage>[];
      final accounts = <AuthService>[];
      final databases = <LocalDatabaseService>[];
      final syncs = <ChatSyncService>[];
      final ids = {for (var i = 0; i < 3; i++) const Uuid().v4()};
      final mediaId = const Uuid().v4();
      final peer = const Uuid().v4();
      String? owner;
      try {
        for (var i = 0; i < 2; i++) {
          final folder = Directory('${dir.path}/device$i');
          await folder.create();
          final storage = AccountStorage(
            factory: databaseFactoryFfi,
            directory: folder.path,
          );
          storages.add(storage);
          final auth = AuthService(
            storage: storage,
            vault: TestVault(),
            backend: SupabaseAuthBackend(
              config['SUPABASE_URL'],
              config['SUPABASE_PUBLISHABLE_KEY'],
            ),
          );
          accounts.add(auth);
          await auth.initialize();
          expect(
            await auth.authenticate(
              fixture['email'],
              fixture['password'],
              register: false,
              remember: false,
            ),
            isTrue,
            reason: 'Fixture login must succeed: ${auth.error ?? auth.notice}',
          );
          owner ??= auth.session!.userId;
          expect(auth.session!.userId, owner);
          databases.add(LocalDatabaseService.instance);
        }
        final first = databases[0], second = databases[1];
        final oldId = await first.getDeviceId();
        final newId = await second.getDeviceId();
        expect(newId, isNot(oldId));
        await first.savePeer(peer, 'Synthetic existing contact');
        final sent = MessageModel(
          id: ids.elementAt(0),
          senderId: oldId,
          senderName: 'Synthetic account',
          receiverId: peer,
          text: 'Synthetic prior conversation',
          timestamp: DateTime.now().toUtc(),
        );
        final sos = MessageModel(
          id: ids.elementAt(1),
          senderId: peer,
          senderName: 'Synthetic existing contact',
          receiverId: oldId,
          text: SosAlert(
            incidentId: const Uuid().v4(),
            revision: 1,
            active: false,
            name: 'Synthetic SOS',
            people: 1,
            category: EmergencyType.medical,
            details: 'Synthetic closed SOS',
            updatedAt: DateTime.now().toUtc(),
          ).toJson(),
          timestamp: DateTime.now().toUtc(),
          type: MessageType.sos,
        );
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
        );
        final file = File('${dir.path}/synthetic.png');
        await file.writeAsBytes(bytes);
        final media = MediaFile(
          mediaId: mediaId,
          messageId: ids.elementAt(2),
          senderId: oldId,
          senderName: 'Synthetic account',
          receiverId: peer,
          fileName: 'synthetic.png',
          mimeType: 'image/png',
          fileSize: bytes.length,
          checksum: sha256.convert(bytes).toString(),
          localPath: file.path,
          createdAt: DateTime.now().toUtc(),
          status: MediaStatus.delivered,
        );
        await first.insertMessage(sent);
        await first.insertMessage(sos);
        await first.saveMediaMessage(
          media,
          MessageModel(
            id: media.messageId,
            senderId: oldId,
            senderName: media.senderName,
            receiverId: peer,
            text: mediaId,
            timestamp: media.createdAt,
            type: MessageType.media,
            status: MessageStatus.delivered,
          ),
        );
        final mediaCloud = SupabaseMediaCloud(accounts[0]);
        await mediaCloud.upload(media, owner!, (_) {});
        await mediaCloud.verify(media, owner);
        for (var i = 0; i < 2; i++) {
          syncs.add(
            ChatSyncService(
              ChatStore(databases[i]),
              FixtureChatCloud(
                accounts[i],
                owner,
                ids,
                database: databases[i],
                attachments: ChatAttachmentRestore(
                  SupabaseAttachmentArchive(accounts[i], owner),
                  directoryProvider: () async =>
                      Directory('${dir.path}/files$i'),
                ),
              ),
            ),
          );
        }
        await syncs[0].sync();
        expect(syncs[0].error, isNull);
        await syncs[1].sync();
        expect(syncs[1].error, isNull);
        expect(await ChatStore(second).list(), hasLength(3));
        expect(await second.getMessages(), isEmpty);
        final restoredFile = (await second.getMediaForMessage(
          media.messageId,
        ))!;
        expect(await File(restoredFile.localPath).readAsBytes(), bytes);
        final wire = Transport();
        final service = MessageService(nearbyService: wire, database: second);
        try {
          await service.initialize();
          expect(service.messages, hasLength(3));
          expect(
            service.messages.singleWhere((m) => m.id == sent.id).senderId,
            newId,
          );
          expect(
            service.messages.singleWhere((m) => m.id == sos.id).receiverId,
            newId,
          );
          expect(service.peers[peer], 'Synthetic existing contact');
          expect(wire.packets, isEmpty);
        } finally {
          service.dispose();
          wire.dispose();
        }
      } finally {
        // Remove only generated fixture attachments/installations. Archive rows
        // use the same supported tombstone operation as the application.
        if (owner != null && accounts.first.session != null) {
          final client = await accounts.first.cloudClient(owner);
          for (final id in ids) {
            final rows = await client
                .from('chat_records')
                .select()
                .eq('owner_id', owner)
                .eq('id', id);
            if (rows.isNotEmpty && rows.single['deleted'] != true) {
              await client.rpc(
                'sync_chat',
                params: {
                  'operation': const Uuid().v4(),
                  'record_id': id,
                  'base_version': rows.single['version'],
                  'body': rows.single['payload'],
                  'remove_record': true,
                },
              );
            }
          }
          await client.storage.from(SupabaseMediaCloud.bucket).remove([
            '$owner/$mediaId',
          ]);
          await client
              .from('media_records')
              .delete()
              .eq('owner_id', owner)
              .eq('id', mediaId);
          for (final storage in storages) {
            await client
                .from('account_devices')
                .delete()
                .eq('user_id', owner)
                .eq('installation_id', await storage.installationId);
          }
        }
        for (final sync in syncs) {
          sync.dispose();
        }
        for (final auth in accounts) {
          await auth.signOut();
          auth.dispose();
        }
        for (final storage in storages) {
          await storage.close();
        }
        LocalDatabaseService.instance = originalDatabase;
        await dir.delete(recursive: true);
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_CHAT'),
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
