import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/sos_alert.dart';

/// A local coordinate diagram. No tiles, invented roads, or network requests.
class OfflineLocationMap extends StatelessWidget {
  const OfflineLocationMap({super.key, required this.location});
  final SosLocation location;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFEDF4F0),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE6E0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label:
              'แผนภาพพิกัดออฟไลน์ จุดกึ่งกลางคือพิกัดที่ได้รับ ไม่มีข้อมูลถนน',
          child: SizedBox(
            height: 160,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CoordinatePainter()),
                ),
                const Positioned(
                  top: 12,
                  right: 12,
                  child: Text(
                    '↑ N',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFC94B2B),
                        size: 40,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ตำแหน่งที่ได้รับ',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'แผนภาพพิกัด • ใช้ได้ออฟไลน์',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              ),
              Text(
                'ความแม่นยำที่บันทึก ±${location.accuracy.toStringAsFixed(0)} ม.',
              ),
              const SizedBox(height: 4),
              const Text(
                'ไม่มีข้อมูลถนนหรือเส้นทาง • กริดไม่มีมาตราส่วน\nไม่ใช่ตำแหน่งปัจจุบันของคุณ',
                style: TextStyle(fontSize: 11, color: Color(0xFF52635A)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CoordinatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFDCE6E0)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      math.min(size.width, size.height) * .35,
      Paint()..color = const Color(0xFFC8DED1).withValues(alpha: .45),
    );
  }

  @override
  bool shouldRepaint(covariant _CoordinatePainter oldDelegate) => false;
}
