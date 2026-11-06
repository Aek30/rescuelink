import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/sos_store.dart';
import '../services/sos_sync_service.dart';
import '../services/chat_sync_service.dart';
import '../theme/rescue_theme.dart';
import '../widgets/rescue_ui.dart';
import '../utils/thai_time.dart';

/// Top-level helper to format the last sync duration into readable Thai text
String syncAgo(DateTime? d) {
  if (d == null) return 'ยังไม่เคยซิงก์';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'ซิงก์เมื่อสักครู่';
  if (diff.inMinutes < 60) return 'ซิงก์ล่าสุด ${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return 'ซิงก์ล่าสุด ${diff.inHours} ชั่วโมงที่แล้ว';
  return 'ซิงก์ล่าสุด ${diff.inDays} วันที่แล้ว';
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, required this.service, this.chatService});
  final SosSyncService service;
  final ChatSyncService? chatService;
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<SosRecord> _conflicts = [];
  List<Map<String, Object?>> _queue = [];
  late final ChatSyncService? _chat;
  List<Map<String, Object?>> _chatQueue = [];
  List<Map<String, Object?>> _chatConflicts = [];
  bool _syncing = false;
  String? _error;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _chat = widget.chatService ?? ChatSyncCoordinator.instance.current;
    widget.service.addListener(_load);
    _chat?.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.service.removeListener(_load);
    _chat?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final records = await widget.service.store.list(includeDeleted: true);
      final queue = await widget.service.store.queue();
      final chatQueue = await _chat?.store.queue() ?? <Map<String, Object?>>[];
      final chatRecords = await _chat?.store.list() ?? <Map<String, Object?>>[];
      if (mounted) {
        setState(() {
          _conflicts = records.where((r) => r.conflict != null).toList();
          _queue = queue;
          _chatQueue = chatQueue;
          _chatConflicts = chatRecords
              .where((r) => r['conflict'] != null)
              .toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'อ่านคิวไม่สำเร็จ');
    }
  }

  Future<void> _syncAll() async {
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      await Future.wait([
        widget.service.sync(),
        if (_chat != null) _chat.sync(),
      ]);
      await _load();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _resolveChat(Map<String, Object?> record, bool local) async {
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      await _chat!.store.resolve(record['id'] as String, keepLocal: local);
      await _chat.sync();
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'แก้ข้อมูลข้อความขัดแย้งไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _resolving = false);
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
    final disabled =
        service.busy || (_chat?.busy ?? false) || _resolving || _syncing;
    final totalPending = _queue.length + _chatQueue.length;
    final totalConflicts = _conflicts.length + _chatConflicts.length;
    final hasCloud = service.cloud != null || _chat?.cloud != null;
    final syncError = service.error ?? _chat?.error;
    DateTime? lastSuccess = service.lastSuccess;
    if (_chat != null) {
      final chatSuccess = _chat.lastSuccess;
      if (chatSuccess == null || lastSuccess == null) {
        lastSuccess = null;
      } else if (chatSuccess.isBefore(lastSuccess)) {
        lastSuccess = chatSuccess;
      }
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? RescueTheme.darkSurface : Colors.white;
    final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
    final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
    final line = dark ? RescueTheme.darkBorder : RescueTheme.border;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'การซิงก์',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: ink,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              // 2.2 การ์ดสถานะหลักด้านบน ไล่สีกรมมุมโค้ง 24
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? [const Color(0xFF1E293B), RescueTheme.darkSurface]
                        : [RescueTheme.navy, const Color(0xFF24365C)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    // แถวบน: วงกลมไอคอน 52 พื้นส้ม + ข้อความสถานะ
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: RescueTheme.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            !hasCloud
                                ? Icons.cloud_off_outlined
                                : (syncError != null
                                      ? Icons.sync_problem_rounded
                                      : Icons.cloud_done_outlined),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                !hasCloud
                                    ? 'บันทึกในเครื่อง'
                                    : syncAgo(lastSuccess),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                !hasCloud
                                    ? 'เข้าสู่ระบบเพื่อซิงก์'
                                    : syncError != null
                                    ? 'ตรวจสอบรายการที่ยังซิงก์ไม่สำเร็จด้านล่าง'
                                    : lastSuccess != null
                                    ? '${ThaiTime.format(lastSuccess)} (เวลาไทย)'
                                    : 'ข้อมูลทั้งหมดอยู่ในเครื่องของคุณ',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // แถวกลาง: Chip สถิติ 2 ใบเท่ากัน
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.queue_outlined,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'รอซิงก์ $totalPending',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  totalConflicts > 0
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline_rounded,
                                  color: totalConflicts > 0
                                      ? RescueTheme.orange
                                      : Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'ขัดแย้ง $totalConflicts',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ล่าง: FilledButton "ซิงก์ตอนนี้"
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: RescueTheme.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: disabled || !hasCloud ? null : _syncAll,
                        icon: const Icon(Icons.sync_rounded, size: 20),
                        label: const Text(
                          'ซิงก์ตอนนี้',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (disabled) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: RescueTheme.orange,
                    backgroundColor: dark
                        ? const Color(0xFF382314)
                        : RescueTheme.peach,
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const RescueSectionLabel('SOS และข้อความ'),
              RescueGroup(
                children: [
                  RescueTile(
                    icon: Icons.sos_rounded,
                    accent: service.error != null
                        ? RescueTheme.danger
                        : RescueTheme.orange,
                    label: 'SOS',
                    subtitle: service.busy
                        ? 'กำลังซิงก์…'
                        : service.error ?? syncAgo(service.lastSuccess),
                    trailing: _statusBadge(
                      dark: dark,
                      busy: service.busy,
                      hasError: service.error != null,
                      pendingCount: _queue.length,
                      synced: service.lastSuccess != null,
                    ),
                  ),
                  RescueTile(
                    icon: Icons.chat_outlined,
                    accent: _chat?.error != null
                        ? RescueTheme.danger
                        : RescueTheme.orange,
                    label: 'ข้อความ',
                    subtitle: _chat == null
                        ? 'บันทึกในเครื่อง'
                        : _chat.busy
                        ? 'กำลังซิงก์…'
                        : _chat.error ?? syncAgo(_chat.lastSuccess),
                    trailing: _statusBadge(
                      dark: dark,
                      busy: _chat?.busy ?? false,
                      hasError: _chat?.error != null,
                      pendingCount: _chatQueue.length,
                      synced: _chat?.lastSuccess != null,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                child: Text(
                  'ซิงก์ SOS และข้อความอัตโนมัติเมื่อกลับมาออนไลน์ ข้อมูลออฟไลน์จะเก็บไว้ในเครื่อง',
                  style: TextStyle(fontSize: 12.5, color: muted, height: 1.5),
                ),
              ),
              if (_error != null || syncError != null) ...[
                const SizedBox(height: 12),
                RescueBanner(
                  _error ?? syncError!,
                  kind: RescueBannerKind.error,
                ),
              ],

              // 2.3 ถ้ามี _conflicts: หัวข้อ "ข้อมูลขัดแย้ง"
              if (_conflicts.isNotEmpty) ...[
                const RescueSectionLabel('ข้อมูลขัดแย้ง'),
                for (final record in _conflicts) _conflict(record, disabled),
              ],

              if (_chatConflicts.isNotEmpty) ...[
                const RescueSectionLabel('ข้อความที่ขัดแย้ง'),
                for (final record in _chatConflicts)
                  _chatConflict(record, disabled),
              ],
              // 2.4 หัวข้อ "คิวรอซิงก์"
              const RescueSectionLabel('คิวรอซิงก์'),
              if (totalPending == 0 && totalConflicts == 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: line),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color:
                              (dark
                                      ? const Color(0xFF4ADE80)
                                      : const Color(0xFF16A34A))
                                  .withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 42,
                          color: dark
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        !hasCloud
                            ? 'ข้อมูลอยู่ในเครื่อง'
                            : syncError != null
                            ? 'ยังซิงก์ไม่สำเร็จ'
                            : service.lastSuccess == null ||
                                  (_chat != null && _chat.lastSuccess == null)
                            ? 'ยังไม่เคยซิงก์'
                            : 'ทุกอย่างซิงก์แล้ว',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ไม่มีรายการค้างอยู่',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                )
              else
                RescueGroup(
                  children: [
                    for (final op in _chatQueue)
                      RescueTile(
                        trailing: const SizedBox.shrink(),
                        icon: op['blocked'] == 1
                            ? Icons.sync_problem
                            : Icons.chat_outlined,
                        accent: op['blocked'] == 1
                            ? const Color(0xFFE04C4C)
                            : RescueTheme.orange,
                        label: op['deleted'] == 1
                            ? 'ลบข้อความ'
                            : 'บันทึกข้อความ',
                        subtitle: op['blocked'] == 1
                            ? 'รอจัดการข้อมูลขัดแย้ง'
                            : 'รอซิงก์ประวัติข้อความ',
                      ),
                    for (final op in _queue)
                      RescueTile(
                        trailing: const SizedBox.shrink(),
                        icon: op['blocked'] == 1
                            ? Icons.sync_problem
                            : Icons.cloud_upload_outlined,
                        accent: op['blocked'] == 1
                            ? const Color(0xFFE04C4C)
                            : RescueTheme.orange,
                        label: op['deleted'] == 1
                            ? 'ลบเหตุ SOS'
                            : 'บันทึกเหตุ SOS',
                        subtitleWidget: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              SosAlert.fromJson(op['payload'] as String).name,
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ลองส่ง ${op['attempts']} ครั้ง',
                              style: TextStyle(color: muted, fontSize: 11),
                            ),
                            if (op['error'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${op['error']}',
                                style: const TextStyle(
                                  color: Color(0xFFE04C4C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
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

  Widget _statusBadge({
    required bool dark,
    required bool busy,
    required bool hasError,
    required int pendingCount,
    required bool synced,
  }) {
    if (busy) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: RescueTheme.orange,
        ),
      );
    }
    final (label, fg, bg) = hasError
        ? (
            'มีปัญหา',
            dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
            dark ? const Color(0xFF3B1818) : const Color(0xFFFEE2E2),
          )
        : pendingCount > 0
        ? (
            'รอ $pendingCount',
            dark ? const Color(0xFFFFCBA4) : const Color(0xFF9A3412),
            dark ? const Color(0xFF362112) : const Color(0xFFFFEDD5),
          )
        : synced
        ? (
            'ซิงก์แล้ว',
            dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
            dark ? const Color(0xFF132A1C) : const Color(0xFFDCFCE7),
          )
        : (
            'รอซิงก์',
            dark ? RescueTheme.darkTextMuted : RescueTheme.muted,
            dark ? const Color(0xFF1E293B) : const Color(0xFFF1ECE1),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _chatConflict(Map<String, Object?> record, bool disabled) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
    final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
    final line = dark ? RescueTheme.darkBorder : RescueTheme.border;
    final remoteDeleted =
        jsonDecode(record['conflict'] as String)?['deleted'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF281A12) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark
              ? RescueTheme.orange.withValues(alpha: 0.45)
              : const Color(0xFFFFB17B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: RescueTheme.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ประวัติข้อความมีการแก้ไขจากหลายเครื่อง',
                  style: TextStyle(
                    color: ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'เลือกเวอร์ชันของข้อความที่ต้องการเก็บไว้ในบัญชีของคุณ',
            style: TextStyle(fontSize: 12.5, color: muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      side: BorderSide(color: line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: disabled
                        ? null
                        : () => _resolveChat(record, false),
                    child: const Text(
                      'ใช้ข้อมูล Cloud',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: RescueTheme.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: disabled || remoteDeleted
                        ? null
                        : () => _resolveChat(record, true),
                    child: const Text(
                      'ใช้ข้อมูลในเครื่อง',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conflict(SosRecord record, bool disabled) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? RescueTheme.darkSurface : Colors.white;
    final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
    final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
    final line = dark ? RescueTheme.darkBorder : RescueTheme.border;

    final remote = jsonDecode(record.conflict!) as Map<String, dynamic>?;
    final remoteAlert = remote == null
        ? null
        : SosAlert.fromJson(jsonEncode(remote['payload']));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF281A12) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark
              ? RescueTheme.orange.withValues(alpha: 0.45)
              : const Color(0xFFFFB17B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: RescueTheme.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.alert.name,
                  style: TextStyle(
                    color: ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // กล่องข้อมูลในเครื่อง
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ในเครื่อง${record.deleted ? ' (ลบ)' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.alert.summary,
                  style: TextStyle(fontSize: 13, color: ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // กล่องข้อมูล Cloud
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cloud${remote?['deleted'] == true ? ' (ลบแล้ว)' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  remoteAlert?.summary ?? 'ไม่พบข้อมูล',
                  style: TextStyle(fontSize: 13, color: ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // แถวปุ่มล่าง 2 ปุ่มขนาดเท่ากัน
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      side: BorderSide(color: line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: disabled ? null : () => _resolve(record, false),
                    child: const Text(
                      'ใช้ข้อมูล Cloud',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: RescueTheme.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: disabled || remote?['deleted'] == true
                        ? null
                        : () => _resolve(record, true),
                    child: const Text(
                      'ใช้ข้อมูลในเครื่อง',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
