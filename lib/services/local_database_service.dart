import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';

class LocalDatabaseService {
  LocalDatabaseService({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;
  static final instance = LocalDatabaseService();
  final DatabaseFactory _factory;
  final String? path;
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async {
    try {
      return await _factory.openDatabase(
        path ?? p.join(await _factory.getDatabasesPath(), 'rescuelink.db'),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
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
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
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

  Future<void> setSetting(String key, String value) async {
    await (await database).insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveSos(String state, List<MessageModel> packets) async {
    await (await database).transaction((txn) async {
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
  Future<void> insertMessage(MessageModel message) async {
    final db = await database;
    await db.transaction((txn) async {
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
        orderBy: 'timestamp ASC, id ASC',
      )).map(MessageModel.fromMap).toList();
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
  Future<void> close() async {
    await (await database).close();
    _opening = null;
  }
}
