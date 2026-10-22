import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sos_alert.dart';
import '../services/message_service.dart';
import '../theme/rescue_theme.dart';
import '../widgets/bundled_offline_map.dart';
import '../widgets/emergency_type_chip.dart';
import '../widgets/incident_status_chip.dart';
import 'chat_screen.dart';

class IncidentDetailScreen extends StatefulWidget {
  const IncidentDetailScreen({
    super.key,
    required this.service,
    required this.peerId,
  });
  final MessageService service;
  final String peerId;
  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  late final Timer _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

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
    final d = value.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year + 543} ${sosClock(d)}';
  }

  void _mapInfo() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เกี่ยวกับแผนที่',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const Text(
              'แผนที่ถนนออฟไลน์ครอบคลุมจังหวัดปทุมธานี นอกพื้นที่นี้ยังอ่านและคัดลอกพิกัดได้\n\nแตะแผนที่เพื่อเปิดเต็มจอ แล้วเลื่อนหรือกางนิ้วเพื่อซูม\n\nพิกัดเป็นจุดที่ผู้ส่งบันทึก ไม่ใช่ตำแหน่งติดตามสด วงกลมแสดงความแม่นยำที่รายงาน ไม่ใช่ขอบเขตภัยพิบัติ\n\nการเปิดในแอปแผนที่ภายนอกต้องมีเน็ตหรือแผนที่พื้นที่ที่ดาวน์โหลดไว้',
            ),
            const SizedBox(height: 16),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      ),
    ),
  );

  List<OfflineMapMarker> _markers(
    SosLocation location,
    bool active,
    bool stale,
  ) => [
    OfflineMapMarker(
      id: 'incident',
      label: stale ? 'ตำแหน่งที่บันทึก • ข้อมูลเก่า' : 'ตำแหน่งที่บันทึก',
      location: location,
      color: active
          ? kSosRed.withValues(alpha: stale ? .55 : 1)
          : const Color(0xFF536572),
      onTap: () {},
    ),
  ];

  void _openMap(SosLocation location, bool active, bool stale) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('ตำแหน่งเหตุ SOS')),
            body: BundledOfflineMap(
              focus: location,
              fullScreen: true,
              showAccuracyCircles: true,
              markers: _markers(location, active, stale),
            ),
          ),
        ),
      );

  Widget _map(SosLocation location, bool active, bool stale) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      height: 240,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'เปิดแผนที่เต็มจอ',
              child: GestureDetector(
                onTap: () => _openMap(location, active, stale),
                child: IgnorePointer(
                  child: BundledOfflineMap(
                    key: const ValueKey('incident-map'),
                    focus: location,
                    fullScreen: true,
                    compact: true,
                    showAccuracyCircles: true,
                    showOfflineBadge: false,
                    markers: _markers(location, active, stale),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ออฟไลน์',
                style: TextStyle(
                  fontSize: 12,
                  color: RescueTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'ข้อมูลแผนที่',
                    color: RescueTheme.orangeInk,
                    onPressed: _mapInfo,
                    icon: const Icon(Icons.info_outline),
                  ),
                  IconButton(
                    tooltip: 'เปิดแผนที่เต็มจอ',
                    color: RescueTheme.orangeInk,
                    onPressed: () => _openMap(location, active, stale),
                    icon: const Icon(Icons.fullscreen),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tile(IconData icon, String label, Widget value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: RescueTheme.navy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF536572)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        value,
      ],
    ),
  );

  Widget _location(SosLocation location, bool stale, int age) => SosCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'พิกัดที่ผู้ส่งบันทึก',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                sosCoordinates(location),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF536572),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              tooltip: 'คัดลอกพิกัด',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: sosCoordinates(location)),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('คัดลอกพิกัดแล้ว')),
                  );
                }
              },
            ),
          ],
        ),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              location.manuallySelected
                  ? 'ปักหมุดเอง • ไม่ได้วัดความแม่นยำ GPS'
                  : 'ความแม่นยำ ±${location.accuracy.round()} ม.',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'บันทึกเมื่อ ${_date(location.capturedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: stale ? const Color(0xFFFFF3CD) : RescueTheme.cream,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: stale
                    ? const Color(0xFF946000)
                    : const Color(0xFF536572),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'อายุตำแหน่ง $age นาที${stale ? ' • ข้อมูลเก่า' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: stale
                        ? const Color(0xFF946000)
                        : const Color(0xFF536572),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () async {
              try {
                await const MethodChannel(
                  'com.rmutt.rescuelink/maps',
                ).invokeMethod<void>('open', {
                  'latitude': location.latitude,
                  'longitude': location.longitude,
                });
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'เปิดแอปแผนที่ไม่ได้ ใช้ปุ่มคัดลอกพิกัดได้',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('เปิดในแอปแผนที่'),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: RescueTheme.light.copyWith(
      textTheme: RescueTheme.light.textTheme.apply(
        bodyColor: RescueTheme.navy,
        displayColor: RescueTheme.navy,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    ),
    child: Builder(
      builder: (context) => ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final service = widget.service;
          final presence = service.presence[widget.peerId];
          final alert = presence?.sos;
          final now = DateTime.now().toUtc();
          final active = alert?.isActiveAt(now) == true;
          final location = alert != null
              ? alert.location
              : (presence?.rescue == true ? presence?.rescueLocation : null);
          final stale =
              location != null &&
              now.difference(location.capturedAt) > const Duration(minutes: 15);
          final name = alert?.name.trim().isNotEmpty == true
              ? alert!.name
              : service.peers[widget.peerId] ?? widget.peerId;
          final age = location == null
              ? null
              : now.difference(location.capturedAt).inMinutes.clamp(0, 999999);
          return Scaffold(
            backgroundColor: RescueTheme.cream,
            appBar: AppBar(
              title: const Text(
                'รายละเอียด SOS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: RescueTheme.orangeInk,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ChatScreen(service: service, peerId: widget.peerId),
                      ),
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('ติดต่อผ่านแชต'),
                  ),
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  key: const ValueKey('incident-header'),
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFFFF0F1) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? kSosRed.withValues(alpha: .18)
                          : RescueTheme.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: RescueTheme.peach,
                        foregroundColor: RescueTheme.navy,
                        child: Text(
                          name.isEmpty ? '?' : name.characters.first,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                IncidentStatusChip(
                                  label: active
                                      ? 'SOS'
                                      : alert?.isExpired(now) == true
                                      ? 'SOS หมดอายุ'
                                      : alert != null
                                      ? 'SOS ยกเลิกแล้ว'
                                      : presence?.rescue == true
                                      ? 'หน่วยกู้ภัย'
                                      : 'ไม่มี SOS',
                                  color: active
                                      ? kSosRed
                                      : const Color(0xFF536572),
                                  icon: active ? Icons.sos : Icons.info_outline,
                                ),
                                PeerConnectionChip(
                                  service: service,
                                  peerId: widget.peerId,
                                ),
                              ],
                            ),
                            if (alert != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'อัปเดตเมื่อ ${sosAge(alert.updatedAt, now: now)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF536572),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (alert != null) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const columns = 2;
                      final width =
                          (constraints.maxWidth - 8 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: width,
                            child: _tile(
                              Icons.category_outlined,
                              'ประเภทเหตุ',
                              EmergencyTypeChips(types: alert.categories),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _tile(
                              Icons.people_outline,
                              'ผู้ต้องการความช่วยเหลือ',
                              Text(
                                '${alert.people} คน',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'ยังไม่มีรายละเอียดเหตุที่ได้รับ',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                if (alert != null && alert.details.isNotEmpty)
                  SosCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notes_outlined,
                          color: RescueTheme.navy,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SelectableText(
                            alert.details,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (location != null) ...[
                  _map(location, active, stale),
                  const SizedBox(height: 16),
                  _location(location, stale, age!),
                ] else
                  const SosCard(
                    child: Text(
                      'ไม่แนบพิกัด • ขอรายละเอียดเพิ่มเติมผ่านแชต',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                Container(
                  key: const ValueKey('incident-receipt-notice'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1DDA4)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Color(0xFF946000),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ได้รับข้อความ ≠ มีหน่วยกู้ภัยตอบรับ',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF795500),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
