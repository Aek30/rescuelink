import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/services/chat_attachment_restore.dart';
import 'package:rescuelink/services/chat_store.dart';
import 'package:rescuelink/services/chat_sync_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'chat_sync_test.dart' show MemoryChatCloud;
import 'message_service_test.dart' show Transport;

class ArchiveFiles implements AttachmentArchive {
  final records = <Map<String, dynamic>>[];
  final files = <String, Uint8List>{};
  bool corrupt = false;
  int downloads = 0;
  @override
  bool isCurrent = true;
  @override
  Future<List<Map<String, dynamic>>> list() async => records;
  @override
  Future<Uint8List> download(String id) async {
    downloads++;
    return corrupt ? Uint8List.fromList([0]) : files[id]!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late LocalDatabaseService oldDevice, newDevice;
  late MemoryChatCloud cloud;
  late ChatSyncService oldSync, newSync;
  late String oldId;
  MessageModel item(
    String id, {
    bool incoming = false,
    String peer = 'peer',
    MessageType type = MessageType.message,
    String? text,
  }) => MessageModel(
    id: id,
    senderId: incoming ? peer : oldId,
    senderName: 'ชื่อเหมือนกัน',
    receiverId: incoming ? oldId : peer,
    text: text ?? 'ข้อความ $id',
    timestamp: DateTime.utc(2026, 10, 26),
    type: type,
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chat-cross-device-');
    oldDevice = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${dir.path}/old.db',
    );
    newDevice = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${dir.path}/new.db',
    );
    oldId = await oldDevice.getDeviceId();
    cloud = MemoryChatCloud();
    oldSync = ChatSyncService(ChatStore(oldDevice), cloud);
    newSync = ChatSyncService(ChatStore(newDevice), cloud);
  });
  tearDown(() async {
    oldSync.dispose();
    newSync.dispose();
    await oldDevice.close();
    await newDevice.close();
    await dir.delete(recursive: true);
  });
  Future<MessageService> openNewDevice() async {
    final wire = Transport();
    final service = MessageService(nearbyService: wire, database: newDevice);
    addTearDown(() {
      service.dispose();
      wire.dispose();
    });
    await service.initialize();
    return service;
  }

  test(
    'fresh device restores every conversation, direction and peer name without guessing names',
    () async {
      await oldDevice.savePeer('peer', 'ผู้ติดต่อเดิม');
      await oldDevice.savePeer('outgoing-only', 'ส่งหาอย่างเดียว');
      for (var i = 0; i < 205; i++) {
        await oldDevice.insertMessage(item('m$i', incoming: i.isOdd));
      }
      await oldDevice.insertMessage(item('only', peer: 'outgoing-only'));
      await oldSync.sync();
      expect(oldSync.error, isNull);
      await newDevice.setSetting('profileDisplayName', 'เปลี่ยนชื่อแล้ว');
      await newSync.sync();
      final service = await openNewDevice();
      expect(service.myId, isNot(oldId));
      expect(service.messages, hasLength(206));
      expect(
        service.messages.where((m) => m.senderId == service.myId),
        hasLength(104),
      );
      expect(
        service.messages.where((m) => m.receiverId == service.myId),
        hasLength(102),
      );
      expect(service.peers['peer'], 'ผู้ติดต่อเดิม');
      expect(service.peers['outgoing-only'], 'ส่งหาอย่างเดียว');
      expect(
        await newDevice.getMessages(),
        isEmpty,
        reason: 'Restoring history never replays radio packets',
      );
      await newSync.sync();
      expect(await ChatStore(newDevice).list(), hasLength(206));
      expect(await ChatStore(newDevice).queue(), isEmpty);
    },
  );

  test(
    'legacy archives use registered account identities even for incoming-only history',
    () async {
      cloud.records['legacy'] = {
        'id': 'legacy',
        'version': 1,
        'deleted': false,
        'payload': item('legacy', incoming: true).toMap(),
      };
      await newDevice.setSetting('myRadioIds', jsonEncode([oldId]));
      await newSync.sync();
      final service = await openNewDevice();
      expect(service.messages.single.senderId, 'peer');
      expect(service.messages.single.receiverId, service.myId);
    },
  );

  test(
    'legacy metadata upgrade never rewrites an operation after a lost cloud reply',
    () async {
      await oldDevice.insertMessage(item('legacy-queued'));
      final db = await oldDevice.database;
      final queued = (await ChatStore(oldDevice).queue()).single;
      final legacy = item('legacy-queued').toJson();
      await db.update('chat_records', {'payload': legacy});
      await db.update('chat_queue', {'payload': legacy});
      cloud.loseReply = true;
      await oldSync.sync();
      final replay = (await ChatStore(oldDevice).queue()).first;
      expect(replay['operation_id'], queued['operation_id']);
      expect(replay['payload'], legacy);
      expect(oldSync.conflicts, 0);
      await oldSync.sync();
      expect(await ChatStore(oldDevice).queue(), isEmpty);
      expect(oldSync.conflicts, 0);
      expect(
        cloud.records['legacy-queued']!['payload']['archiveIdentity'],
        oldId,
      );
    },
  );

  test(
    'v9 upgrade queues existing media and SOS history exactly once',
    () async {
      await oldDevice.insertMessage(item('old-photo', type: MessageType.media));
      await oldDevice.insertMessage(item('old-sos', type: MessageType.sos));
      final db = await oldDevice.database;
      await db.delete('chat_queue');
      await db.delete('chat_records');
      await db.setVersion(9);
      await oldDevice.close();
      expect(await ChatStore(oldDevice).list(), hasLength(2));
      expect(await ChatStore(oldDevice).queue(), hasLength(2));
      await oldSync.sync();
      expect(await ChatStore(oldDevice).queue(), isEmpty);
      await oldDevice.close();
      expect(await ChatStore(oldDevice).list(), hasLength(2));
    },
  );

  test(
    'cloud edits and deletion update an already used device archive',
    () async {
      await oldDevice.insertMessage(item('edited'));
      await oldDevice.insertMessage(item('deleted', incoming: true));
      await oldSync.sync();
      await newSync.sync();
      await ChatStore(newDevice).edit('edited', text: 'แก้ไขจากอีกเครื่อง');
      await ChatStore(newDevice).edit('deleted', delete: true);
      await newSync.sync();
      await oldSync.sync();
      final wire = Transport();
      final service = MessageService(nearbyService: wire, database: oldDevice);
      addTearDown(() {
        service.dispose();
        wire.dispose();
      });
      await service.initialize();
      expect(service.messages.single.text, 'แก้ไขจากอีกเครื่อง');
    },
  );

  test(
    'media and SOS messages restore alongside verified attachments, with retry after corruption',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final file = File('${dir.path}/photo.png');
      await file.writeAsBytes(bytes);
      final media = MediaFile(
        mediaId: 'photo',
        messageId: 'media-message',
        senderId: oldId,
        senderName: 'ฉัน',
        receiverId: 'peer',
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileSize: bytes.length,
        checksum: sha256.convert(bytes).toString(),
        localPath: file.path,
        createdAt: DateTime.utc(2026, 10, 26),
        status: MediaStatus.delivered,
      );
      await oldDevice.saveMediaMessage(
        media,
        item('media-message', type: MessageType.media, text: 'photo'),
      );
      await oldDevice.insertMessage(
        item('sos-message', type: MessageType.sos, text: 'SOS เดิม'),
      );
      await oldSync.sync();
      await newSync.sync();
      final files = ArchiveFiles();
      files.records.add({
        'id': 'photo',
        'message_id': 'media-message',
        'file_name': 'photo.png',
        'mime_type': 'image/png',
        'file_size': bytes.length,
        'checksum': media.checksum,
        'created_at': media.createdAt.toIso8601String(),
      });
      files.files['photo'] = bytes;
      final restore = ChatAttachmentRestore(
        files,
        directoryProvider: () async => dir,
      );
      files.corrupt = true;
      await expectLater(restore.restore(newDevice), throwsStateError);
      expect(await newDevice.getMediaForMessage('media-message'), isNull);
      expect(await ChatStore(newDevice).list(), hasLength(2));
      files.corrupt = false;
      await restore.restore(newDevice);
      final restored = (await newDevice.getMediaForMessage('media-message'))!;
      expect(await File(restored.localPath).readAsBytes(), bytes);
      expect(restored.localPath, isNot(file.path));
      final service = await openNewDevice();
      expect(
        service.messages.map((m) => m.type),
        containsAll([MessageType.media, MessageType.sos]),
      );
      await restore.restore(newDevice);
      expect(
        files.downloads,
        2,
        reason: 'Verified local files are not downloaded again',
      );
      expect(await newDevice.getMessages(), isEmpty);
    },
  );
}
