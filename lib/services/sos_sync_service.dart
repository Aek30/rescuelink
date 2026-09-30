import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'auth_service.dart';
import 'local_database_service.dart';
import 'sos_store.dart';

abstract interface class SosCloud {
  Future<Map<String, dynamic>> push(Map<String, Object?> operation);
  Future<List<Map<String, dynamic>>> pull();
}

class SupabaseSosCloud implements SosCloud {
  SupabaseSosCloud(this.auth, this.owner);
  final AuthService auth;
  final String owner;
  @override
  Future<Map<String, dynamic>> push(Map<String, Object?> operation) async {
    final client = await auth.cloudClient(owner);
    return Map<String, dynamic>.from(
      await client.rpc(
            'sync_sos',
            params: {
              'operation': operation['operation_id'],
              'record_id': operation['record_id'],
              'base_version': operation['base_version'],
              'body': jsonDecode(operation['payload'] as String),
              'remove_record': operation['deleted'] == 1,
            },
          )
          as Map,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> pull() async {
    final client = await auth.cloudClient(owner);
    final records = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      if (auth.session?.userId != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
      final page = await client
          .from('sos_records')
          .select()
          .eq('owner_id', owner)
          .order('id')
          .range(offset, offset + 199);
      records.addAll(page);
      if (page.length < 200) return records;
    }
  }
}

class SosSyncService extends ChangeNotifier {
  SosSyncService(this.store, this.cloud);
  final SosStore store;
  final SosCloud? cloud;
  bool busy = false, _stopped = false;
  String? error;
  DateTime? lastSuccess;
  int pending = 0, conflicts = 0;
  void _notify() {
    if (!_stopped) notifyListeners();
  }

  Future<void> refreshStatus() async {
    final queue = await store.queue();
    pending = queue.length;
    conflicts = queue
        .where((r) => r['blocked'] == 1)
        .map((r) => r['record_id'])
        .toSet()
        .length;
    lastSuccess ??= DateTime.tryParse(
      await store.database.getSetting('sosLastSync') ?? '',
    );
    _notify();
  }

  Future<void> sync() async {
    if (busy || _stopped) return;
    busy = true;
    error = null;
    _notify();
    try {
      await refreshStatus();
      if (cloud == null) return;
      for (final operation in await store.queue()) {
        if (_stopped) return;
        final db = await store.database.database;
        final current = await db.query(
          'sos_queue',
          where: 'operation_id = ? AND blocked = 0',
          whereArgs: [operation['operation_id']],
        );
        if (current.isEmpty) continue;
        try {
          final result = await cloud!
              .push(operation)
              .timeout(const Duration(seconds: 20));
          await store.acknowledge(operation, result);
        } catch (_) {
          await db.rawUpdate(
            'UPDATE sos_queue SET attempts = attempts + 1, error = ? WHERE operation_id = ?',
            ['เชื่อมต่อ Cloud ไม่สำเร็จ จะลองใหม่', operation['operation_id']],
          );
          rethrow;
        }
      }
      if (_stopped) return;
      await store.mergeRemote(
        await cloud!.pull().timeout(const Duration(seconds: 20)),
      );
      lastSuccess = DateTime.now();
      await store.database.setSetting(
        'sosLastSync',
        lastSuccess!.toUtc().toIso8601String(),
      );
    } catch (_) {
      error =
          'ซิงก์ไม่สำเร็จ ข้อมูลยังอยู่ในเครื่อง ตรวจสอบอินเทอร์เน็ตหรือเข้าสู่ระบบใหม่';
    } finally {
      busy = false;
      try {
        await refreshStatus();
      } catch (_) {
        error = 'อ่านคิวซิงก์ไม่สำเร็จ กรุณาลองใหม่';
      }
      _notify();
    }
  }

  @override
  void dispose() {
    _stopped = true;
    super.dispose();
  }
}

class SosSyncCoordinator extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = SosSyncCoordinator();
  SosSyncService? current;
  Timer? _timer;
  String? _owner;
  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    AuthService.instance.addListener(_scopeChanged);
    _scopeChanged();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(current?.sync()),
    );
  }

  void _scopeChanged() {
    final owner = AuthService.instance.session?.userId;
    final db = LocalDatabaseService.instance;
    if (_owner == owner && identical(current?.store.database, db)) return;
    current?.removeListener(notifyListeners);
    current?.dispose();
    _owner = owner;
    current = SosSyncService(
      SosStore(db),
      owner == null ? null : SupabaseSosCloud(AuthService.instance, owner),
    );
    current!.addListener(notifyListeners);
    notifyListeners();
    unawaited(current!.sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(current?.sync());
  }
}
