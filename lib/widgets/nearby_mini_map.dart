import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/message_service.dart';
import '../services/sos_location_service.dart';
import '../screens/incident_detail_screen.dart';

/// North-up local coordinate map. Never infers positions from discovery/RSSI.
class NearbyMiniMap extends StatefulWidget {
  const NearbyMiniMap({super.key, required this.service, this.capture});
  final MessageService service;
  final Future<SosLocation> Function()? capture;
  @override
  State<NearbyMiniMap> createState() => _NearbyMiniMapState();
}

class _NearbyMiniMapState extends State<NearbyMiniMap> {
  SosLocation? _me;
  bool _loading = false;
  String? _error;
  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fix =
          await (widget.capture?.call() ?? SosLocationService().capture());
      if (mounted) setState(() => _me = fix);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'อ่านตำแหน่งไม่ได้ ตรวจสิทธิ์/GPS แล้วลองใหม่');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Offset _relative(SosLocation point, SosLocation origin) {
    final longitude = (point.longitude - origin.longitude + 540) % 360 - 180;
    return Offset(
      longitude * 111320 * math.cos(origin.latitude * math.pi / 180),
      -(point.latitude - origin.latitude) * 111320,
    );
  }

  void _open(String id) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => IncidentDetailScreen(service: widget.service, peerId: id),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final points = widget.service.presence.entries
          .where((e) => e.value.sos?.location != null)
          .toList();
      final origin =
          _me ?? (points.isEmpty ? null : points.first.value.sos!.location!);
      final offsets = {
        for (final e in points)
          e.key: _relative(e.value.sos!.location!, origin!),
      };
      double extent = 100;
      for (final p in offsets.values) {
        extent = math.max(extent, math.max(p.dx.abs(), p.dy.abs()) * 1.3);
      }
      final now = DateTime.now().toUtc();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161C24) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF283442) : const Color(0xFFE2E8E4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'แผนที่รอบตัว',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'มีพิกัด ${points.length} เครื่อง • ใช้ได้ออฟไลน์',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 280,
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final scale =
                      (math.min(bounds.maxWidth, bounds.maxHeight) - 72) /
                      (extent * 2);
                  final center = Offset(
                    bounds.maxWidth / 2,
                    bounds.maxHeight / 2,
                  );
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _MapGrid(isDark: isDark)),
                      ),
                      const Positioned(top: 12, right: 14, child: Text('↑ N')),
                      if (origin == null)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                              'ยังไม่มีพิกัด\nกด “ตำแหน่งของฉัน” เพื่อเริ่มดูแผนที่',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      for (final e in points)
                        Positioned(
                          left: center.dx + offsets[e.key]!.dx * scale - 24,
                          top: center.dy + offsets[e.key]!.dy * scale - 24,
                          child: IconButton.filled(
                            tooltip:
                                '${widget.service.peers[e.key] ?? 'ไม่ทราบชื่อ'} • แตะดูรายละเอียด',
                            style: IconButton.styleFrom(
                              backgroundColor: e.value.sos!.isActiveAt(now)
                                  ? const Color(0xFFC83D32)
                                  : e.value.isFresh(now) && e.value.rescue
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            onPressed: () => _open(e.key),
                            icon: const Icon(Icons.person_pin_circle_outlined),
                          ),
                        ),
                      if (_me != null)
                        Positioned(
                          left: center.dx - 18,
                          top: center.dy - 18,
                          child: Tooltip(
                            message: 'ฉัน • พิกัดที่อ่านล่าสุด',
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF167A65),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      if (origin != null)
                        Positioned(
                          bottom: 10,
                          left: 12,
                          child: Container(
                            color: isDark
                                ? const Color(0xFF161C24).withValues(alpha: .9)
                                : Colors.white.withValues(alpha: .9),
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              'จากกึ่งกลางถึงขอบพื้นที่วาด ≈ ${extent.round()} ม.',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'เขียว: ฉัน  •  แดง: SOS  •  น้ำเงิน: กู้ภัย\nเทา: สถานะเก่า/ปิดแล้ว',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'แผนภาพจากพิกัด GPS ไม่มีถนนหรือการนำทาง\nอุปกรณ์ที่ไม่มีพิกัดจะแสดงเฉพาะในรายการด้านล่าง',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF63736B),
                    ),
                  ),
                  if (_me == null && points.isNotEmpty)
                    const Text(
                      'กึ่งกลางอ้างอิงพิกัดที่ได้รับ ไม่ใช่ตำแหน่งของคุณ',
                    ),
                  if (_me != null)
                    Text(
                      'ฉัน: ${_me!.latitude.toStringAsFixed(5)}, ${_me!.longitude.toStringAsFixed(5)}\n±${_me!.accuracy.round()} ม. • บันทึก ${_me!.capturedAt.toLocal()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _locate,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _loading
                          ? 'กำลังอ่าน GPS…'
                          : _me == null
                          ? 'ตำแหน่งของฉัน'
                          : 'อัปเดตตำแหน่งของฉัน',
                    ),
                  ),
                  for (final e in points)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        widget.service.peers[e.key] ?? 'เครื่องที่ไม่ทราบชื่อ',
                      ),
                      subtitle: Text(
                        '${e.value.isFresh(now) ? 'สถานะล่าสุด' : 'สถานะหมดอายุ'} • พิกัดบันทึก ${e.value.sos!.location!.capturedAt.toLocal()}',
                      ),
                      onTap: () => _open(e.key),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _MapGrid extends CustomPainter {
  const _MapGrid({this.isDark = false});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = isDark ? const Color(0xFF0F1512) : const Color(0xFFEDF4EF),
    );
    final paint = Paint()
      ..color = isDark ? const Color(0xFF1B2822) : const Color(0xFFDCE7DF)
      ..strokeWidth = 1;
    for (double x = size.width / 2 % 24; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = size.height / 2 % 24; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGrid oldDelegate) =>
      oldDelegate.isDark != isDark;
}
