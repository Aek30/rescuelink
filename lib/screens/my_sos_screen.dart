import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/sos_store.dart';
import '../services/sos_sync_service.dart';
import '../theme/rescue_theme.dart';
import '../widgets/emergency_type_chip.dart';
import '../widgets/sos_history_card.dart';
import '../widgets/sos_history_section_header.dart';
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
    final categories = alert.categories.toSet();
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(delete ? 'ลบเหตุที่ยุติแล้ว?' : 'แก้ไขเหตุที่ยุติแล้ว'),
          content: delete
              ? Text(
                  '${sosHistoryDisplayName(alert.name)}\n${alert.categoriesLabel}',
                )
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final type in EmergencyType.values)
                                FilterChip(
                                  label: Text(type.shortLabel),
                                  selected: categories.contains(type),
                                  onSelected: (selected) => update(() {
                                    if (!selected) {
                                      if (categories.length > 1) {
                                        categories.remove(type);
                                      }
                                    } else if (type == EmergencyType.other) {
                                      categories
                                        ..clear()
                                        ..add(type);
                                    } else {
                                      categories
                                        ..remove(EmergencyType.other)
                                        ..add(type);
                                    }
                                  }),
                                ),
                            ],
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
            category: categories.first,
            categories: categories.toList(),
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
      title: const Text('ประวัติ SOS'),
      actions: [
        IconButton(
          tooltip: 'บัญชี / Sync',
          icon: const Icon(Icons.cloud_sync_outlined),
          onPressed: SosSyncCoordinator.instance.current == null
              ? null
              : () async {
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
    floatingActionButton: widget.onCreate == null || _records.isEmpty
        ? null
        : FloatingActionButton.extended(
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: RescueTheme.accentFor(context).withValues(alpha: .25),
              ),
            ),
            tooltip: 'แจ้งเหตุ SOS',
            onPressed: widget.onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('แจ้งเหตุใหม่'),
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
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    MediaQuery.paddingOf(context).bottom + 104,
                  ),
                  children: [
                    _historyHeader(),
                    if (!_busy && _records.isEmpty) _emptyHistory(),
                    ..._historySections(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _date(DateTime value) {
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    final local = value.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year + 543}';
  }

  Widget _historyHeader() => SosHistoryOverviewHeader(total: _records.length);

  List<Widget> _historySections() {
    final sorted = [..._records]
      ..sort((a, b) => b.alert.updatedAt.compareTo(a.alert.updatedAt));
    final now = DateTime.now().toUtc();
    final children = <Widget>[];
    for (final active in [true, false]) {
      final records = sorted
          .where((r) => r.alert.isActiveAt(now) == active)
          .toList();
      if (records.isEmpty) continue;
      children.add(
        SosHistorySectionHeader(
          title: active ? 'กำลังดำเนินการ' : 'ยุติแล้ว',
          active: active,
        ),
      );
      for (var i = 0; i < records.length; i++) {
        final record = records[i];
        if (i == 0 ||
            _date(record.alert.updatedAt) !=
                _date(records[i - 1].alert.updatedAt)) {
          children.add(
            SosHistorySectionHeader(
              title: _date(record.alert.updatedAt),
              date: true,
            ),
          );
        }
        final editable =
            !_busy && !record.alert.active && record.conflict == null;
        children.add(
          SosHistoryCard(
            record: record,
            active: active,
            onEdit: editable ? () => _edit(record) : null,
            onDelete: editable ? () => _edit(record, delete: true) : null,
          ),
        );
      }
    }
    return children;
  }

  Widget _emptyHistory() => SosCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: RescueTheme.mutedFor(context),
          ),
          const SizedBox(height: 16),
          const Text(
            'ยังไม่มีเหตุ SOS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'คำขอที่คุณส่งจะแสดงที่นี่\nเพื่อกลับมาดูรายละเอียดได้ภายหลัง',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RescueTheme.mutedFor(context),
              fontSize: 13,
            ),
          ),
          if (widget.onCreate != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('แจ้งเหตุใหม่'),
            ),
          ],
        ],
      ),
    ),
  );
}
