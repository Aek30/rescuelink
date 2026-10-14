import 'package:flutter/material.dart';
import '../theme/rescue_theme.dart';

class SosConfirmationDialog extends StatelessWidget {
  const SosConfirmationDialog({
    super.key,
    required this.name,
    required this.people,
    required this.category,
    required this.details,
    required this.location,
    required this.recipients,
    required this.translate,
  });

  final String name, people, category, details, location;
  final List<String> recipients;
  final String Function(String) translate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final muted = RescueTheme.mutedFor(context);
    final surface = dark ? const Color(0xFF161C24) : Colors.white;
    final panel = dark ? const Color(0xFF202A36) : const Color(0xFFF6F7F9);
    final red = dark ? const Color(0xFFFFA6A6) : const Color(0xFFB82E37);
    final t = translate;

    Widget detailRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return AlertDialog(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: red.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sos_rounded, size: 24, color: red),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    t('ขอความช่วยเหลือฉุกเฉิน'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: red,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            t('ยืนยันข้อมูล SOS'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t('ตรวจสอบรายละเอียดก่อนส่งคำขอความช่วยเหลือ'),
            style: TextStyle(fontSize: 13, height: 1.5, color: muted),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  detailRow(Icons.person_outline_rounded, t('ผู้แจ้ง'), name),
                  Divider(
                    height: 1,
                    color: scheme.onSurface.withValues(alpha: .08),
                  ),
                  detailRow(
                    Icons.people_outline_rounded,
                    t('จำนวนผู้ต้องการความช่วยเหลือ'),
                    '$people ${t('คน')}',
                  ),
                  Divider(
                    height: 1,
                    color: scheme.onSurface.withValues(alpha: .08),
                  ),
                  detailRow(
                    Icons.warning_amber_rounded,
                    t('ประเภทเหตุ'),
                    category,
                  ),
                ],
              ),
            ),
            if (details.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              detailRow(
                Icons.notes_rounded,
                t('รายละเอียดเหตุ'),
                details.trim(),
              ),
            ],
            detailRow(
              Icons.location_on_outlined,
              t('ตำแหน่งที่เกิดเหตุ'),
              location,
            ),
            if (recipients.isNotEmpty)
              detailRow(
                Icons.alternate_email_rounded,
                t('ผู้รับข้อความเพิ่มเติม'),
                recipients.join(', '),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: red.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${t('ประกาศสถานะให้เครื่องที่เชื่อมต่อและผู้ใช้ผ่านเครื่องส่งต่อ รวมเครื่องที่เชื่อมต่อภายหลัง')}\n\n'
                '${t('หากออฟไลน์ ระบบจะเก็บไว้ส่งเมื่อเชื่อมต่อผู้รับอีกครั้ง')}',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.sos_rounded, size: 24),
              label: Text(t('ยืนยันส่ง SOS')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB82E37),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: muted,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(t('กลับไปแก้ไข')),
            ),
          ],
        ),
      ],
    );
  }
}
