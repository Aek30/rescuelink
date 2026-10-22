import 'package:flutter/material.dart';

import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';
import '../services/app_preferences.dart';
import '../services/message_service.dart';
import '../widgets/emergency_type_chip.dart';
import '../widgets/location_button.dart';
import 'chat_screen.dart';

const Color kRescueBlue = RescueTheme.rescue;

const Color _kLightMuted = Color(0xFF5B6675);

final RegExp _cancelTagRegExp = RegExp(r'\[ยกเลิก:\s*([^\]]+)\]');

({String details, List<String> cancelReasons}) _parseDetails(String raw) {
  final reasons = <String>[];
  for (final match in _cancelTagRegExp.allMatches(raw)) {
    final reason = match.group(1)?.trim() ?? '';
    if (reason.isNotEmpty && !reasons.contains(reason)) {
      reasons.add(reason);
    }
  }
  final cleaned = raw.replaceAll(_cancelTagRegExp, '').trim();
  return (details: cleaned, cancelReasons: reasons);
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _screenBg(BuildContext context) =>
    _isDark(context) ? RescueTheme.darkSurface : RescueTheme.cream;

Color _cardBg(BuildContext context) =>
    _isDark(context) ? RescueTheme.darkSurface : Colors.white;

Color _borderColor(BuildContext context) =>
    _isDark(context) ? RescueTheme.darkBorder : RescueTheme.border;

Color _inkColor(BuildContext context) =>
    _isDark(context) ? Colors.white : RescueTheme.navy;

Color _mutedColor(BuildContext context) =>
    _isDark(context) ? RescueTheme.darkTextMuted : _kLightMuted;

/// Displays received SOS reports and the local responder mode switch.
class ResponderScreen extends StatefulWidget {
  const ResponderScreen({super.key, required this.service});

  final MessageService service;

  @override
  State<ResponderScreen> createState() => _ResponderScreenState();
}

class _StageAppearance {
  const _StageAppearance(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

class _ResponderScreenState extends State<ResponderScreen> {
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

      setState(() {
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

  String _stageFor(SosAlert alert) =>
      alert.isActiveAt(DateTime.now().toUtc()) ? 'open' : 'closed';

  _StageAppearance _stageAppearance(String stage) => stage == 'open'
      ? _StageAppearance(
          tr('กำลังขอความช่วยเหลือ', 'Active SOS'),
          kSosRed,
          Icons.notification_important_outlined,
        )
      : _StageAppearance(
          tr('ยกเลิก / หมดอายุ', 'Cancelled / expired'),
          _kLightMuted,
          Icons.block_outlined,
        );

  String _filterLabel(String value) => switch (value) {
    'all' => tr('ทั้งหมด', 'All'),
    'open' => tr('SOS ที่เปิดอยู่', 'Active SOS'),
    _ => tr('ยกเลิก / หมดอายุ', 'Cancelled / expired'),
  };

  String _formatDate(DateTime utc) {
    final value = utc.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _locationLabel(SosAlert alert) =>
      alert.location != null
          ? tr('มีพิกัด', 'Has location')
          : tr('ไม่มีพิกัด', 'No location');

  Future<void> _detail(String owner, SosAlert initial) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => ListenableBuilder(
        listenable: s,
        builder: (sheetContext, _) {
          final alert =
              incidents['$owner:${initial.incidentId}']?.$2 ?? initial;
          final stage = _stageFor(alert);
          final isOpen = stage == 'open';
          final appearance = _stageAppearance(stage);
          final parsed = _parseDetails(alert.details);
          final ink = _inkColor(sheetContext);
          final muted = _mutedColor(sheetContext);
          final border = _borderColor(sheetContext);
          final sheetBg = _cardBg(sheetContext);
          final headerIconColor = isOpen ? kSosRed : _kLightMuted;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.91,
            ),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 1. หัว (ไอคอน + ประเภท + chip + ปิด)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: headerIconColor.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.notifications_active_outlined,
                                color: headerIconColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(
                                      'รายละเอียดเหตุ SOS',
                                      'SOS incident details',
                                    ),
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t(alert.categoriesLabel),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _StageChip(appearance: appearance),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: tr('ปิด', 'Close'),
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Icon(Icons.close_rounded, color: ink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 17),
                        // 2. การ์ดข้อมูล (ผู้แจ้ง / จำนวนคน / อัปเดตล่าสุด)
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
                              Divider(height: 24, color: border),
                              _DetailRow(
                                icon: Icons.groups_2_outlined,
                                title: tr(
                                  'จำนวนผู้ประสบภัย',
                                  'People affected',
                                ),
                                value:
                                    '${alert.people} ${tr('คน', 'people')}',
                              ),
                              Divider(height: 24, color: border),
                              _DetailRow(
                                icon: Icons.schedule_rounded,
                                title: tr('อัปเดตล่าสุด', 'Last updated'),
                                value:
                                    '${sosAge(alert.updatedAt)} • ${_formatDate(alert.updatedAt)}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 3. การ์ดรายละเอียด (แยกเหตุผลยกเลิกเป็นบรรทัดแยก)
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
                              if (parsed.details.isNotEmpty)
                                SelectableText(
                                  parsed.details,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: ink,
                                  ),
                                )
                              else if (parsed.cancelReasons.isEmpty)
                                SelectableText(
                                  tr('ไม่มีรายละเอียด', 'No description'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: muted,
                                  ),
                                ),
                              if (parsed.cancelReasons.isNotEmpty) ...[
                                if (parsed.details.isNotEmpty)
                                  const SizedBox(height: 8),
                                Text(
                                  'ยกเลิกเพราะ: ${parsed.cancelReasons.join(', ')}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 4. การ์ดตำแหน่ง
                        if (alert.location != null)
                          LocationButton(location: alert.location!)
                        else
                          _SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionCaption(
                                  icon: Icons.location_on_outlined,
                                  text: tr(
                                    'ตำแหน่งผู้แจ้ง',
                                    'Reporter location',
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  tr('ไม่มีพิกัด', 'No location'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: sheetBg,
                      border: Border(top: BorderSide(color: border)),
                    ),
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          if (!mounted) return;
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ChatScreen(service: s, peerId: owner),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kRescueBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: Text(
                          tr('ติดต่อผู้แจ้งเหตุ', 'Message reporter'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
    final active = entries
        .where((entry) => _stageFor(entry.value.$2) == 'open')
        .length;
    final closed = entries.length - active;
    final visible = entries
        .where(
          (entry) => filter == 'all' || _stageFor(entry.value.$2) == filter,
        )
        .toList();

    int countForFilter(String value) => switch (value) {
      'all' => entries.length,
      'open' => active,
      _ => closed,
    };

    final bg = _screenBg(context);
    final ink = _inkColor(context);
    final muted = _mutedColor(context);
    final border = _borderColor(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('หน่วยกู้ภัย', 'Responder'),
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            Text(
              tr('ศูนย์จัดการแจ้งเหตุ SOS', 'SOS incident center'),
              style: TextStyle(
                color: muted,
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
            icon: const Icon(Icons.refresh_rounded, color: kRescueBlue),
          ),
          const SizedBox(width: 9),
        ],
      ),
      body: RefreshIndicator(
        color: kRescueBlue,
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
                      LinearProgressIndicator(
                        minHeight: 3,
                        color: kRescueBlue,
                        backgroundColor: border,
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('รายการแจ้งเหตุ', 'SOS incidents'),
                            style: TextStyle(
                              color: ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${visible.length} ${tr('รายการ', 'incidents')}',
                          style: TextStyle(
                            color: muted,
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
                            'closed',
                          ]) ...[
                            _FilterChip(
                              title:
                                  '${_filterLabel(value)} ${countForFilter(value)}',
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
                            color: kRescueBlue,
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
                                'ไม่พบเหตุในหมวดนี้',
                                'No incidents in this filter',
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
                          category: t(entry.value.$2.categoriesLabel),
                          date: _formatDate(entry.value.$2.updatedAt),
                          location: _locationLabel(entry.value.$2),
                          appearance: _stageAppearance(
                            _stageFor(entry.value.$2),
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
    final dark = _isDark(context);
    final ink = _inkColor(context);
    final muted = _mutedColor(context);
    final border = _borderColor(context);
    final cardColor = active
        ? kRescueBlue.withValues(alpha: dark ? .16 : .08)
        : _cardBg(context);
    final cardBorder = active
        ? kRescueBlue.withValues(alpha: dark ? .55 : .40)
        : border;
    final hasLocationError = s.rescueLocationError != null;

    final statusText = s.ready
        ? tr(
            s.rescueMode
                ? s.rescueLocationLoading
                      ? 'กำลังอ่าน GPS และแชร์ตำแหน่งกู้ภัยอัตโนมัติ…'
                      : s.rescueLocationError ??
                            (s.rescueLocation != null
                                ? 'แชร์ตำแหน่งกู้ภัยแล้ว • ปิดโหมดกู้ภัยเพื่อหยุดแชร์'
                                : 'ยังไม่มีพิกัดกู้ภัย อัปเดตตำแหน่งได้ที่หน้าใกล้ฉัน')
                : 'ผู้ช่วยเหลือทั่วไป • ยังไม่มีการยืนยันหน่วยงาน',
            s.rescueMode
                ? s.rescueLocationLoading
                      ? 'Reading GPS and sharing responder location…'
                      : s.rescueLocationError != null
                      ? 'Location unavailable. Check GPS and update it in Nearby.'
                      : s.rescueLocation != null
                      ? 'Responder location shared. Turn off rescue mode to stop sharing.'
                      : 'No responder location yet. Update it in Nearby.'
                : 'Community responder • Organization not verified',
          )
        : tr(
            'อุปกรณ์ยังไม่พร้อม โปรดตรวจสอบสิทธิ์และการเชื่อมต่อ',
            'Device not ready. Check permissions and connections.',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: active
                      ? kRescueBlue.withValues(alpha: dark ? .24 : .14)
                      : muted.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  color: active ? kRescueBlue : muted,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active
                          ? tr('กำลังรับแจ้งเหตุ', 'Receiving SOS alerts')
                          : tr('ยังไม่รับแจ้งเหตุ', 'Not receiving SOS alerts'),
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active ? kRescueBlue : muted,
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
                            style: TextStyle(
                              color: active ? kRescueBlue : muted,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 12.5,
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
                activeThumbColor: Colors.white,
                activeTrackColor: kRescueBlue,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: muted.withValues(alpha: .35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (hasLocationError)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF33260D) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: dark
                    ? const Color(0xFF664D1A)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: dark
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFB45309),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFF92400E),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: muted,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
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
      color: _cardBg(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _borderColor(context)),
    ),
    child: child,
  );
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.appearance});
  final _StageAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final isOpen = appearance.color == kSosRed;
    final chipColor = isOpen
        ? kSosRed
        : (_isDark(context) ? RescueTheme.darkTextMuted : _kLightMuted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(appearance.icon, size: 14, color: chipColor),
          const SizedBox(width: 5),
          Text(
            appearance.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final ink = _inkColor(context);
    final muted = _mutedColor(context);

    return Row(
      children: [
        Icon(icon, color: muted, size: 21),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: kRescueBlue),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _inkColor(context),
        ),
      ),
    ],
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
  Widget build(BuildContext context) {
    final muted = _mutedColor(context);
    final border = _borderColor(context);

    return Material(
      color: selected ? RescueTheme.peach : _cardBg(context),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? RescueTheme.orangeInk.withValues(alpha: .30)
              : border,
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
              color: selected ? RescueTheme.orangeInk : muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final isOpen = appearance.color == kSosRed;
    final dark = _isDark(context);
    final ink = _inkColor(context);
    final muted = _mutedColor(context);
    final border = isOpen
        ? kSosRed.withValues(alpha: dark ? .45 : .28)
        : _borderColor(context);
    final iconColor = isOpen ? kSosRed : _kLightMuted;
    final metaStyle = TextStyle(color: muted, fontSize: 12.5);
    final parsed = _parseDetails(alert.details);
    final hasLocation = alert.location != null;

    return Opacity(
      opacity: isOpen ? 1.0 : 0.88,
      child: Material(
        color: _cardBg(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 15, 13, 14),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ส่วนบน: ไอคอน + ประเภท (ได้ 2 บรรทัด) + ชื่อผู้แจ้ง
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 41,
                            height: 41,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.notification_important_outlined,
                              color: iconColor,
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert.name.trim().isEmpty
                                      ? fallbackName
                                      : alert.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (parsed.details.isNotEmpty) ...[
                        const SizedBox(height: 11),
                        Text(
                          parsed.details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (parsed.cancelReasons.isNotEmpty) ...[
                        SizedBox(height: parsed.details.isNotEmpty ? 6 : 10),
                        Text(
                          'ยกเลิกเพราะ: ${parsed.cancelReasons.join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 11),
                      // แถวเมตา: จำนวนคน • เวลาสัมพัทธ์ • พิกัด • chip สถานะ
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${alert.people} $peopleLabel • ${sosAge(alert.updatedAt)} •',
                            style: metaStyle,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasLocation) ...[
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: muted,
                                ),
                                const SizedBox(width: 2),
                              ],
                              Text(
                                location,
                                style: metaStyle,
                              ),
                            ],
                          ),
                          Text('•', style: metaStyle),
                          _StageChip(appearance: appearance),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      color: _cardBg(context),
      border: Border.all(color: _borderColor(context)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: RescueTheme.peach,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFiltered
                ? Icons.filter_list_off_rounded
                : Icons.notifications_none_rounded,
            size: 29,
            color: RescueTheme.orangeInk,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _inkColor(context),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _mutedColor(context),
            fontSize: 12.5,
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
  Widget build(BuildContext context) {
    final dark = _isDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSosRed.withValues(alpha: dark ? .16 : .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kSosRed.withValues(alpha: dark ? .35 : .20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: kSosRed,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: _inkColor(context),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
