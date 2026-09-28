import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/message_service.dart';
import '../services/sos_location_service.dart';
import '../screens/chat_screen.dart';
import '../screens/incident_detail_screen.dart';

double sosDistance(SosLocation a, SosLocation b) {
  const r = math.pi / 180;
  final h =
      math.pow(math.sin((b.latitude - a.latitude) * r / 2), 2) +
      math.cos(a.latitude * r) *
          math.cos(b.latitude * r) *
          math.pow(math.sin((b.longitude - a.longitude) * r / 2), 2);
  return 12742000 * math.asin(math.sqrt(h.clamp(0, 1)));
}

class SosRadar extends StatefulWidget {
  const SosRadar({super.key, required this.service, this.captureLocation});
  final MessageService service;
  final Future<SosLocation> Function()? captureLocation;
  @override
  State<SosRadar> createState() => _SosRadarState();
}

class _SosRadarState extends State<SosRadar> {
  SosLocation? _origin;
  double _radius = 200;
  bool _locating = false;
  String? _error;
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final fix =
          await (widget.captureLocation ?? SosLocationService().capture)();
      if (mounted) setState(() => _origin = fix);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'อ่านตำแหน่งไม่ได้ กรุณาเปิด GPS และอนุญาตตำแหน่ง แล้วลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final now = DateTime.now().toUtc();
      bool fresh(SosLocation? p) =>
          p != null &&
          !now.isBefore(p.capturedAt) &&
          now.difference(p.capturedAt) <= const Duration(minutes: 2);
      double? distance(SosAlert alert) =>
          fresh(_origin) && fresh(alert.location)
          ? sosDistance(_origin!, alert.location!)
          : null;
      final entries =
          widget.service.presence.entries
              .where(
                (e) =>
                    e.key != widget.service.myId &&
                    e.value.sos?.active == true &&
                    e.value.isFresh(now),
              )
              .toList()
            ..sort(
              (a, b) => (distance(a.value.sos!) ?? double.infinity).compareTo(
                distance(b.value.sos!) ?? double.infinity,
              ),
            );
      final within = entries.where((e) {
        final d = distance(e.value.sos!);
        return d != null && d <= _radius;
      }).toList();
      final unknown = entries
          .where((e) => distance(e.value.sos!) == null)
          .toList();
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161C24) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isDark ? Border.all(color: const Color(0xFF283442)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFF347CF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'โหมดหน่วยกู้ภัยกำลังทำงาน (Radar Active)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'รัศมีแสดง SOS ${_radius.toInt()} เมตร',
              textAlign: TextAlign.center,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final radius in [100.0, 200.0, 500.0])
                  ChoiceChip(
                    label: Text('${radius.toInt()} ม.'),
                    selected: radius == _radius,
                    onSelected: (_) => setState(() => _radius = radius),
                  ),
              ],
            ),
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _RadarPainter(
                    radius: _radius,
                    isDark: isDark,
                    points: [
                      for (final e in within)
                        _radarPoint(
                          _origin!,
                          e.value.sos!.location!,
                          distance(e.value.sos!)! / _radius,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              'ทิศเหนืออยู่ด้านบน • จุดสีน้ำเงินคือตำแหน่งคุณ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : Colors.blueGrey,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _locating ? null : _locate,
              icon: const Icon(Icons.my_location),
              label: Text(
                _locating ? 'กำลังอ่านตำแหน่ง…' : 'อัปเดตตำแหน่งเพื่อคำนวณระยะ',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!fresh(_origin))
              const Text(
                'ยังไม่มีพิกัดปัจจุบันของคุณ • แสดงผู้ส่ง SOS โดยไม่ระบุระยะ',
              ),
            if (fresh(_origin))
              Text(
                'พิกัดคุณ ±${_origin!.accuracy.round()} ม. • ${_origin!.capturedAt.toLocal()}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 12),
            Text(
              'รายการ SOS ในรัศมี ${within.length} ราย',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (within.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('ยังไม่พบ SOS ที่ยืนยันระยะในรัศมีนี้ได้'),
              ),
            if (unknown.isNotEmpty)
              Text(
                'ไม่ทราบระยะ ${unknown.length} ราย • ไม่มีพิกัดหรือพิกัดเก่า',
              ),
            for (final entry in [...within, ...unknown])
              Card(
                color: isDark ? const Color(0xFF1E2631) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF3D2528)
                        : const Color(0xFFFFDDDD),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value.sos!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${entry.value.sos!.category.label} • ${entry.value.sos!.people} คน',
                      ),
                      Text(
                        distance(entry.value.sos!) == null
                            ? 'ไม่ทราบระยะ'
                            : 'ระยะประมาณ ${distance(entry.value.sos!)!.round()} เมตร • คลาดเคลื่อน ±${(_origin!.accuracy + entry.value.sos!.location!.accuracy).round()} ม.',
                      ),
                      Text(
                        'รับสถานะ ${now.difference(entry.value.receivedAt).inSeconds} วินาทีที่แล้ว',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => IncidentDetailScreen(
                                  service: widget.service,
                                  peerId: entry.key,
                                ),
                              ),
                            ),
                            child: const Text('ดูรายละเอียด'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ChatScreen(
                                  service: widget.service,
                                  peerId: entry.key,
                                ),
                              ),
                            ),
                            child: const Text('แชต'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (entries.length > within.length + unknown.length)
              Text(
                'นอกระยะที่เลือก ${entries.length - within.length - unknown.length} ราย • ดูได้ในรายการสถานะด้านล่าง',
              ),
            const SizedBox(height: 8),
            Text(
              'แสดงสถานะ SOS ที่ได้รับภายใน 30 วินาที ผ่านอุปกรณ์ที่เชื่อมต่อ '
              'รัศมีเป็นตัวกรองจาก GPS ไม่ใช่ระยะรับสัญญาณที่รับประกัน',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : Colors.blueGrey,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Offset _radarPoint(SosLocation a, SosLocation b, double fraction) {
  const r = math.pi / 180;
  final lon = (b.longitude - a.longitude) * r;
  final bearing = math.atan2(
    math.sin(lon) * math.cos(b.latitude * r),
    math.cos(a.latitude * r) * math.sin(b.latitude * r) -
        math.sin(a.latitude * r) * math.cos(b.latitude * r) * math.cos(lon),
  );
  return Offset(math.sin(bearing) * fraction, -math.cos(bearing) * fraction);
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.radius,
    required this.points,
    this.isDark = false,
  });
  final double radius;
  final List<Offset> points;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final extent = size.shortestSide / 2 - 20;
    final ring = Paint()
      ..color = isDark ? const Color(0xFF283A54) : const Color(0xFFD5E4FF)
      ..style = PaintingStyle.stroke;
    for (final fraction in [0.33, 0.67, 1.0]) {
      canvas.drawCircle(center, extent * fraction, ring);
    }
    canvas.drawLine(center, center + Offset(0, -extent), ring);
    final label = TextPainter(
      text: TextSpan(
        text: '${radius.toInt()} ม. • N',
        style: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : Colors.blueGrey,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(center.dx - label.width / 2, 0));
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF347CF5));
    for (final point in points) {
      canvas.drawCircle(
        center + point * extent,
        5,
        Paint()..color = const Color(0xFFFF5252),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.points != points ||
      oldDelegate.isDark != isDark;
}
