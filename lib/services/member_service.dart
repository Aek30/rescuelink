import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'local_database_service.dart';
import 'app_preferences.dart';

class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.email,
    required this.name,
    this.pending = false,
    this.offline = false,
    this.syncError,
  });
  final String id, email, name;
  final bool pending, offline;
  final String? syncError;
}

abstract interface class MemberRepository {
  Future<MemberProfile> read();
  Future<MemberProfile> updateName(String name);
  Future<void> deleteAccount(String password);
}

class SupabaseMemberRepository implements MemberRepository {
  SupabaseMemberRepository(this.auth, {this.localDatabase});
  final AuthService auth;
  final LocalDatabaseService? localDatabase;
  static final _uploads = <LocalDatabaseService, Future<MemberProfile>>{};

  String get _owner =>
      auth.session?.userId ?? (throw StateError('กรุณาเข้าสู่ระบบก่อน'));

  void _check(String owner, LocalDatabaseService database) {
    if (auth.session?.userId != owner ||
        (localDatabase == null &&
            !identical(database, LocalDatabaseService.instance))) {
      throw StateError('บัญชีเปลี่ยนแล้ว');
    }
  }

  Future<MemberProfile> _local(
    String owner,
    LocalDatabaseService database, {
    bool offline = false,
    String? syncError,
  }) async {
    final db = await database.database;
    final settings = await db.query(
      'settings',
      where: 'key IN (?, ?)',
      whereArgs: ['profileNameDraft', 'profileDisplayName'],
    );
    _check(owner, database);
    final values = {for (final row in settings) row['key']: row['value']};
    return MemberProfile(
      id: owner,
      email: auth.session!.email,
      name:
          (values['profileNameDraft'] ?? values['profileDisplayName'] ?? '')
              as String,
      pending: values['profileNameDraft'] != null,
      offline: offline,
      syncError: syncError,
    );
  }

  Future<MemberProfile> readLocal() {
    final owner = _owner;
    final database = localDatabase ?? LocalDatabaseService.instance;
    return _local(owner, database);
  }

  @override
  Future<MemberProfile> read() async {
    final owner = _owner;
    final database = localDatabase ?? LocalDatabaseService.instance;
    final cached = await _local(owner, database);
    if (cached.pending) return syncPending();
    try {
      final client = await auth
          .cloudClient(owner)
          .timeout(const Duration(seconds: 20));
      _check(owner, database);
      final row = await client
          .from('profiles')
          .select('id, display_name')
          .eq('id', owner)
          .single()
          .timeout(const Duration(seconds: 15));
      _check(owner, database);
      final db = await database.database;
      await db.transaction((txn) async {
        _check(owner, database);
        final current = await txn.query(
          'settings',
          where: 'key IN (?, ?)',
          whereArgs: ['profileNameDraft', 'profileDisplayName'],
        );
        final values = {for (final row in current) row['key']: row['value']};
        // A GET started before a save must not replace its newer confirmed cache.
        if (values['profileNameDraft'] == null &&
            (values['profileDisplayName'] ?? '') == cached.name) {
          await txn.rawInsert(
            'INSERT OR REPLACE INTO settings(key, value) VALUES (?, ?)',
            ['profileDisplayName', row['display_name'] as String],
          );
        }
      });
      if (localDatabase == null) await AppPreferences.instance.load();
      return await _local(owner, database);
    } catch (e) {
      _check(owner, database);
      return _local(owner, database, offline: true, syncError: memberError(e));
    }
  }

  @override
  Future<MemberProfile> updateName(String name) async {
    name = name.trim();
    if (name.isEmpty || name.length > 80) {
      throw StateError('กรุณาระบุชื่อ 1–80 ตัวอักษร');
    }
    final owner = _owner;
    final database = localDatabase ?? LocalDatabaseService.instance;
    final db = await database.database;
    _check(owner, database);
    await db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR REPLACE INTO settings(key, value) VALUES (?, ?)',
        ['profileNameDraft', name],
      );
      await txn.rawInsert(
        'INSERT OR REPLACE INTO settings(key, value) VALUES (?, ?)',
        ['profileNameDraftRevision', const Uuid().v4()],
      );
    });
    _check(owner, database);
    if (localDatabase == null) await AppPreferences.instance.load();
    return syncPending();
  }

  Future<MemberProfile> syncPending() async {
    final owner = _owner;
    final database = localDatabase ?? LocalDatabaseService.instance;
    final previous = _uploads[database];
    if (previous != null) {
      await previous;
      _check(owner, database);
      return syncPending();
    }
    final upload = _sync(owner, database);
    _uploads[database] = upload;
    try {
      return await upload;
    } finally {
      if (identical(_uploads[database], upload)) _uploads.remove(database);
    }
  }

  Future<MemberProfile> _sync(
    String owner,
    LocalDatabaseService database,
  ) async {
    final db = await database.database;
    final snapshot = await db.query(
      'settings',
      where: 'key IN (?, ?)',
      whereArgs: ['profileNameDraft', 'profileNameDraftRevision'],
    );
    final values = {for (final row in snapshot) row['key']: row['value']};
    final draft = values['profileNameDraft'] as String?;
    final revision = values['profileNameDraftRevision'];
    _check(owner, database);
    if (draft == null) return _local(owner, database);
    try {
      final client = await auth
          .cloudClient(owner)
          .timeout(const Duration(seconds: 20));
      _check(owner, database);
      final row = await client
          .from('profiles')
          .update({'display_name': draft})
          .eq('id', owner)
          .select('id, display_name')
          .single()
          .timeout(const Duration(seconds: 15));
      _check(owner, database);
      if (row['id'] != owner || row['display_name'] != draft) {
        throw StateError('Cloud ยังไม่ยืนยันชื่อที่บันทึก');
      }
      await db.transaction((txn) async {
        _check(owner, database);
        final current = await txn.query(
          'settings',
          where: 'key IN (?, ?)',
          whereArgs: ['profileNameDraft', 'profileNameDraftRevision'],
        );
        final values = {for (final row in current) row['key']: row['value']};
        await txn.rawInsert(
          'INSERT OR REPLACE INTO settings(key, value) VALUES (?, ?)',
          ['profileDisplayName', draft],
        );
        // A late response must never clear a newer draft (including A → B → A).
        if (values['profileNameDraft'] == draft &&
            values['profileNameDraftRevision'] == revision) {
          await txn.delete(
            'settings',
            where: 'key IN (?, ?)',
            whereArgs: ['profileNameDraft', 'profileNameDraftRevision'],
          );
        }
      });
      _check(owner, database);
      if (localDatabase == null) await AppPreferences.instance.load();
      return await _local(owner, database);
    } catch (e) {
      _check(owner, database);
      return _local(owner, database, offline: true, syncError: memberError(e));
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    if (password.isEmpty) throw StateError('กรุณากรอกรหัสผ่านเพื่อยืนยัน');
    final owner = _owner;
    final client = await auth.cloudClient(owner);
    final response = await client.functions.invoke(
      'delete-account',
      body: {'password': password, 'confirmation': 'DELETE'},
    );
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['deleted'] != true) {
      throw StateError('ลบบัญชีไม่สำเร็จ กรุณาลองใหม่');
    }
    if (auth.session?.userId != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
    await auth.signOut();
    if (auth.backend is SupabaseAuthBackend) {
      await (auth.backend as SupabaseAuthBackend).profiles.vault.remove(owner);
    }
    await auth.storage.removeOwner(owner);
  }
}

String memberError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FunctionException) {
    if (error.status == 401) return 'session หมดอายุ กรุณาเข้าสู่ระบบใหม่';
    if (error.status == 403) return 'รหัสผ่านไม่ถูกต้อง บัญชียังไม่ถูกลบ';
    return 'ลบบัญชีไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
  }
  return 'ติดต่อฐานข้อมูลไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
}
