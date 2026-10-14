import 'package:flutter/material.dart';
import '../theme/rescue_theme.dart';

enum RescueBannerKind { error, success, info }

/// Section header label with subtle typography matching settings_panel
class RescueSectionLabel extends StatelessWidget {
  const RescueSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: muted,
        ),
      ),
    );
  }
}

/// Rounded card container with divider separators matching settings_panel
class RescueGroup extends StatelessWidget {
  const RescueGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? RescueTheme.darkSurface : Colors.white;
    final line = dark ? RescueTheme.darkBorder : RescueTheme.border;

    return Material(
      color: surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 66, color: line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Row tile with colored rounded icon box, label, optional subtitle, and trailing chevron
class RescueTile extends StatelessWidget {
  const RescueTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? RescueTheme.darkText : RescueTheme.navy;
    final muted = dark ? RescueTheme.darkTextMuted : RescueTheme.muted;
    final c = accent ?? RescueTheme.orange;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitleWidget != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: subtitleWidget!,
                    )
                  else if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, color: muted, size: 24),
          ],
        ),
      ),
    );
  }
}

/// Modern rounded banner with leading icon for error, success, and info messages
class RescueBanner extends StatelessWidget {
  const RescueBanner(this.text, {super.key, required this.kind});

  final String text;
  final RescueBannerKind kind;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final (icon, iconColor, bgColor, borderColor, textColor) = switch (kind) {
      RescueBannerKind.error => (
        Icons.error_outline_rounded,
        const Color(0xFFE04C4C),
        dark ? const Color(0xFF2C1515) : const Color(0xFFFEE2E2),
        dark ? const Color(0xFF5A2222) : const Color(0xFFFCA5A5),
        dark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
      ),
      RescueBannerKind.success => (
        Icons.check_circle_outline_rounded,
        dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
        dark ? const Color(0xFF132A1C) : const Color(0xFFDCFCE7),
        dark ? const Color(0xFF1F4D2E) : const Color(0xFF86EFAC),
        dark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
      ),
      RescueBannerKind.info => (
        Icons.info_outline_rounded,
        dark ? const Color(0xFFFFAD85) : RescueTheme.orangeInk,
        dark ? const Color(0xFF2A1C14) : const Color(0xFFFFEDD5),
        dark ? const Color(0xFF5A3420) : const Color(0xFFFED7AA),
        dark ? const Color(0xFFFFD8BF) : const Color(0xFF9A3412),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
