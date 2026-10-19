import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';

IconData emergencyIcon(EmergencyType type) => switch (type) {
  EmergencyType.flood => Icons.flood_outlined,
  EmergencyType.fire => Icons.local_fire_department_outlined,
  EmergencyType.accident => Icons.car_crash_outlined,
  EmergencyType.medical => Icons.medical_services_outlined,
  EmergencyType.trapped => Icons.person_pin_circle_outlined,
  EmergencyType.supplies => Icons.water_drop_outlined,
  EmergencyType.other => Icons.sos_rounded,
};

class EmergencyTypeChip extends StatelessWidget {
  const EmergencyTypeChip({super.key, required this.type});
  final EmergencyType type;
  @override
  Widget build(BuildContext context) {
    final color = RescueTheme.accentFor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(emergencyIcon(type), size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              type.shortLabel,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class EmergencyTypeChips extends StatelessWidget {
  const EmergencyTypeChips({super.key, required this.types});
  final List<EmergencyType> types;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final type in types) EmergencyTypeChip(type: type)],
  );
}

class SosCard extends StatelessWidget {
  const SosCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161C24)
          : Colors.white,
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF283442)
            : RescueTheme.border,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

String sosAge(DateTime time, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(time);
  if (age.inMinutes < 1) return 'เมื่อสักครู่';
  if (age.inMinutes < 60) return '${age.inMinutes} นาทีที่แล้ว';
  if (age.inHours < 24) return '${age.inHours} ชม. ที่แล้ว';
  return '${age.inDays} วันที่แล้ว';
}

String sosClock(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

bool sosLocationStale(SosLocation location) =>
    DateTime.now().difference(location.capturedAt) > const Duration(minutes: 5);

Color sosWarningColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFCE73)
    : const Color(0xFF946000);

class SosStaleWarning extends StatelessWidget {
  const SosStaleWarning({super.key});
  @override
  Widget build(BuildContext context) {
    final color = sosWarningColor(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ตำแหน่งเก่า',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SosLocationStatusChip extends StatelessWidget {
  const SosLocationStatusChip({super.key, required this.location});
  final SosLocation location;
  @override
  Widget build(BuildContext context) {
    final color = RescueTheme.mutedFor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        sosLocationAge(location),
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}

String sosCoordinates(SosLocation location) =>
    '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';

String sosLocationAge(SosLocation location) =>
    '${location.manuallySelected ? 'ปักหมุดเอง' : 'แม่นยำ ±${location.accuracy.round()} ม.'} • บันทึก${sosAge(location.capturedAt)}';
