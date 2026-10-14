import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';

/// Evidence of a confirmed upload, independent of radio delivery receipts.
/// Stored in the account's local settings and committed with the queue ACK.
class CloudSyncReceipts {
  static String _key(String type, String payload) {
    final canonical = type == 'message'
        ? MessageModel.fromJson(
            payload,
          ).copyWith(status: MessageStatus.pending).toJson()
        : SosAlert.fromJson(payload).toJson();
    return 'cloudReceipt:$type:${sha256.convert(utf8.encode(canonical))}';
  }

  static Future<void> record(
    DatabaseExecutor db,
    String type,
    String payload,
  ) async {
    await db.insert('settings', {
      'key': _key(type, payload),
      'value': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<Set<String>> messageIds(
    DatabaseExecutor db,
    List<MessageModel> messages,
  ) async {
    final keys = (await db.query(
      'settings',
      columns: ['key'],
      where: 'key LIKE ?',
      whereArgs: ['cloudReceipt:%'],
    )).map((row) => row['key']).toSet();
    final ids = <String>{};
    for (final message in messages) {
      if (message.type != MessageType.message &&
          message.type != MessageType.sos) {
        continue;
      }
      try {
        final payload = message.type == MessageType.sos
            ? message.text
            : message.toJson();
        if (keys.contains(_key(message.type.name, payload))) {
          ids.add(message.id);
        }
      } on FormatException {
        // Malformed legacy SOS packets cannot prove a cloud upload.
      }
    }
    return ids;
  }
}
