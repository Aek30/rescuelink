import 'package:flutter/material.dart';

import '../models/sos_alert.dart';
import '../services/app_preferences.dart';
import '../services/message_service.dart';
import '../services/responder_store.dart';
import '../widgets/location_button.dart';
import 'chat_screen.dart';

/// Redesigned RescueLink responder screen.
///
/// Design: Rescue blue #3B82F6, SOS red #FF4D4D, soft peach #FFB37B,
/// warm off-white surfaces, and rounded cards.
///
/// The existing MessageService / ResponderStore workflow is preserved.
/// Case assignment and progress are still LOCAL TO THIS DEVICE.
class ResponderScreen extends StatefulWidget {
  const ResponderScreen({super.key, required this.service});

  final MessageService service;

  @override
  State<ResponderScreen> createState() => _ResponderScreenState();
}

class _RescuePalette {
  static const blue = Color(0xFF3B82F6);
  static const sos = Color(0xFFFF4D4D);
  static const canvas = Color(0xFFFFFAF6);
  static const white = Colors.white;
  static const ink = Color(0xFF202C40);
  static const muted = Color(0xFF788397);
  static const line = Color(0xFFE8EAF0);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const grey = Color(0xFF98A2B3);
}

class _StageAppearance {
  const _StageAppearance(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

class _ResponderScreenState extends State<ResponderScreen> {
  final Map<String, Map<String, dynamic>> records = {};
  Map<String, Map<String, SosAlert>> storedIncidents = {};

  int _refreshRevision = 0;
  bool busy = false;
  bool loading = true;
  String? error;
  String filter = 'all';

  MessageService get s => widget.service;
  String t(String key) => AppPreferences.instance.text(key);

  String tr(String thai, String english) =>
      AppPreferences.instance.t(thai, english);

  Map<String, (String, SosAlert)> get incidents {
    final result = <String, (String, SosAlert)>{};

    void add(String owner, SosAlert alert) {
      final key = '$owner:${alert.incidentId}';
      if (result[key] == null || result[key]!.$2.revision < alert.revision) {
        result[key] = (owner, alert);
      }
    }

    for (final message in s.receivedSos) {
      add(message.senderId, SosAlert.fromJson(message.text));
    }
    for (final entry in s.presence.entries) {
      if (entry.value.sos != null) add(entry.key, entry.value.sos!);
    }
    for (final owner in storedIncidents.entries) {
      for (final alert in owner.value.values) {
        add(owner.key, alert);
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    s.addListener(_refresh);
    AppPreferences.instance.addListener(_localeChanged);
    _refresh();
  }

  @override
  void dispose() {
    s.removeListener(_refresh);
    AppPreferences.instance.removeListener(_localeChanged);
    super.dispose();
  }

  void _localeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final revision = ++_refreshRevision;
    try {
      final stored = await s.database.getRemoteSos();
      if (!mounted || revision != _refreshRevision) return;
      storedIncidents = stored;

      final next = <String, Map<String, dynamic>>{};
      for (final entry in incidents.entries) {
        final record = await ResponderStore(
          s,
        ).read(entry.value.$1, entry.value.$2.incidentId);
        if (!mounted || revision != _refreshRevision) return;
        if (record != null) next[entry.key] = record;
      }
      if (!mounted || revision != _refreshRevision) return;
      setState(() {
        records
          ..clear()
          ..addAll(next);
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted && revision == _refreshRevision) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleRescueMode(bool value) async {
    if (busy || !s.ready) return;
    if (value && s.mySos?.isActiveAt(DateTime.now().toUtc()) == true) {
      setState(() {
        error = tr(
          'กรุณาจัดการหรือยกเลิก SOS ของคุณก่อนเปิดรับเหตุ',
          'Resolve or cancel your own SOS before enabling responder mode.',
        );
      });
      return;
    }
    await _run(() => s.setRescueMode(value));
  }

  /// Visible status: closed incidents must not look actionable.
  /// Completed local records remain completed even after SOS expiration.
  String _stageFor(String key, SosAlert alert) {
    final saved = records[key]?['stage'] as String?;
    if (saved == 'completed') return 'completed';
    if (!alert.active || alert.isExpired(DateTime.now().toUtc())) {
      return 'closed';
    }
    if (saved == 'pending' || saved == 'helping') return saved!;
    return 'open';
  }

  _StageAppearance _stageAppearance(String stage) => switch (stage) {
    'pending' => _StageAppearance(
      tr('รอยืนยัน', 'Awaiting confirmation'),
      _RescuePalette.amber,
      Icons.hourglass_bottom_rounded,
    ),
    'helping' => _StageAppearance(
      tr('กำลังช่วยเหลือ', 'Helping'),
      _RescuePalette.blue,
      Icons.volunteer_activism_outlined,
    ),
    'completed' => _StageAppearance(
      tr('เสร็จสิ้น', 'Completed'),
      _RescuePalette.green,
      Icons.check_circle_outline_rounded,
    ),
    'closed' => _StageAppearance(
      tr('ยกเลิก / หมดอายุ', 'Cancelled / expired'),
      _RescuePalette.grey,
      Icons.block_outlined,
    ),
    _ => _StageAppearance(
      tr('รอรับเคส', 'New incident'),
      _RescuePalette.sos,
      Icons.notification_important_outlined,
    ),
  };

  String _filterLabel(String value) => switch (value) {
    'all' => tr('ทั้งหมด', 'All'),
    'open' => tr('รอรับเคส', 'New'),
    'pending' => tr('รอยืนยัน', 'Pending'),
    'helping' => tr('กำลังช่วยเหลือ', 'Helping'),
    'completed' => tr('เสร็จสิ้น', 'Done'),
    _ => tr('ปิด / หมดอายุ', 'Closed'),
  };

  String _formatDate(DateTime utc) {
    final value = utc.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _locationLabel(SosAlert alert) =>
      alert.location?.summary ?? tr('ไม่ได้ระบุตำแหน่ง', 'No location');

  Future<void> _detail(String owner, SosAlert initial) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, updateSheet) {
          final alert =
              incidents['$owner:${initial.incidentId}']?.$2 ?? initial;
          final key = '$owner:${alert.incidentId}';
          final record = records[key];
          final stage = _stageFor(key, alert);
          final appearance = _stageAppearance(stage);
          final canAct =
              !busy && s.rescueMode && alert.isActiveAt(DateTime.now().toUtc());
          final nextStages = record == null
              ? <String>['pending']
              : record['stage'] == 'completed'
              ? <String>[]
              : <String>['helping', 'completed'];

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.91,
            ),
            decoration: const BoxDecoration(
              color: _RescuePalette.canvas,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _RescuePalette.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 23),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _RescuePalette.sos.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: _RescuePalette.sos,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('รายละเอียดเหตุ SOS', 'SOS incident details'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _RescuePalette.ink,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              t(alert.category.label),
                              style: const TextStyle(
                                fontSize: 14,
                                color: _RescuePalette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: tr('ปิด', 'Close'),
                        onPressed: () => Navigator.pop(sheet),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StageChip(appearance: appearance),
                  ),
                  const SizedBox(height: 17),
                  _SurfaceCard(
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.person_outline_rounded,
                          title: tr('ผู้แจ้งเหตุ', 'Reported by'),
                          value: alert.name.isEmpty
                              ? tr('ไม่ระบุชื่อ', 'Unknown')
                              : alert.name,
                        ),
                        const Divider(height: 24, color: _RescuePalette.line),
                        _DetailRow(
                          icon: Icons.groups_2_outlined,
                          title: tr('จำนวนผู้ประสบภัย', 'People affected'),
                          value: '${alert.people} ${tr('คน', 'people')}',
                        ),
                        const Divider(height: 24, color: _RescuePalette.line),
                        _DetailRow(
                          icon: Icons.schedule_rounded,
                          title: tr('อัปเดตล่าสุด', 'Last updated'),
                          value: _formatDate(alert.updatedAt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionCaption(
                          icon: Icons.notes_outlined,
                          text: tr(
                            'รายละเอียดเพิ่มเติม',
                            'Incident description',
                          ),
                        ),
                        const SizedBox(height: 9),
                        SelectableText(
                          alert.details.trim().isEmpty
                              ? tr('ไม่มีรายละเอียด', 'No description')
                              : alert.details,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: _RescuePalette.ink,
                          ),
                        ),
                        const SizedBox(height: 17),
                        _SectionCaption(
                          icon: Icons.location_on_outlined,
                          text: tr('ตำแหน่งผู้แจ้ง', 'Reporter location'),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          _locationLabel(alert),
                          style: const TextStyle(color: _RescuePalette.ink),
                        ),
                        if (alert.location != null) ...[
                          const SizedBox(height: 10),
                          LocationButton(location: alert.location!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: _RescuePalette.blue.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _RescuePalette.blue.withValues(alpha: .13),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: _RescuePalette.blue,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(
                              'สถานะรับเคสบันทึกเฉพาะเครื่องนี้ ยังไม่มีระบบยืนยันการจัดสรรเคสจากผู้แจ้ง',
                              'Case progress is saved on this device only. The reporter has not confirmed assignment.',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: _RescuePalette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: error!),
                  ],
                  const SizedBox(height: 20),
                  for (final nextStage in nextStages) ...[
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: canAct
                            ? () async {
                                updateSheet(() {});
                                await _run(() async {
                                  final store = ResponderStore(s);
                                  await store.update(owner, alert, nextStage);
                                  await store.notifyReporter(
                                    owner,
                                    alert.incidentId,
                                  );
                                });
                                if (sheet.mounted) updateSheet(() {});
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _RescuePalette.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _RescuePalette.line,
                          disabledForegroundColor: _RescuePalette.muted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: Icon(
                          nextStage == 'completed'
                              ? Icons.check_circle_outline_rounded
                              : Icons.volunteer_activism_outlined,
                        ),
                        label: Text(
                          nextStage == 'pending'
                              ? tr('รับเคสนี้', 'Accept case')
                              : nextStage == 'helping'
                              ? tr('เริ่มช่วยเหลือ', 'Start helping')
                              : tr('บันทึกว่าเสร็จสิ้น', 'Mark completed'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheet);
                        if (!mounted) return;
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ChatScreen(service: s, peerId: owner),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _RescuePalette.blue,
                        side: BorderSide(
                          color: _RescuePalette.blue.withValues(alpha: .35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(
                        tr('ติดต่อผู้แจ้งเหตุ', 'Message reporter'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (record != null) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              updateSheet(() {});
                              await _run(
                                () => ResponderStore(
                                  s,
                                ).notifyReporter(owner, alert.incidentId),
                              );
                              if (sheet.mounted) updateSheet(() {});
                            },
                      icon: const Icon(Icons.send_outlined, size: 17),
                      label: Text(
                        tr('ส่งการอัปเดตเคสอีกครั้ง', 'Resend case update'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = incidents.entries.toList()
      ..sort((a, b) => b.value.$2.updatedAt.compareTo(a.value.$2.updatedAt));
    final pending = entries
        .where((entry) => _stageFor(entry.key, entry.value.$2) == 'pending')
        .length;
    final helping = entries
        .where((entry) => _stageFor(entry.key, entry.value.$2) == 'helping')
        .length;
    final visible = entries
        .where(
          (entry) =>
              filter == 'all' || _stageFor(entry.key, entry.value.$2) == filter,
        )
        .toList();

    return Scaffold(
      backgroundColor: _RescuePalette.canvas,
      appBar: AppBar(
        backgroundColor: _RescuePalette.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('หน่วยกู้ภัย', 'Responder'),
              style: const TextStyle(
                color: _RescuePalette.ink,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            Text(
              tr('ศูนย์จัดการแจ้งเหตุ SOS', 'SOS incident center'),
              style: const TextStyle(
                color: _RescuePalette.muted,
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('รีเฟรชข้อมูล', 'Refresh incidents'),
            onPressed: loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded, color: _RescuePalette.blue),
          ),
          const SizedBox(width: 9),
        ],
      ),
      body: RefreshIndicator(
        color: _RescuePalette.blue,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(17, 12, 17, 36),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 690),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRescueToggle(),
                    if (busy) ...[
                      const SizedBox(height: 11),
                      const LinearProgressIndicator(
                        minHeight: 3,
                        color: _RescuePalette.blue,
                        backgroundColor: _RescuePalette.line,
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 23),
                    Text(
                      tr('ภาพรวมการช่วยเหลือ', 'Responder overview'),
                      style: const TextStyle(
                        color: _RescuePalette.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            count: entries.length,
                            title: tr('เหตุทั้งหมด', 'All SOS'),
                            icon: Icons.notifications_active_outlined,
                            color: _RescuePalette.sos,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _MetricCard(
                            count: pending,
                            title: tr('รอยืนยัน', 'Pending'),
                            icon: Icons.hourglass_bottom_rounded,
                            color: _RescuePalette.amber,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _MetricCard(
                            count: helping,
                            title: tr('กำลังช่วย', 'Helping'),
                            icon: Icons.volunteer_activism_outlined,
                            color: _RescuePalette.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('รายการแจ้งเหตุ', 'SOS incidents'),
                            style: const TextStyle(
                              color: _RescuePalette.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${visible.length} ${tr('รายการ', 'cases')}',
                          style: const TextStyle(
                            color: _RescuePalette.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final value in const [
                            'all',
                            'open',
                            'pending',
                            'helping',
                            'completed',
                            'closed',
                          ]) ...[
                            _FilterChip(
                              title: _filterLabel(value),
                              selected: filter == value,
                              onTap: () => setState(() => filter = value),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (loading && entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 54),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _RescuePalette.blue,
                          ),
                        ),
                      )
                    else if (visible.isEmpty)
                      _EmptyIncidents(
                        isFiltered: entries.isNotEmpty,
                        title: entries.isEmpty
                            ? tr(
                                'ยังไม่มีเหตุแจ้งเข้ามา',
                                'No incoming SOS yet',
                              )
                            : tr(
                                'ไม่พบเคสในหมวดนี้',
                                'No cases in this filter',
                              ),
                        subtitle: entries.isEmpty
                            ? tr(
                                'รายการ SOS ที่ได้รับจากอุปกรณ์ใกล้เคียงจะปรากฏที่นี่',
                                'Incoming SOS reports from nearby devices will appear here.',
                              )
                            : tr(
                                'ลองเลือกตัวกรองอื่นเพื่อดูรายการเหตุทั้งหมด',
                                'Choose a different filter to see other incidents.',
                              ),
                      )
                    else
                      for (final entry in visible) ...[
                        _IncidentCard(
                          alert: entry.value.$2,
                          category: t(entry.value.$2.category.label),
                          date: _formatDate(entry.value.$2.updatedAt),
                          location: _locationLabel(entry.value.$2),
                          appearance: _stageAppearance(
                            _stageFor(entry.key, entry.value.$2),
                          ),
                          peopleLabel: tr('คน', 'people'),
                          fallbackName: tr('ไม่ระบุชื่อ', 'Unknown'),
                          onTap: () => _detail(entry.value.$1, entry.value.$2),
                        ),
                        const SizedBox(height: 11),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRescueToggle() {
    final active = s.rescueMode;
    return Column(
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? const [Color(0xFF2469D8), Color(0xFF5D9CF8)]
                  : const [Color(0xFF66758C), Color(0xFF9BA8BB)],
            ),
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: (active ? _RescuePalette.blue : _RescuePalette.grey)
                    .withValues(alpha: .17),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -19,
                top: -17,
                child: Icon(
                  Icons.shield_outlined,
                  size: 130,
                  color: Colors.white.withValues(alpha: .09),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(19),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .17),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.health_and_safety_outlined,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('พร้อมรับแจ้งเหตุ', 'Ready to respond'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFFB3FFCA)
                                      : const Color(0xFFE9EBF0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  active
                                      ? tr(
                                          'เปิดโหมดช่วยเหลือ',
                                          'Responder mode on',
                                        )
                                      : tr(
                                          'ปิดโหมดช่วยเหลือ',
                                          'Responder mode off',
                                        ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: active,
                      onChanged: busy || !s.ready ? null : _toggleRescueMode,
                      activeThumbColor: _RescuePalette.blue,
                      activeTrackColor: Colors.white,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: .25),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _RescuePalette.muted,
              size: 16,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                s.ready
                    ? tr(
                        'ผู้ช่วยเหลือทั่วไป • ยังไม่มีการยืนยันหน่วยงาน',
                        'Community responder • Organization not verified',
                      )
                    : tr(
                        'อุปกรณ์ยังไม่พร้อม โปรดตรวจสอบสิทธิ์และการเชื่อมต่อ',
                        'Device not ready. Check permissions and connections.',
                      ),
                style: const TextStyle(
                  color: _RescuePalette.muted,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _RescuePalette.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: _RescuePalette.line),
    ),
    child: child,
  );
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.appearance});
  final _StageAppearance appearance;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: appearance.color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(appearance.icon, size: 14, color: appearance.color),
        const SizedBox(width: 5),
        Text(
          appearance.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: appearance.color,
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _RescuePalette.muted, size: 21),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: _RescuePalette.muted),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _RescuePalette.ink,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: _RescuePalette.blue),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _RescuePalette.ink,
        ),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.count,
    required this.title,
    required this.icon,
    required this.color,
  });

  final int count;
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 113),
    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _RescuePalette.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: const TextStyle(
            color: _RescuePalette.ink,
            fontSize: 25,
            height: 1.0,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _RescuePalette.muted, fontSize: 11.5),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _RescuePalette.blue : _RescuePalette.white,
    shape: StadiumBorder(
      side: BorderSide(
        color: selected ? _RescuePalette.blue : _RescuePalette.line,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : _RescuePalette.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.alert,
    required this.category,
    required this.date,
    required this.location,
    required this.appearance,
    required this.peopleLabel,
    required this.fallbackName,
    required this.onTap,
  });

  final SosAlert alert;
  final String category;
  final String date;
  final String location;
  final _StageAppearance appearance;
  final String peopleLabel;
  final String fallbackName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(21),
    child: InkWell(
      borderRadius: BorderRadius.circular(21),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 15, 13, 14),
        decoration: BoxDecoration(
          border: Border.all(color: _RescuePalette.line),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 41,
                  height: 41,
                  decoration: BoxDecoration(
                    color: _RescuePalette.sos.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.notification_important_outlined,
                    color: _RescuePalette.sos,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _RescuePalette.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.name.trim().isEmpty ? fallbackName : alert.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _RescuePalette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                _StageChip(appearance: appearance),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              alert.details.trim().isEmpty ? '—' : alert.details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _RescuePalette.ink,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 13),
            const Divider(height: 1, color: _RescuePalette.line),
            const SizedBox(height: 11),
            Row(
              children: [
                const Icon(
                  Icons.people_outline_rounded,
                  color: _RescuePalette.muted,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  '${alert.people} $peopleLabel',
                  style: const TextStyle(
                    color: _RescuePalette.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 13),
                const Icon(
                  Icons.schedule_rounded,
                  color: _RescuePalette.muted,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: const TextStyle(
                    color: _RescuePalette.muted,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _RescuePalette.blue,
                  size: 21,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: _RescuePalette.muted,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _RescuePalette.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyIncidents extends StatelessWidget {
  const _EmptyIncidents({
    required this.isFiltered,
    required this.title,
    required this.subtitle,
  });
  final bool isFiltered;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _RescuePalette.line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _RescuePalette.blue.withValues(alpha: .09),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFiltered
                ? Icons.filter_list_off_rounded
                : Icons.notifications_none_rounded,
            size: 29,
            color: _RescuePalette.blue,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _RescuePalette.ink,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _RescuePalette.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _RescuePalette.sos.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _RescuePalette.sos.withValues(alpha: .20)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: _RescuePalette.sos,
          size: 20,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: _RescuePalette.ink,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
