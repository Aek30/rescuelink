import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/media_model.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
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
          version: 8,
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
            if (oldVersion < 7) await _createRelayQueueSchema(db);
            if (oldVersion < 8) await _upgradeRelayQueues(db);
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
            await _createRelayQueueSchema(db);
            await _upgradeRelayQueues(db);
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

  static Future<void> _createRelayQueueSchema(Database db) async {
    await db.execute('''
      CREATE TABLE relay_queue (
        seq          INTEGER PRIMARY KEY AUTOINCREMENT,
        packet_id    TEXT NOT NULL,
        payload      TEXT NOT NULL,
        dest_peer    TEXT NOT NULL,
        attempts     INTEGER NOT NULL DEFAULT 0,
        next_attempt TEXT,
        created_at   TEXT NOT NULL
      )''');
    await db.execute(
      'CREATE UNIQUE INDEX relay_queue_packet ON relay_queue(packet_id, dest_peer)',
    );
    await db.execute('''
      CREATE TABLE relay_ack_queue (
        seq         INTEGER PRIMARY KEY AUTOINCREMENT,
        ack_for     TEXT NOT NULL,
        payload     TEXT NOT NULL,
        dest_peer   TEXT NOT NULL,
        attempts    INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL
      )''');
    await db.execute(
      'CREATE UNIQUE INDEX relay_ack_packet ON relay_ack_queue(ack_for)',
    );
  }

  static Future<void> _upgradeRelayQueues(Database db) async {
    // Add fields without deleting/rebuilding any pending jobs. Version 7 rows
    // keep their neighbor keys; routing reads the destination from the payload.
    await db.execute('ALTER TABLE relay_queue ADD COLUMN ack_payload TEXT');
    await db.execute(
      'ALTER TABLE relay_ack_queue ADD COLUMN next_attempt TEXT',
    );
    final acks = await db.query('relay_ack_queue');
    for (final job in acks) {
      final data = jsonDecode(job['payload'] as String) as Map<String, dynamic>;
      if (!data.containsKey('relayAckRoute')) {
        final route = (data['relayPath'] as List).cast<String>();
        data['relayAckRoute'] = route;
        data['relayPath'] = [route.first];
        await db.update(
          'relay_ack_queue',
          {'payload': jsonEncode(data)},
          where: 'seq = ?',
          whereArgs: [job['seq']],
        );
      }
    }
  }

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

  // ─── Relay Queue (Phase 5 Part 2) ────────────────────────────────────────

  /// Persist the packet and seen marker together, even without a next hop.
  /// Retransmissions can repair legacy seen-only entries that have no job.
  Future<bool> enqueueRelay({
    required String packetId,
    required String payload,
    required String destPeer,
  }) async {
    return (await database).transaction((txn) async {
      final existing = await txn.query(
        'relay_queue',
        where: 'packet_id = ?',
        whereArgs: [packetId],
      );
      if (existing.isNotEmpty) {
        final previous = MessageModel.fromJson(
          existing.first['payload'] as String,
        );
        final incoming = MessageModel.fromJson(payload);
        final before = previous.toMap()..remove('status');
        final after = incoming.toMap()..remove('status');
        if (jsonEncode(before) != jsonEncode(after)) {
          throw const FormatException('Conflicting relay packet ID');
        }
        return false;
      }
      await txn.insert('relay_seen', {
        'id': packetId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('relay_queue', {
        'packet_id': packetId,
        'payload': payload,
        'dest_peer': destPeer,
        'attempts': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    });
  }

  /// ดึงรายการที่พร้อม retry (next_attempt IS NULL หรือ next_attempt <= now)
  Future<List<Map<String, Object?>>> retryableRelayItems([
    String? destPeer,
  ]) async {
    return (await database).rawQuery(
      '''SELECT * FROM relay_queue
         WHERE ack_payload IS NULL
           AND (next_attempt IS NULL OR next_attempt <= ?)
           ${destPeer == null ? '' : 'AND dest_peer = ?'}
         ORDER BY seq''',
      [DateTime.now().toUtc().toIso8601String(), ?destPeer],
    );
  }

  /// อัปเดต attempt count และ next_attempt (exponential backoff)
  Future<void> markRelayAttempt(int seq, int attempts) async {
    final backoffSeconds = (5 * (1 << attempts.clamp(0, 6))).clamp(5, 300);
    final next = DateTime.now()
        .toUtc()
        .add(Duration(seconds: backoffSeconds))
        .toIso8601String();
    await (await database).update(
      'relay_queue',
      {'attempts': attempts + 1, 'next_attempt': next},
      where: 'seq = ?',
      whereArgs: [seq],
    );
  }

  /// Delete only jobs no longer needed; a native send alone is not delivery.
  Future<void> deleteRelayItem(int seq) async {
    await (await database).delete(
      'relay_queue',
      where: 'seq = ?',
      whereArgs: [seq],
    );
  }

  // ─── Relay ACK Queue (Phase 5 Part 2) ───────────────────────────────────

  /// บันทึก ACK รอส่งกลับ (เมื่อเส้นทางยังขาด)
  Future<bool> enqueueRelayAck({
    required String ackFor,
    required String payload,
    required String destPeer,
  }) async {
    return (await database).transaction(
      (txn) => _enqueueRelayAck(
        txn,
        ackFor: ackFor,
        payload: payload,
        destPeer: destPeer,
      ),
    );
  }

  static Future<bool> _enqueueRelayAck(
    DatabaseExecutor db, {
    required String ackFor,
    required String payload,
    required String destPeer,
  }) async {
    final existing = await db.query(
      'relay_ack_queue',
      where: 'ack_for = ?',
      whereArgs: [ackFor],
    );
    if (existing.isNotEmpty) return false;
    await db.insert('relay_ack_queue', {
      'ack_for': ackFor,
      'payload': payload,
      'dest_peer': destPeer,
      'attempts': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return true;
  }

  Future<Map<String, Object?>?> relayItem(String packetId) async {
    final rows = await (await database).query(
      'relay_queue',
      where: 'packet_id = ?',
      whereArgs: [packetId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Cache the receipt and queue its return hop in one transaction. A repeated
  /// data packet can replay the receipt if a native ACK send was lost.
  Future<bool> acceptRelayAck({
    required MessageModel ack,
    required String payload,
    required String destPeer,
  }) async {
    return (await database).transaction((txn) async {
      final rows = await txn.query(
        'relay_queue',
        where: 'packet_id = ?',
        whereArgs: [ack.ackFor],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final original = MessageModel.fromJson(rows.first['payload'] as String);
      if (original.senderId != ack.receiverId ||
          original.receiverId != ack.senderId) {
        return false;
      }
      await txn.update(
        'relay_queue',
        {'ack_payload': payload},
        where: 'packet_id = ?',
        whereArgs: [ack.ackFor],
      );
      await _enqueueRelayAck(
        txn,
        ackFor: ack.ackFor!,
        payload: payload,
        destPeer: destPeer,
      );
      return true;
    });
  }

  Future<void> markRelayAckAttempt(int seq, int attempts) async {
    final seconds = (5 * (1 << attempts.clamp(0, 6))).clamp(5, 300);
    await (await database).update(
      'relay_ack_queue',
      {
        'attempts': attempts + 1,
        'next_attempt': DateTime.now()
            .toUtc()
            .add(Duration(seconds: seconds))
            .toIso8601String(),
      },
      where: 'seq = ?',
      whereArgs: [seq],
    );
  }

  Future<void> resetRelayBackoff() async {
    final db = await database;
    await db.update('relay_queue', {'next_attempt': null});
    await db.update('relay_ack_queue', {'next_attempt': null});
  }

  /// ดึง ACK ที่ค้างสำหรับ peer นี้
  Future<List<Map<String, Object?>>> pendingRelayAcks(String destPeer) async {
    return (await database).query(
      'relay_ack_queue',
      where: 'dest_peer = ? AND (next_attempt IS NULL OR next_attempt <= ?)',
      whereArgs: [destPeer, DateTime.now().toUtc().toIso8601String()],
      orderBy: 'seq',
    );
  }

  /// ลบ ACK หลังส่งสำเร็จ
  Future<void> deleteRelayAckItem(int seq) async {
    await (await database).delete(
      'relay_ack_queue',
      where: 'seq = ?',
      whereArgs: [seq],
    );
  }

  // ─── Relay TTL Cleanup ───────────────────────────────────────────────────

  /// ลบรายการคิวที่เกิน 48 ชั่วโมง เรียกตอนเปิดแอปและทุก 6 ชั่วโมง
  Future<void> cleanupExpiredRelayItems() async {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 48))
        .toIso8601String();
    final db = await database;
    await db.delete(
      'relay_queue',
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );
    await db.delete(
      'relay_ack_queue',
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );
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

  Future<void> savePeer(String id, String name) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('peers', {
        'id': id,
        'name': name,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'peers',
        {'name': name},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

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

  /// Keep revision tombstones independently of connection/presence freshness.
  /// Equal revisions never replace payload/updatedAt, so replay cannot extend
  /// an incident's expiry or undo a cancellation, including after restart.
  Future<bool> recordRemoteSos(String owner, SosAlert alert) async {
    final key = 'remoteSos:${jsonEncode([owner, alert.incidentId])}';
    return (await database).transaction((txn) async {
      final rows = await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (rows.isNotEmpty &&
          SosAlert.fromJson(rows.single['value'] as String).revision >=
              alert.revision) {
        return false;
      }
      await txn.insert('settings', {
        'key': key,
        'value': alert.toJson(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  Future<Map<String, Map<String, SosAlert>>> getRemoteSos() async {
    final result = <String, Map<String, SosAlert>>{};
    for (final row in await (await database).query(
      'settings',
      where: 'key LIKE ?',
      whereArgs: ['remoteSos:%'],
    )) {
      final ids = (jsonDecode((row['key'] as String).substring(10)) as List)
          .cast<String>();
      (result[ids[0]] ??= {})[ids[1]] = SosAlert.fromJson(
        row['value'] as String,
      );
    }
    return result;
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
    for (final row in await (await database).query(
      'peers',
      orderBy: 'rowid ASC',
    ))
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
