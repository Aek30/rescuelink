import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/sos_store.dart';
import '../services/sos_sync_service.dart';
import 'sync_screen.dart';

class MySosScreen extends StatefulWidget {
  const MySosScreen({super.key, required this.store, this.onCreate});
  final SosStore store;
  final VoidCallback? onCreate;
  @override
  State<MySosScreen> createState() => _MySosScreenState();
}

class _MySosScreenState extends State<MySosScreen> {
  List<SosRecord> _records = [];
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await widget.store.list();
      if (mounted) {
        setState(() {
          _records = records;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'อ่านรายการไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(SosRecord record, {bool delete = false}) async {
    final alert = record.alert;
    final name = TextEditingController(text: alert.name);
    final details = TextEditingController(text: alert.details);
    final people = TextEditingController(text: '${alert.people}');
    var category = alert.category;
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(delete ? 'ลบเหตุที่ยุติแล้ว?' : 'แก้ไขเหตุที่ยุติแล้ว'),
          content: delete
              ? Text('${alert.name}\n${alert.category.label}')
              : SizedBox(
                  width: 420,
                  child: Form(
                    key: form,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: name,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อผู้แจ้ง',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'กรุณาระบุชื่อ'
                                : null,
                          ),
                          TextFormField(
                            controller: people,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'จำนวนคน',
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 1 || n > 999
                                  ? 'ระบุ 1–999 คน'
                                  : null;
                            },
                          ),
                          DropdownButtonFormField<EmergencyType>(
                            initialValue: category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'ประเภทเหตุ',
                            ),
                            items: EmergencyType.values
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => update(() => category = v!),
                          ),
                          TextFormField(
                            controller: details,
                            maxLength: 1000,
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'รายละเอียด',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                if (delete || form.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(delete ? 'ลบ' : 'บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await widget.store.editClosed(
          SosAlert(
            incidentId: alert.incidentId,
            revision: alert.revision + 1,
            active: false,
            name: name.text.trim(),
            people: int.parse(people.text),
            category: category,
            details: details.text.trim(),
            updatedAt: DateTime.now().toUtc(),
            location: alert.location,
          ),
          delete: delete,
        );
        await _load();
      } catch (e) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = e is StateError
                ? e.message.toString()
                : 'บันทึกไม่สำเร็จ กรุณาลองใหม่';
          });
        }
      }
    }
    // Dialog route finishes its exit animation before disposing its controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    details.dispose();
    people.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('รายการเหตุ SOS ของฉัน'),
      actions: [
        IconButton(
          tooltip: 'บัญชี / Sync',
          icon: const Icon(Icons.cloud_sync_outlined),
          onPressed: () async {
            final sync = SosSyncCoordinator.instance.current;
            if (sync == null) return;
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SyncScreen(service: sync),
              ),
            );
            await _load();
          },
        ),
        IconButton(
          tooltip: 'โหลดรายการใหม่',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: widget.onCreate == null
        ? null
        : FloatingActionButton(
            tooltip: 'แจ้งเหตุ SOS',
            onPressed: widget.onCreate,
            child: const Icon(Icons.add),
          ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (!_busy && _records.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'ยังไม่มีเหตุ SOS',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final record in _records)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    record.alert.active
                                        ? Icons.sos
                                        : Icons.check_circle_outline,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      record.alert.category.label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  Text(
                                    record.alert.active
                                        ? 'กำลังขอความช่วยเหลือ'
                                        : 'ยุติแล้ว',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${record.alert.name} • ${record.alert.people} คน',
                              ),
                              if (record.alert.details.isNotEmpty)
                                SelectableText(record.alert.details),
                              if (record.alert.location != null)
                                SelectableText(record.alert.location!.summary),
                              Text('${record.alert.updatedAt.toLocal()}'),
                              if (record.conflict != null)
                                const Text('ข้อมูลขัดแย้งกับ Cloud'),
                              if (!record.alert.active)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'แก้ไขเหตุ',
                                      onPressed:
                                          _busy || record.conflict != null
                                          ? null
                                          : () => _edit(record),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'ลบเหตุ',
                                      onPressed:
                                          _busy || record.conflict != null
                                          ? null
                                          : () => _edit(record, delete: true),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
