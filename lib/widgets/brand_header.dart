import 'package:flutter/material.dart';
import '../theme/rescue_theme.dart';

/// Compact illustrated heading; the image is decorative, never a status signal.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.image,
    this.eyebrow,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String? image;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2631) : RescueTheme.peach,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF283442) : RescueTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null)
            SizedBox(
              height: 110,
              child: ExcludeSemantics(
                child: Image.asset(
                  image!,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, .25),
                  cacheWidth: 960,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF283442)
                            : Colors.white.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        icon,
                        color: isDark ? const Color(0xFFFF9E7D) : RescueTheme.orangeInk,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        eyebrow ?? 'RescueLink • เชื่อมต่อความช่วยเหลือ',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFF9E7D) : RescueTheme.orangeInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFF1F5F9) : RescueTheme.navy,
                    fontSize: 25,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : RescueTheme.muted,
                    fontSize: 13,
                    height: 1.6,
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
