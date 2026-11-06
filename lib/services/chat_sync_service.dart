import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'auth_service.dart';
import 'auto_sync_trigger.dart';
import 'local_database_service.dart';
import 'chat_store.dart';
import 'chat_attachment_restore.dart';

abstract interface class ChatCloud {
  Future<Map<String, dynamic>> push(Map<String, Object?> operation);
  Future<List<Map<String, dynamic>>> pull();
}

class SupabaseChatCloud implements ChatCloud, ChatAttachmentCloud {
  SupabaseChatCloud(
    this.auth,
    this.owner, {
    LocalDatabaseService? database,
    this.attachments,
  }) : database = database ?? LocalDatabaseService.instance;
  final AuthService auth;
  final String owner;
  final LocalDatabaseService database;
  final ChatAttachmentRestore? attachments;
  @override
  Future<void> restoreAttachments(LocalDatabaseService database) =>
      (attachments ??
              ChatAttachmentRestore(SupabaseAttachmentArchive(auth, owner)))
          .restore(database);
  @override
  Future<Map<String, dynamic>> push(Map<String, Object?> operation) async {
    final client = await auth.cloudClient(owner);
    return Map<String, dynamic>.from(
      await client.rpc(
            'sync_chat',
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
    {
      await client.from('account_devices').upsert({
        'user_id': owner,
        'installation_id': await auth.storage.installationId,
        'radio_identity': await database.getDeviceId(),
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,installation_id');
      final radioIds = <String>{await database.getDeviceId()};
      for (var offset = 0; ; offset += 200) {
        if (auth.session?.userId != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
        final devices = await client
            .from('account_devices')
            .select('radio_identity')
            .eq('user_id', owner)
            .order('installation_id')
            .range(offset, offset + 199);
        for (final row in devices) {
          if (row['radio_identity'] is String &&
              (row['radio_identity'] as String).isNotEmpty) {
            radioIds.add(row['radio_identity'] as String);
          }
        }
        if (devices.length < 200) break;
      }
      if (radioIds.isNotEmpty) {
        if (auth.session?.userId != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
        await database.setSetting('myRadioIds', jsonEncode(radioIds.toList()));
      }
    }
    final records = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      if (auth.session?.userId != owner) throw StateError('บัญชีเปลี่ยนแล้ว');
      final page = await client
          .from('chat_records')
          .select()
          .eq('owner_id', owner)
          .order('id')
          .range(offset, offset + 199);
      records.addAll(page);
      if (page.length < 200) return records;
    }
  }
}

class ChatSyncService extends ChangeNotifier {
  ChatSyncService(this.store, this.cloud);
  final ChatStore store;
  final ChatCloud? cloud;
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
      await store.database.getSetting('chatLastSync') ?? '',
    );
    _notify();
  }

  Future<void> sync() async {
    if (busy || _stopped) return;
    busy = true;
    // Keep the last failure visible until a complete sync succeeds.
    _notify();
    try {
      await refreshStatus();
      if (cloud == null) return;
      await store.prepareForSync();
      var uploadFailed = false;
      final failedRecords = <Object?>{};
      for (final operation in await store.queue()) {
        if (_stopped) return;
        if (failedRecords.contains(operation['record_id'])) continue;
        final db = await store.database.database;
        final current = await db.query(
          'chat_queue',
          where: 'operation_id = ? AND blocked = 0',
          whereArgs: [operation['operation_id']],
        );
        if (current.isEmpty) continue;
        try {
          final result = await cloud!
              .push(operation)
              .timeout(const Duration(seconds: 20));
          await store.acknowledge(operation, result);
        } catch (failure, stack) {
          debugPrint('Chat sync push failed: $failure\n$stack');
          await db.rawUpdate(
            'UPDATE chat_queue SET attempts = attempts + 1, error = ? WHERE operation_id = ?',
            ['เชื่อมต่อ Cloud ไม่สำเร็จ จะลองใหม่', operation['operation_id']],
          );
          uploadFailed = true;
          failedRecords.add(operation['record_id']);
        }
      }
      if (_stopped) return;
      await store.mergeRemote(
        await cloud!.pull().timeout(const Duration(seconds: 20)),
      );
      if (_stopped) return;
      if (cloud case final ChatAttachmentCloud attachments) {
        await attachments.restoreAttachments(store.database);
      }
      if (uploadFailed) throw StateError('อัปโหลดประวัติบางรายการไม่สำเร็จ');
      lastSuccess = DateTime.now();
      await store.database.setSetting(
        'chatLastSync',
        lastSuccess!.toUtc().toIso8601String(),
      );
      error = null;
    } catch (failure, stack) {
      debugPrint('Chat sync failed: $failure\n$stack');
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

class ChatSyncCoordinator extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = ChatSyncCoordinator();
  ChatSyncService? current;
  bool _started = false;
  bool _syncAfterCurrent = false;
  late final _automatic = AutoSyncTrigger(sync: _syncAutomatically);

  Future<void> _syncAutomatically() async {
    final service = current;
    if (service == null) return;
    if (service.busy) {
      _syncAfterCurrent = true;
      return;
    }
    _syncAfterCurrent = false;
    await service.sync();
  }

  void _serviceChanged() {
    notifyListeners();
    if (_syncAfterCurrent && current?.busy == false) _automatic.requestSync();
  }

  String? _owner;
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    AuthService.instance.addListener(_scopeChanged);
    _scopeChanged();
    _automatic.start();
  }

  void _localChanged() {
    _syncAfterCurrent = true;
    _automatic.requestSync();
  }

  void _scopeChanged() {
    final owner = AuthService.instance.session?.userId;
    final db = LocalDatabaseService.instance;
    if (_owner == owner && identical(current?.store.database, db)) return;
    current?.store.database.syncRequested.removeListener(_localChanged);
    current?.removeListener(_serviceChanged);
    current?.dispose();
    _owner = owner;
    current = ChatSyncService(
      ChatStore(db),
      owner == null
          ? null
          : SupabaseChatCloud(AuthService.instance, owner, database: db),
    );
    current!.addListener(_serviceChanged);
    db.syncRequested.addListener(_localChanged);
    notifyListeners();
    unawaited(
      current!.refreshStatus().catchError((Object error) {
        debugPrint('Local sync status: $error');
      }),
    );
    _automatic.requestSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_automatic.refresh());
  }
}
