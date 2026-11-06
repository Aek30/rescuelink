import 'package:flutter/material.dart';
import '../models/sos_emergency_info.dart';
import '../theme/rescue_theme.dart';

class SosEmergencyInfoSummary extends StatelessWidget {
  const SosEmergencyInfoSummary({super.key, required this.info});
  final Map<String, String> info;
  @override
  Widget build(BuildContext context) {
    if (info.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = RescueTheme.accentFor(context);
    final muted = RescueTheme.mutedFor(context);
    final border = dark ? RescueTheme.darkBorder : RescueTheme.border;
    const icons = {
      'full_name': Icons.person_outline_rounded,
      'phone': Icons.phone_outlined,
      'date_of_birth': Icons.cake_outlined,
      'medical_conditions': Icons.medical_information_outlined,
      'allergies': Icons.health_and_safety_outlined,
      'medications': Icons.medication_outlined,
      'medical_notes': Icons.notes_rounded,
      'blood_group': Icons.bloodtype_outlined,
      'emergency_contact': Icons.contact_phone_outlined,
    };
    final visibleGroups = sosEmergencyGroups.entries
        .where((group) => group.value.any(info.containsKey))
        .toList();
    Widget field(String key) {
      final highlight = key == 'allergies';
      final contact = key == 'emergency_contact';
      final color = highlight
          ? (dark ? const Color(0xFFFFA6A6) : kSosRed)
          : contact
          ? (dark ? const Color(0xFF8CDAC1) : const Color(0xFF167A65))
          : accent;
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight || contact
              ? color.withValues(alpha: dark ? .10 : .06)
              : (dark
                    ? Colors.white.withValues(alpha: .035)
                    : const Color(0xFFFAF8F5)),
          borderRadius: BorderRadius.circular(12),
          border: highlight
              ? Border.all(color: color.withValues(alpha: .18))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icons[key], size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sosEmergencyLabels[key]!,
                    style: TextStyle(
                      fontSize: 12,
                      color: highlight ? color : muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    info[key]!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: highlight || contact
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('sos-emergency-info-card'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF161C24) : Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.medical_information_outlined,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ข้อมูลฉุกเฉินที่แนบ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${info.length} รายการ',
                  style: TextStyle(
                    fontSize: 11,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ข้อมูลที่ผู้แจ้งเลือกแนบกับ SOS นี้',
            style: TextStyle(fontSize: 12, color: muted, height: 1.5),
          ),
          for (var i = 0; i < visibleGroups.length; i++) ...[
            const SizedBox(height: 16),
            if (i > 0) ...[
              Divider(height: 1, color: border),
              const SizedBox(height: 16),
            ],
            Text(
              visibleGroups[i].key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            for (final key in visibleGroups[i].value.where(info.containsKey))
              field(key),
          ],
        ],
      ),
    );
  }
}
