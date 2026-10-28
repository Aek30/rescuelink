import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_model.dart';
import '../models/message_model.dart';
import 'auth_service.dart';
import 'local_database_service.dart';

abstract interface class ChatAttachmentCloud {
  Future<void> restoreAttachments(LocalDatabaseService database);
}

abstract interface class AttachmentArchive {
  Future<List<Map<String, dynamic>>> list();
  Future<Uint8List> download(String id);
  bool get isCurrent;
}

class SupabaseAttachmentArchive implements AttachmentArchive {
  SupabaseAttachmentArchive(this.auth, this.owner);
  final AuthService auth;
  final String owner;
  @override
  bool get isCurrent => auth.session?.userId == owner;
  @override
  Future<List<Map<String, dynamic>>> list() async {
    final client = await auth.cloudClient(owner);
    final records = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      if (!isCurrent) throw StateError('บัญชีเปลี่ยนแล้ว');
      final page = await client
          .from('media_records')
          .select()
          .eq('owner_id', owner)
          .order('id')
          .range(offset, offset + 199);
      records.addAll(page);
      if (page.length < 200) return records;
    }
  }

  @override
  Future<Uint8List> download(String id) async {
    final client = await auth.cloudClient(owner);
    return client.storage.from('chat-media').download('$owner/$id');
  }
}

/// Restore only attachments referenced by this account's non-deleted history.
/// A failed file never prevents other files or text messages from restoring.
class ChatAttachmentRestore {
  ChatAttachmentRestore(this.cloud, {this.directoryProvider});
  final AttachmentArchive cloud;
  final Future<Directory> Function()? directoryProvider;

  Future<void> restore(LocalDatabaseService database) async {
    final records = await cloud.list().timeout(const Duration(seconds: 20));
    final db = await database.database;
    final messages = <String, MessageModel>{
      for (final row in await db.query('chat_records', where: 'deleted = 0'))
        row['id'] as String: MessageModel.fromJson(row['payload'] as String),
    };
    Directory? folder;
    var failed = false;
    for (final row in records) {
      if (!cloud.isCurrent) throw StateError('บัญชีเปลี่ยนแล้ว');
      final message = messages[row['message_id']];
      final id = row['id'] as String;
      if (message == null ||
          message.type != MessageType.media ||
          message.text != id) {
        continue;
      }
      try {
        if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
          throw const FormatException('Invalid media ID');
        }
        final existing = await database.getMediaForMessage(message.id);
        if (existing != null && await _valid(File(existing.localPath), row)) {
          continue;
        }
        final bytes = await cloud
            .download(id)
            .timeout(const Duration(minutes: 3));
        if (!cloud.isCurrent) throw StateError('บัญชีเปลี่ยนแล้ว');
        if (bytes.length != row['file_size'] ||
            sha256.convert(bytes).toString() != row['checksum']) {
          throw const FormatException('Attachment checksum mismatch');
        }
        if (folder == null) {
          final root =
              await (directoryProvider?.call() ??
                  getApplicationSupportDirectory());
          // Separate caches for accounts that share one installation.
          folder = Directory(
            p.join(
              root.path,
              'chat-archive',
              sha256.convert(utf8.encode(db.path)).toString(),
            ),
          );
        }
        await folder.create(recursive: true);
        final extension = p.extension(row['file_name'] as String);
        final safeExtension =
            RegExp(r'^\.[a-zA-Z0-9]{1,8}$').hasMatch(extension)
            ? extension
            : '';
        final file = File(p.join(folder.path, '$id$safeExtension'));
        final temporary = File('${file.path}.part');
        await temporary.writeAsBytes(bytes, flush: true);
        if (!cloud.isCurrent) {
          await temporary.delete();
          throw StateError('บัญชีเปลี่ยนแล้ว');
        }
        await temporary.rename(file.path);
        await database.insertMediaFile(
          MediaFile(
            mediaId: id,
            messageId: message.id,
            senderId: message.senderId,
            senderName: message.senderName,
            receiverId: message.receiverId,
            fileName: row['file_name'] as String,
            mimeType: row['mime_type'] as String,
            fileSize: bytes.length,
            checksum: row['checksum'] as String,
            localPath: file.path,
            createdAt: DateTime.parse(row['created_at'] as String),
            bytesTransferred: bytes.length,
            status: MediaStatus.cloudReady,
          ),
        );
        // Replace stale metadata when a file was missing on this device.
        await db.update(
          'media_files',
          {
            'localPath': file.path,
            'status': MediaStatus.cloudReady.name,
            'bytesTransferred': bytes.length,
          },
          where: 'mediaId = ?',
          whereArgs: [id],
        );
        database.cloudReceiptsChanged.value++;
      } catch (_) {
        if (!cloud.isCurrent) rethrow;
        failed = true;
      }
    }
    final backedUpIds = {for (final row in records) row['id']};
    for (final message in messages.values.where(
      (m) => m.type == MessageType.media,
    )) {
      if (!cloud.isCurrent) throw StateError('บัญชีเปลี่ยนแล้ว');
      if (backedUpIds.contains(message.text)) continue;
      final local = await database.getMediaForMessage(message.id);
      if (local == null ||
          local.localPath.isEmpty ||
          !await File(local.localPath).exists()) {
        failed = true;
      }
    }
    if (failed) throw StateError('กู้คืนไฟล์บางรายการไม่สำเร็จ จะลองใหม่');
  }

  Future<bool> _valid(File file, Map<String, dynamic> row) async =>
      await file.exists() &&
      await file.length() == row['file_size'] &&
      (await sha256.bind(file.openRead()).first).toString() == row['checksum'];
}
