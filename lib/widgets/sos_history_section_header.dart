import 'package:flutter/material.dart';
import '../theme/rescue_theme.dart';

class SosHistoryOverviewHeader extends StatelessWidget {
  const SosHistoryOverviewHeader({super.key, required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final accent = RescueTheme.accentFor(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.history_rounded, color: accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'ทุกคำขอของคุณ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ทั้งหมด $total เหตุ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'ย้อนดูรายละเอียดและสถานะการขอความช่วยเหลือ',
                  style: TextStyle(
                    fontSize: 13,
                    color: RescueTheme.mutedFor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SosHistorySectionHeader extends StatelessWidget {
  const SosHistorySectionHeader({
    super.key,
    required this.title,
    this.active = false,
    this.date = false,
  });
  final String title;
  final bool active;
  final bool date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: date ? 4 : 12, bottom: date ? 10 : 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: date ? 12 : 17,
        fontWeight: date ? FontWeight.w600 : FontWeight.w700,
        color: date
            ? RescueTheme.mutedFor(context)
            : active
            ? RescueTheme.accentFor(context)
            : Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}
