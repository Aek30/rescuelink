import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/sos_alert.dart';
import 'local_database_service.dart';

class SosRecord {
  SosRecord.fromMap(Map<String, Object?> row)
    : alert = SosAlert.fromJson(row['payload'] as String),
      version = row['version'] as int,
      deleted = row['deleted'] == 1,
      conflict = row['conflict'] as String?;
  final SosAlert alert;
  final int version;
  final bool deleted;
  final String? conflict;
}

class SosStore {
  SosStore(this.database);
  final LocalDatabaseService database;

  static Future<void> createSchema(Database db) async {
    await db.execute('''CREATE TABLE sos_records (
      id TEXT PRIMARY KEY, payload TEXT NOT NULL, version INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0, conflict TEXT)''');
    await db.execute('''CREATE TABLE sos_queue (
      seq INTEGER PRIMARY KEY AUTOINCREMENT, operation_id TEXT NOT NULL UNIQUE,
      record_id TEXT NOT NULL, base_version INTEGER NOT NULL,
      payload TEXT NOT NULL, deleted INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, error TEXT,
      blocked INTEGER NOT NULL DEFAULT 0)''');
    await db.execute(
      'CREATE INDEX sos_queue_record ON sos_queue(record_id, seq)',
    );
    final old = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['mySos'],
    );
    if (old.isNotEmpty) await savePublished(db, old.single['value'] as String);
  }

  static Future<void> savePublished(DatabaseExecutor db, String state) async {
    final saved = jsonDecode(state) as Map<String, dynamic>;
    await _save(db, SosAlert.fromJson(saved['alert'] as String));
  }

  static Future<void> _save(
    DatabaseExecutor db,
    SosAlert alert, {
    bool deleted = false,
  }) async {
    final rows = await db.query(
      'sos_records',
      where: 'id = ?',
      whereArgs: [alert.incidentId],
    );
    final previous = rows.isEmpty ? null : SosRecord.fromMap(rows.single);
    if (previous?.conflict != null) {
      throw StateError('กรุณาจัดการข้อมูลขัดแย้งก่อนแก้ไข');
    }
    if (previous?.deleted == true) throw StateError('เหตุนี้ถูกลบแล้ว');
    if (previous != null && alert.revision <= previous.alert.revision) {
      throw StateError('ข้อมูลเปลี่ยนแล้ว กรุณาเปิดเหตุใหม่');
    }
    if (previous != null && !previous.alert.active && alert.active) {
      throw StateError('เหตุนี้ยุติแล้ว กรุณาสร้างเหตุใหม่');
    }
    if (deleted && (previous == null || previous.alert.active)) {
      throw StateError('ลบได้เฉพาะเหตุที่ยุติแล้ว');
    }
    final base = previous?.version ?? 0;
    await db.insert('sos_records', {
      'id': alert.incidentId,
      'payload': alert.toJson(),
      'version': base + 1,
      'deleted': deleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('sos_queue', {
      'operation_id': const Uuid().v4(),
      'record_id': alert.incidentId,
      'base_version': base,
      'payload': alert.toJson(),
      'deleted': deleted ? 1 : 0,
    });
  }

  Future<List<SosRecord>> list({bool includeDeleted = false}) async =>
      (await (await database.database).query(
        'sos_records',
        where: includeDeleted ? null : 'deleted = 0 OR conflict IS NOT NULL',
        orderBy: 'rowid DESC',
      )).map(SosRecord.fromMap).toList();

  Future<List<Map<String, Object?>>> queue() async =>
      (await database.database).query('sos_queue', orderBy: 'seq');

  Future<void> editClosed(SosAlert alert, {bool delete = false}) async {
    await (await database.database).transaction((txn) async {
      final rows = await txn.query(
        'sos_records',
        where: 'id = ?',
        whereArgs: [alert.incidentId],
      );
      if (rows.isEmpty) throw StateError('ไม่พบเหตุ SOS');
      final current = SosRecord.fromMap(rows.single);
      if (current.alert.active || alert.active) {
        throw StateError('แก้ไขประวัติได้เฉพาะเหตุที่ยุติแล้ว');
      }
      if (alert.revision != current.alert.revision + 1) {
        throw StateError('ข้อมูลเปลี่ยนแล้ว กรุณาเปิดใหม่');
      }
      await _save(txn, alert, deleted: delete);
    });
  }

  Future<void> acknowledge(
    Map<String, Object?> operation,
    Map<String, dynamic> result,
  ) async {
    await (await database.database).transaction((txn) async {
      final queued = await txn.query(
        'sos_queue',
        where: 'operation_id = ?',
        whereArgs: [operation['operation_id']],
        limit: 1,
      );
      if (queued.isEmpty) return;
      final id = operation['record_id'];
      if (result['outcome'] == 'conflict') {
        await txn.update(
          'sos_records',
          {'conflict': jsonEncode(result['record'])},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.update(
          'sos_queue',
          {'blocked': 1, 'error': 'ข้อมูลขัดแย้ง'},
          where: 'record_id = ?',
          whereArgs: [id],
        );
      } else if (result['outcome'] == 'applied') {
        await txn.delete(
          'sos_queue',
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
          'sos_queue',
          where: 'record_id = ?',
          whereArgs: [remote['id']],
          limit: 1,
        );
        if (pending.isNotEmpty) continue;
        await _putRemote(txn, remote);
      }
    });
  }

  static Future<void> _putRemote(
    DatabaseExecutor txn,
    Map<String, dynamic> remote,
  ) async {
    final alert = SosAlert.fromJson(jsonEncode(remote['payload']));
    if (alert.incidentId != remote['id']) {
      throw const FormatException('Invalid remote ID');
    }
    await txn.insert('sos_records', {
      'id': remote['id'],
      'payload': alert.toJson(),
      'version': remote['version'],
      'deleted': remote['deleted'] == true ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _updateCurrent(txn, alert);
  }

  static Future<void> _updateCurrent(
    DatabaseExecutor txn,
    SosAlert alert,
  ) async {
    final saved = await txn.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['mySos'],
    );
    if (saved.isEmpty) return;
    final state =
        jsonDecode(saved.single['value'] as String) as Map<String, dynamic>;
    if (SosAlert.fromJson(state['alert'] as String).incidentId !=
        alert.incidentId) {
      return;
    }
    state['alert'] = alert.toJson();
    await txn.update(
      'settings',
      {'value': jsonEncode(state)},
      where: 'key = ?',
      whereArgs: ['mySos'],
    );
  }

  Future<void> resolve(String id, {required bool keepLocal}) async {
    await (await database.database).transaction((txn) async {
      final row = (await txn.query(
        'sos_records',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      final local = SosRecord.fromMap(row);
      if (local.conflict == null) return;
      final remote = jsonDecode(local.conflict!) as Map<String, dynamic>?;
      final remoteAlert = remote == null
          ? null
          : SosAlert.fromJson(jsonEncode(remote['payload']));
      if (keepLocal &&
          remoteAlert != null &&
          ((!remoteAlert.active && local.alert.active) ||
              (remoteAlert.active && local.deleted))) {
        throw StateError('สถานะเหตุเปลี่ยนแล้ว กรุณาใช้ข้อมูล Cloud ก่อน');
      }
      if (keepLocal && remote?['deleted'] == true) {
        throw StateError('Cloud ลบเหตุนี้แล้ว กรุณาใช้ข้อมูล Cloud');
      }
      await txn.delete('sos_queue', where: 'record_id = ?', whereArgs: [id]);
      if (keepLocal) {
        final revision = local.alert.revision > (remoteAlert?.revision ?? 0)
            ? local.alert.revision + 1
            : remoteAlert!.revision + 1;
        final resolved = SosAlert(
          incidentId: id,
          revision: revision,
          active: local.alert.active,
          name: local.alert.name,
          people: local.alert.people,
          category: local.alert.category,
          details: local.alert.details,
          location: local.alert.location,
          updatedAt: DateTime.now().toUtc(),
        );
        await txn.update(
          'sos_records',
          {
            'version': (remote?['version'] as int? ?? 0) + 1,
            'conflict': null,
            'payload': resolved.toJson(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert('sos_queue', {
          'operation_id': const Uuid().v4(),
          'record_id': id,
          'base_version': remote?['version'] ?? 0,
          'payload': resolved.toJson(),
          'deleted': local.deleted ? 1 : 0,
        });
        await _updateCurrent(txn, resolved);
      } else if (remote != null) {
        await _putRemote(txn, remote);
      } else {
        await txn.delete('sos_records', where: 'id = ?', whereArgs: [id]);
      }
    });
  }
}
