import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';
import 'bundled_offline_map.dart';
import 'emergency_type_chip.dart';

class SosLocationCard extends StatelessWidget {
  const SosLocationCard({
    super.key,
    required this.location,
    required this.reading,
    required this.onRefresh,
    required this.onChanged,
  });
  final SosLocation? location;
  final bool reading;
  final VoidCallback onRefresh;
  final ValueChanged<SosLocation> onChanged;

  List<OfflineMapMarker> _markers(SosLocation? value) => value == null
      ? []
      : [
          OfflineMapMarker(
            id: 'sos-pin',
            label: 'ตำแหน่ง SOS',
            location: value,
            color: kSosRed,
          ),
        ];

  Future<void> _pick(BuildContext context) async {
    var selected = location;
    final result = await Navigator.of(context).push<SosLocation>(
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, update) => Scaffold(
            appBar: AppBar(title: const Text('ปรับหมุด SOS')),
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'แตะบนแผนที่เพื่อปรับหมุด\nกดค้าง − เพื่อดูทั้งพื้นที่',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: BundledOfflineMap(
                    fullScreen: true,
                    focus: selected,
                    markers: _markers(selected),
                    onPickLocation: (value) => update(() => selected = value),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(context, selected),
                      child: const Text('ใช้ตำแหน่งนี้'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final value = location;
    final muted = RescueTheme.mutedFor(context);
    final stale = value != null && sosLocationStale(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '2  ตำแหน่ง',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'ข้อมูลแผนที่ออฟไลน์',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                builder: (_) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'แผนที่ถนนออฟไลน์ครอบคลุมจังหวัดปทุมธานี\n\n'
                    'ปรับหมุดได้ภายในพื้นที่แผนที่ นอกพื้นที่นี้ยังอ่านและคัดลอกพิกัด GPS ได้ '
                    'การเปิดแอปแผนที่ภายนอกต้องมีเน็ตหรือแผนที่ที่ดาวน์โหลดไว้',
                  ),
                ),
              ),
            ),
          ],
        ),
        Semantics(
          button: true,
          label: 'เปิดแผนที่เต็มจอเพื่อปรับหมุด',
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 132,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: BundledOfflineMap(
                      fullScreen: true,
                      compact: true,
                      height: 132,
                      focus: value,
                      markers: _markers(value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (value != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  sosCoordinates(value),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              IconButton(
                tooltip: 'คัดลอกพิกัด',
                icon: const Icon(Icons.copy_outlined, size: 20),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: sosCoordinates(value)),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('คัดลอกพิกัดแล้ว')),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: 'เปิดในแอปแผนที่',
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () async {
                  try {
                    await const MethodChannel(
                      'com.rmutt.rescuelink/maps',
                    ).invokeMethod('open', {
                      'latitude': value.latitude,
                      'longitude': value.longitude,
                    });
                  } catch (error) {
                    debugPrint('Open SOS map: $error');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'เปิดแผนที่ไม่ได้ สามารถคัดลอกพิกัดได้',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          SosLocationStatusChip(location: value),
        ] else
          Text(
            'ยังไม่มีพิกัด • ส่ง SOS ได้โดยไม่แนบตำแหน่ง',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        if (stale)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SosStaleWarning(),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: reading ? null : onRefresh,
            icon: Icon(reading ? Icons.hourglass_top : Icons.my_location),
            label: Text(reading ? 'กำลังอัปเดตตำแหน่ง…' : 'อัปเดตตำแหน่ง'),
          ),
        ),
      ],
    );
  }
}

