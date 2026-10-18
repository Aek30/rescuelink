import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import 'bundled_offline_map.dart';

class OfflineLocationMap extends StatelessWidget {
  const OfflineLocationMap({super.key, required this.location});
  final SosLocation location;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BundledOfflineMap(
          focus: location,
          markers: [
            OfflineMapMarker(
              id: 'received',
              label: 'ตำแหน่งที่ได้รับ',
              location: location,
              color: const Color(0xFFC94B2B),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ตำแหน่งที่ได้รับ • ไม่ใช่ตำแหน่งปัจจุบันของคุณ'),
              Text(
                '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              ),
              Text(
                'ความแม่นยำที่บันทึก ±${location.accuracy.toStringAsFixed(0)} ม.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
