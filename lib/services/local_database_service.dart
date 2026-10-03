import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/media_model.dart';
import '../models/message_model.dart';
import 'sos_store.dart';

class LocalDatabaseService {
  LocalDatabaseService({
    DatabaseFactory? factory,
    this.path,
    this.blocked = false,
  }) : _factory = factory ?? databaseFactory;
  // Services capture this immutable database handle when they are created.
  // Never mutate a handle while callbacks from a previous account can finish.
  static LocalDatabaseService instance = LocalDatabaseService();
  final DatabaseFactory _factory;
  final String? path;
  final bool blocked;
  Future<Database>? _opening;
  Future<Database> get database => blocked
      ? Future.error(
          StateError('ไม่สามารถอ่านเจ้าของข้อมูลได้ กรุณาเปิดแอปใหม่'),
        )
      : _opening ??= _open();
  Future<Database> _open() async {
    try {
      return await _factory.openDatabase(
        path ?? p.join(await _factory.getDatabasesPath(), 'rescuelink.db'),
        options: OpenDatabaseOptions(
          version: 6,
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 2) await _createRelaySeen(db);
            if (oldVersion < 3) await SosStore.createSchema(db);
            if (oldVersion < 4) await _createMediaSchema(db);
            if (oldVersion < 5) await _createLocalReceiptTime(db);
            if (oldVersion < 6) {
              // Reading history before this feature was not tracked. Start with
              // old conversations read, and count new arrivals after upgrading.
              await db.execute('''INSERT OR IGNORE INTO settings(key, value)
                SELECT 'chatRead:' || senderId, CAST(MAX(rowid) AS TEXT)
                FROM messages GROUP BY senderId''');
            }
          },
          onCreate: (db, _) async {
            await _createRelaySeen(db);
            await db.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE peers (id TEXT PRIMARY KEY, name TEXT NOT NULL)',
            );
            await db.execute('''CREATE TABLE messages (
            id TEXT PRIMARY KEY, senderId TEXT NOT NULL, senderName TEXT NOT NULL,
            receiverId TEXT NOT NULL, text TEXT NOT NULL, timestamp TEXT NOT NULL,
            type TEXT NOT NULL, status TEXT NOT NULL, ackFor TEXT)''');
            await db.execute(
              'CREATE INDEX outbox ON messages(senderId, receiverId, status)',
            );
            await SosStore.createSchema(db);
            await _createMediaSchema(db);
            await _createLocalReceiptTime(db);
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  static Future<void> _createRelaySeen(Database db) =>
      db.execute('CREATE TABLE relay_seen (id TEXT PRIMARY KEY)');

  static Future<void> _createLocalReceiptTime(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(messages)');
    if (!columns.any((column) => column['name'] == 'recordedAt')) {
      await db.execute('ALTER TABLE messages ADD COLUMN recordedAt TEXT');
    }
    // Leave old receipt times unknown; reconstruct their order using SQLite rowid.
    // A trigger covers text, SOS, media and account-import insert paths equally.
    await db.execute(
      '''CREATE TRIGGER IF NOT EXISTS message_local_time AFTER INSERT ON messages
      BEGIN
        UPDATE messages SET recordedAt = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
        WHERE rowid = NEW.rowid;
      END''',
    );
  }

  static Future<void> _createMediaSchema(Database db) => db.execute('''
    CREATE TABLE media_files (
      mediaId       TEXT PRIMARY KEY,
      messageId     TEXT NOT NULL,
      senderId      TEXT NOT NULL,
      senderName    TEXT NOT NULL DEFAULT '',
      receiverId    TEXT NOT NULL,
      fileName      TEXT NOT NULL,
      mimeType      TEXT NOT NULL,
      fileSize      INTEGER NOT NULL,
      checksum      TEXT NOT NULL,
      localPath     TEXT NOT NULL,
      createdAt     TEXT NOT NULL,
      bytesTransferred INTEGER NOT NULL DEFAULT 0,
      status        TEXT NOT NULL,
      retryCount    INTEGER NOT NULL DEFAULT 0,
      errorMessage  TEXT
    )
  ''');

  /// Atomic across concurrent arrivals and retained across restarts.
  Future<bool> claimRelay(String id) async {
    return (await database).transaction((txn) async {
      final existing = await txn.query(
        'relay_seen',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
      await txn.insert('relay_seen', {'id': id});
      return true;
    });
  }

  Future<String> getDeviceId() async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['deviceId'],
      );
      if (rows.isNotEmpty) return rows.single['value'] as String;
      final id = const Uuid().v4();
      await txn.insert('settings', {'key': 'deviceId', 'value': id});
      return id;
    });
  }

  Future<void> savePeer(String id, String name) async =>
      (await database).insert('peers', {
        'id': id,
        'name': name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<String?> getSetting(String key) async {
    final rows = await (await database).query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  /// Keep the first observed inbound path, not a claimed end-to-end receipt.
  Future<void> saveReceivedRoute(String id, List<String> route) async {
    await (await database).insert('settings', {
      'key': 'receivedRoute:$id',
      'value': jsonEncode(route),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, List<String>>> getReceivedRoutes() async => {
    for (final row in await (await database).query(
      'settings',
      where: 'key LIKE ?',
      whereArgs: ['receivedRoute:%'],
    ))
      (row['key'] as String).substring(
        'receivedRoute:'.length,
      ): List<String>.unmodifiable(
        (jsonDecode(row['value'] as String) as List).cast<String>(),
      ),
  };

  Future<void> setSetting(String key, String value) async {
    await (await database).insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveSos(String state, List<MessageModel> packets) async {
    await (await database).transaction((txn) async {
      await SosStore.savePublished(txn, state);
      await txn.insert('settings', {
        'key': 'mySos',
        'value': state,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final packet in packets) {
        await txn.insert('messages', packet.toMap());
      }
    });
  }

  Future<Map<String, String>> getPeers() async => {
    for (final row in await (await database).query('peers'))
      row['id'] as String: row['name'] as String,
  };
  Future<bool> insertMessage(MessageModel message) async {
    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'messages',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [message.id],
      );
      await txn.insert(
        'messages',
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final rows = await txn.query(
        'messages',
        where: 'id = ?',
        whereArgs: [message.id],
      );
      final saved = MessageModel.fromMap(rows.single);
      if (saved.senderId != message.senderId ||
          saved.receiverId != message.receiverId ||
          saved.text != message.text ||
          saved.type != message.type ||
          saved.senderName != message.senderName ||
          saved.ackFor != message.ackFor ||
          !saved.timestamp.isAtSameMomentAs(message.timestamp)) {
        throw StateError('Conflicting message ID');
      }
      return existing.isEmpty;
    });
  }

  // Conditional updates prevent a fast ACK being overwritten by SENT.
  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    final previous = MessageStatus.values
        .take(status.index)
        .map((s) => s.name)
        .toList();
    if (previous.isEmpty) return;
    await (await database).update(
      'messages',
      {'status': status.name},
      where:
          'id = ? AND status IN (${List.filled(previous.length, '?').join(',')})',
      whereArgs: [id, ...previous],
    );
  }

  Future<List<MessageModel>> getMessages() async =>
      (await (await database).query(
        'messages',
        orderBy: 'rowid ASC',
      )).map(MessageModel.fromMap).toList();

  Future<Map<String, int>> getUnreadCounts(String myId) async => {
    for (final row in await (await database).rawQuery(
      '''
      SELECT m.senderId AS peer, COUNT(*) AS total FROM messages m
      WHERE m.receiverId = ? AND m.senderId != ?
        AND m.type IN ('message', 'media', 'sos')
        AND m.rowid > COALESCE((SELECT CAST(value AS INTEGER) FROM settings
          WHERE key = 'chatRead:' || m.senderId), 0)
      GROUP BY m.senderId''',
      [myId, myId],
    ))
      row['peer'] as String: (row['total'] as num).toInt(),
  };

  Future<void> markConversationRead(
    String myId,
    String peerId,
    String messageId,
  ) async {
    await (await database).transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT rowid AS position FROM messages WHERE id = ? AND senderId = ? AND receiverId = ?',
        [messageId, peerId, myId],
      );
      if (rows.isEmpty) return;
      final position = (rows.single['position'] as num).toInt();
      final key = 'chatRead:$peerId';
      final saved = await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      final previous = saved.isEmpty
          ? 0
          : int.tryParse(saved.single['value'] as String) ?? 0;
      if (position <= previous) return;
      await txn.insert('settings', {
        'key': key,
        'value': '$position',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<MessageModel>> getConversation({
    required String myId,
    required String peerId,
  }) async => (await getMessages())
      .where(
        (m) =>
            (m.senderId == myId && m.receiverId == peerId) ||
            (m.senderId == peerId && m.receiverId == myId),
      )
      .toList();
  // ─── Media CRUD ───────────────────────────────────────────────────────────

  Future<bool> saveMediaMessage(MediaFile media, MessageModel message) async {
    return (await database).transaction((txn) async {
      final rows = await txn.query(
        'messages',
        where: 'id = ?',
        whereArgs: [message.id],
      );
      if (rows.isNotEmpty) {
        final saved = MessageModel.fromMap(rows.single);
        if (saved.senderId != message.senderId ||
            saved.receiverId != message.receiverId ||
            saved.text != message.text ||
            saved.type != message.type ||
            saved.senderName != message.senderName ||
            saved.timestamp != message.timestamp) {
          throw StateError('Conflicting media message ID');
        }
        await txn.insert(
          'media_files',
          media.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return false;
      }
      await txn.insert(
        'media_files',
        media.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('messages', message.toMap());
      return true;
    });
  }

  /// แทรก MediaFile ใหม่ — ถ้า mediaId ซ้ำให้ข้ามเพื่อป้องกัน duplicate
  Future<void> insertMediaFile(MediaFile media) async {
    await (await database).insert(
      'media_files',
      media.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// อัพเดตสถานะและ fields ของ MediaFile ที่มีอยู่แล้ว
  Future<void> updateMediaFile(MediaFile media) async {
    await (await database).update(
      'media_files',
      media.toMap(),
      where: 'mediaId = ?',
      whereArgs: [media.mediaId],
    );
  }

  Future<MediaFile?> getMediaFile(String mediaId) async {
    final rows = await (await database).query(
      'media_files',
      where: 'mediaId = ?',
      whereArgs: [mediaId],
    );
    return rows.isEmpty ? null : MediaFile.fromMap(rows.single);
  }

  Future<MediaFile?> getMediaForMessage(String messageId) async {
    final rows = await (await database).query(
      'media_files',
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
    return rows.isEmpty ? null : MediaFile.fromMap(rows.single);
  }

  /// โหลดสื่อทั้งหมด — ใช้ตอนเริ่มต้นแอปเพื่อ rebuild in-memory cache
  Future<List<MediaFile>> getAllMedia() async {
    final rows = await (await database).query(
      'media_files',
      orderBy: 'createdAt DESC',
    );
    return rows.map(MediaFile.fromMap).toList();
  }

  // ─── Core ─────────────────────────────────────────────────────────────────

  Future<void> close() async {
    await (await database).close();
    _opening = null;
  }
}
