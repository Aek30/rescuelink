import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/sos_store.dart';
import '../services/sos_sync_service.dart';
import '../services/auth_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, required this.service});
  final SosSyncService service;
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<SosRecord> _conflicts = [];
  List<Map<String, Object?>> _queue = [];
  String? _error;
  bool _resolving = false;
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.service.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final records = await widget.service.store.list(includeDeleted: true);
      final queue = await widget.service.store.queue();
      if (mounted) {
        setState(() {
          _conflicts = records.where((r) => r.conflict != null).toList();
          _queue = queue;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'อ่านคิวไม่สำเร็จ');
    }
  }

  Future<void> _resolve(SosRecord record, bool local) async {
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      await widget.service.store.resolve(
        record.alert.incidentId,
        keepLocal: local,
      );
      await widget.service.sync();
      await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'แก้ข้อมูลขัดแย้งไม่สำเร็จ',
        );
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final disabled = service.busy || _resolving;
    return Scaffold(
      appBar: AppBar(title: const Text('บัญชี / Sync')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                AuthService.instance.session?.email ?? 'Guest',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                service.cloud == null
                    ? 'บันทึกในเครื่อง • เข้าสู่ระบบเพื่อซิงก์'
                    : 'Cloud: RescueLink',
              ),
              Text(
                'รอซิงก์ ${_queue.length} คำสั่ง • ขัดแย้ง ${_conflicts.length} เหตุ',
              ),
              Text('ซิงก์ล่าสุด: ${service.lastSuccess?.toLocal() ?? '-'}'),
              if (disabled) const LinearProgressIndicator(),
              if (_error != null || service.error != null)
                Text(
                  _error ?? service.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: disabled || service.cloud == null
                      ? null
                      : service.sync,
                  icon: const Icon(Icons.sync),
                  label: const Text('ซิงก์ตอนนี้'),
                ),
              ),
              for (final record in _conflicts) _conflict(record, disabled),
              const Divider(),
              for (final op in _queue)
                ListTile(
                  leading: Icon(
                    op['blocked'] == 1
                        ? Icons.sync_problem
                        : Icons.cloud_upload_outlined,
                  ),
                  title: Text(
                    op['deleted'] == 1 ? 'ลบเหตุ SOS' : 'บันทึกเหตุ SOS',
                  ),
                  subtitle: Text(
                    '${SosAlert.fromJson(op['payload'] as String).name}\nลองส่ง ${op['attempts']} ครั้ง${op['error'] == null ? '' : '\n${op['error']}'}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conflict(SosRecord record, bool disabled) {
    final remote = jsonDecode(record.conflict!) as Map<String, dynamic>?;
    final remoteAlert = remote == null
        ? null
        : SosAlert.fromJson(jsonEncode(remote['payload']));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ข้อมูลขัดแย้ง: ${record.alert.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'ในเครื่อง${record.deleted ? ' (ลบ)' : ''}:\n${record.alert.summary}',
            ),
            const Divider(),
            Text(
              'Cloud${remote?['deleted'] == true ? ' (ลบแล้ว)' : ''}:\n${remoteAlert?.summary ?? 'ไม่พบข้อมูล'}',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: disabled ? null : () => _resolve(record, false),
                  child: const Text('ใช้ข้อมูล Cloud'),
                ),
                TextButton(
                  onPressed: disabled || remote?['deleted'] == true
                      ? null
                      : () => _resolve(record, true),
                  child: const Text('ใช้ข้อมูลในเครื่อง'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
