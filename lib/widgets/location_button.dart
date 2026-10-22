import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';
import 'bundled_offline_map.dart';

class LocationButton extends StatelessWidget {
  const LocationButton({super.key, required this.location});
  final SosLocation location;

  void _showMapInfo(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : RescueTheme.navy;
    final muted = dark ? RescueTheme.darkTextMuted : const Color(0xFF5B6675);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: dark ? RescueTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: RescueTheme.rescue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ข้อมูลแผนที่และตำแหน่ง',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'ตำแหน่งที่ได้รับ • ไม่ใช่ตำแหน่งปัจจุบันของคุณ\n'
                'เลื่อน/กางนิ้วเพื่อซูม • ไม่มีระบบนำทางตามถนน\n\n'
                'แผนที่ถนนออฟไลน์ครอบคลุมจังหวัดปทุมธานี\n'
                'นอกพื้นที่นี้ยังอ่านและคัดลอกพิกัดได้ การเปิดแอปแผนที่ภายนอกต้องมีเน็ตหรือข้อมูลพื้นที่ที่ดาวน์โหลดไว้ (ต้องมีเน็ตหรือแผนที่ที่ดาวน์โหลดไว้)',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: muted,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = dark ? RescueTheme.darkSurface : Colors.white;
    final borderColor = dark ? RescueTheme.darkBorder : RescueTheme.border;
    final ink = dark ? Colors.white : RescueTheme.navy;
    final muted = dark ? RescueTheme.darkTextMuted : const Color(0xFF5B6675);

    final minutes = DateTime.now()
        .difference(location.capturedAt)
        .inMinutes
        .clamp(0, 999999);
    final isStale = minutes > 15;
    final coordsDisplay =
        '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              child: BundledOfflineMap(
                height: 200,
                fullScreen: true,
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
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: RescueTheme.rescue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(
                  coordsDisplay,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'คัดลอกพิกัด',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.copy_rounded, size: 18, color: muted),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: '${location.latitude}, ${location.longitude}',
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('คัดลอกพิกัดแล้ว')),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: 'ข้อมูลแผนที่',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.info_outline_rounded, size: 19, color: muted),
                onPressed: () => _showMapInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _LocationMetaChip(
                icon: Icons.my_location_rounded,
                label: '±${location.accuracy.toStringAsFixed(0)} ม.',
                color: muted,
                backgroundColor: muted.withValues(alpha: .10),
              ),
              _LocationMetaChip(
                icon: Icons.schedule_rounded,
                label: '$minutes นาทีที่แล้ว',
                color: muted,
                backgroundColor: muted.withValues(alpha: .10),
              ),
              if (isStale)
                _LocationMetaChip(
                  icon: Icons.warning_amber_rounded,
                  label: 'ข้อมูลเก่า',
                  color: dark
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFF92400E),
                  backgroundColor: dark
                      ? const Color(0xFF33260D)
                      : const Color(0xFFFEF3C7),
                  borderColor: dark
                      ? const Color(0xFF664D1A)
                      : const Color(0xFFFDE68A),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                backgroundColor: cardBg,
                side: BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text(
                'เปิดในแอปแผนที่',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
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
          ),
        ],
      ),
    );
  }
}

class _LocationMetaChip extends StatelessWidget {
  const _LocationMetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(9),
      border: borderColor != null ? Border.all(color: borderColor!) : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
