import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import 'local_database_service.dart';

/// Private history archive. Changes never alter already transmitted packets.
class ChatStore {
  ChatStore(this.database);
  final LocalDatabaseService database;

  static Future<void> createSchema(Database db) async {
    await db.execute('''CREATE TABLE chat_records (
      id TEXT PRIMARY KEY, payload TEXT NOT NULL, version INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0, conflict TEXT)''');
    await db.execute('''CREATE TABLE chat_queue (
      seq INTEGER PRIMARY KEY AUTOINCREMENT, operation_id TEXT NOT NULL UNIQUE,
      record_id TEXT NOT NULL, base_version INTEGER NOT NULL,
      payload TEXT NOT NULL, deleted INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, error TEXT,
      blocked INTEGER NOT NULL DEFAULT 0)''');
    await db.execute(
      'CREATE INDEX chat_queue_record ON chat_queue(record_id, seq)',
    );
    for (final row in await db.query(
      'messages',
      where: 'type = ?',
      whereArgs: ['message'],
    )) {
      await capture(db, MessageModel.fromMap(row));
    }
  }

  static Future<void> capture(DatabaseExecutor db, MessageModel message) async {
    if (message.type != MessageType.message) return;
    final rows = await db.query(
      'chat_records',
      where: 'id = ?',
      whereArgs: [message.id],
    );
    // Duplicate radio packets cannot resurrect deleted or edited history.
    if (rows.isNotEmpty) return;
    await _save(db, message.id, message.toJson(), 0, false);
  }

  static Future<void> _save(
    DatabaseExecutor db,
    String id,
    String payload,
    int base,
    bool deleted,
  ) async {
    await db.insert('chat_records', {
      'id': id,
      'payload': payload,
      'version': base + 1,
      'deleted': deleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('chat_queue', {
      'operation_id': const Uuid().v4(),
      'record_id': id,
      'base_version': base,
      'payload': payload,
      'deleted': deleted ? 1 : 0,
    });
  }

  Future<List<Map<String, Object?>>> list() async =>
      (await database.database).query(
        'chat_records',
        where: 'deleted = 0 OR conflict IS NOT NULL',
        orderBy: 'rowid DESC',
      );
  Future<List<Map<String, Object?>>> queue() async =>
      (await database.database).query('chat_queue', orderBy: 'seq');

  Future<void> edit(String id, {String? text, bool delete = false}) async {
    if (!delete &&
        (text == null ||
            text.trim().isEmpty ||
            utf8.encode(text.trim()).length > 24576)) {
      throw ArgumentError('ข้อความต้องไม่ว่างและไม่เกิน 24 KB');
    }
    await (await database.database).transaction((txn) async {
      final row = (await txn.query(
        'chat_records',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      if (row['deleted'] == 1 || row['conflict'] != null) {
        throw StateError('กรุณาจัดการข้อมูลขัดแย้งก่อน');
      }
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      if (!delete) payload['text'] = text!.trim();
      await _save(txn, id, jsonEncode(payload), row['version'] as int, delete);
    });
  }

  static Future<void> _putRemote(
    DatabaseExecutor txn,
    Map<String, dynamic> remote,
  ) async {
    final message = MessageModel.fromMap(
      Map<String, dynamic>.from(remote['payload'] as Map),
    );
    if (message.id != remote['id'] || message.type != MessageType.message) {
      throw const FormatException('Invalid remote chat');
    }
    await txn.insert('chat_records', {
      'id': remote['id'],
      'payload': message.toJson(),
      'version': remote['version'],
      'deleted': remote['deleted'] == true ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> resolve(String id, {required bool keepLocal}) async {
    await (await database.database).transaction((txn) async {
      final row = (await txn.query(
        'chat_records',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      if (row['conflict'] == null) return;
      final remote =
          jsonDecode(row['conflict'] as String) as Map<String, dynamic>?;
      if (keepLocal && remote?['deleted'] == true) {
        throw StateError('Cloud ลบข้อความนี้แล้ว กรุณาใช้ข้อมูล Cloud');
      }
      await txn.delete('chat_queue', where: 'record_id = ?', whereArgs: [id]);
      if (keepLocal) {
        await _save(
          txn,
          id,
          row['payload'] as String,
          remote?['version'] as int? ?? 0,
          row['deleted'] == 1,
        );
      } else if (remote != null) {
        await _putRemote(txn, remote);
      } else {
        await txn.delete('chat_records', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<void> acknowledge(
    Map<String, Object?> operation,
    Map<String, dynamic> result,
  ) async {
    await (await database.database).transaction((txn) async {
      final queued = await txn.query(
        'chat_queue',
        where: 'operation_id = ?',
        whereArgs: [operation['operation_id']],
        limit: 1,
      );
      if (queued.isEmpty) return;
      final id = operation['record_id'];
      if (result['outcome'] == 'conflict') {
        await txn.update(
          'chat_records',
          {'conflict': jsonEncode(result['record'])},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.update(
          'chat_queue',
          {'blocked': 1, 'error': 'ข้อมูลขัดแย้ง'},
          where: 'record_id = ?',
          whereArgs: [id],
        );
      } else if (result['outcome'] == 'applied') {
        await txn.delete(
          'chat_queue',
          where: 'operation_id = ?',
          whereArgs: [operation['operation_id']],
        );
      } else {
        throw const FormatException('Invalid sync response');
      }
    });
  }

  Future<void> mergeRemote(List<Map<String, dynamic>> records) async {
    await (await database.database).transaction((txn) async {
      for (final remote in records) {
        final pending = await txn.query(
          'chat_queue',
          where: 'record_id = ?',
          whereArgs: [remote['id']],
          limit: 1,
        );
        if (pending.isNotEmpty) continue;
        await _putRemote(txn, remote);
      }
    });
  }
}
