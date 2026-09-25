import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sos_alert.dart';

class LocationButton extends StatelessWidget {
  const LocationButton({super.key, required this.location});
  final SosLocation location;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'พิกัดบันทึกเมื่อ ${location.capturedAt.toLocal()} • อายุ ${DateTime.now().difference(location.capturedAt).inMinutes.clamp(0, 999999)} นาที',
      ),
      const Text('แผนที่ออฟไลน์ต้องมีข้อมูลแผนที่ดาวน์โหลดไว้ในแอปแผนที่'),
      SelectableText('${location.latitude}, ${location.longitude}'),
      TextButton.icon(
        icon: const Icon(Icons.copy),
        label: const Text('คัดลอกพิกัด'),
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: '${location.latitude}, ${location.longitude}'),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('คัดลอกพิกัดแล้ว')));
          }
        },
      ),
      TextButton.icon(
        icon: const Icon(Icons.map_outlined),
        label: const Text('เปิดตำแหน่งบนแผนที่'),
        onPressed: () async {
          try {
            await const MethodChannel(
              'com.rmutt.rescuelink/maps',
            ).invokeMethod<void>('open', {
              'latitude': location.latitude,
              'longitude': location.longitude,
            });
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'เปิดแผนที่ไม่ได้ หรือไม่มีแอปแผนที่รองรับ เลือกคัดลอกตัวเลขพิกัดด้านบนได้',
                  ),
                ),
              );
            }
          }
        },
      ),
    ],
  );
}
