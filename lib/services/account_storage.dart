import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'local_database_service.dart';

/// The catalog maps an owner to a private local database. It contains no tokens.
/// Ownership transfer changes two catalog rows in one SQLite transaction;
/// message IDs, outbox, SOS and the radio identity stay together.
class AccountStorage {
  AccountStorage({this.factory, this.directory});
  final DatabaseFactory? factory;
  DatabaseFactory get _factory => factory ?? databaseFactory;
  final String? directory;
  Database? _catalog;
  final _handles = <String, LocalDatabaseService>{};
  String owner = 'guest';

  Future<Database>
  get catalog async => _catalog ??= await _factory.openDatabase(
    p.join(directory ?? await _factory.getDatabasesPath(), 'accounts.db'),
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE installation (id TEXT PRIMARY KEY)');
        await db.insert('installation', {'id': const Uuid().v4()});
        await db.execute(
          'CREATE TABLE owners (owner TEXT PRIMARY KEY, file TEXT NOT NULL UNIQUE)',
        );
        await db.insert('owners', {'owner': 'guest', 'file': 'rescuelink.db'});
      },
    ),
  );

  Future<String> get installationId async =>
      ((await (await catalog).query('installation')).single['id'] as String);

  Future<LocalDatabaseService> select(
    String? userId, {
    bool claimGuest = false,
  }) async {
    final target = userId == null ? 'guest' : 'user:$userId';
    if (claimGuest && userId == null) {
      throw StateError('A verified account is required');
    }
    final db = await catalog;
    final file = await db.transaction((txn) async {
      final existing = await txn.query(
        'owners',
        where: 'owner = ?',
        whereArgs: [target],
      );
      if (claimGuest) {
        // An established account is never overwritten or silently merged.
        if (existing.isNotEmpty) {
          throw StateError(
            'บัญชีนี้มีพื้นที่ข้อมูลแล้ว กรุณาเข้าสู่ระบบโดยไม่ผูกข้อมูล Guest',
          );
        }
        final guest = (await txn.query(
          'owners',
          where: 'owner = ?',
          whereArgs: ['guest'],
        )).single;
        final file = guest['file'] as String;
        await txn.update(
          'owners',
          {'file': '${const Uuid().v4()}.db'},
          where: 'owner = ?',
          whereArgs: ['guest'],
        );
        await txn.insert('owners', {'owner': target, 'file': file});
        return file;
      }
      if (existing.isNotEmpty) return existing.single['file'] as String;
      final file = '${const Uuid().v4()}.db';
      await txn.insert('owners', {'owner': target, 'file': file});
      return file;
    });
    final handle = _handles.putIfAbsent(
      file,
      () => LocalDatabaseService(
        factory: _factory,
        path: p.join(directory ?? p.dirname(db.path), file),
      ),
    );
    await handle.database; // Fail before activating an unusable scope.
    owner = target;
    return handle;
  }

  Future<void> removeOwner(String userId) async {
    final target = 'user:$userId';
    if (owner == target) throw StateError('ออกจากบัญชีก่อนลบข้อมูลในเครื่อง');
    final db = await catalog;
    final rows = await db.query(
      'owners',
      where: 'owner = ?',
      whereArgs: [target],
    );
    for (final row in rows) {
      final file = row['file'] as String;
      await _handles.remove(file)?.retire();
      await _factory.deleteDatabase(
        p.join(directory ?? p.dirname(db.path), file),
      );
    }
    await db.delete('owners', where: 'owner = ?', whereArgs: [target]);
  }

  Future<void> close() async {
    for (final handle in _handles.values) {
      await handle.close();
    }
    await _catalog?.close();
    _catalog = null;
    _handles.clear();
  }
}
