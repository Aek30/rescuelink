import 'package:flutter/material.dart';
import 'presence_peer_card.dart';
import '../services/message_service.dart';
import '../theme/rescue_theme.dart';

enum PresenceFilter { all, sos, rescue }

/// Live people directory. Historical incidents belong on the incident screens.
class PresenceList extends StatelessWidget {
  const PresenceList({
    super.key,
    required this.service,
    this.filter = PresenceFilter.all,
    this.excludeFilter,
    this.reachableOnly = false,
    this.headerAction,
    this.flat = false,
  });
  final MessageService service;
  final PresenceFilter filter;
  final PresenceFilter? excludeFilter;
  final bool reachableOnly;
  final Widget? headerAction;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final entries =
        service.presence.entries.where((entry) {
          if (entry.key == service.myId) return false;
          final state = entry.value;
          final sos = state.sos?.isActiveAt(now) == true;
          final rescue = state.isFresh(now) && state.rescue && !sos;
          if (reachableOnly && !service.isReachable(entry.key)) return false;
          if (excludeFilter == PresenceFilter.sos && sos) return false;
          if (excludeFilter == PresenceFilter.rescue && rescue) return false;
          if (excludeFilter == PresenceFilter.all) return false;
          return switch (filter) {
            PresenceFilter.sos => sos,
            PresenceFilter.rescue => rescue,
            PresenceFilter.all =>
              state.isFresh(now) || service.isReachable(entry.key),
          };
        }).toList()..sort(
          (a, b) => (service.peers[a.key] ?? a.key).compareTo(
            service.peers[b.key] ?? b.key,
          ),
        );
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark ? const Color(0xFF94A3B8) : RescueTheme.muted;
    final accent = filter == PresenceFilter.sos
        ? kSosRed
        : filter == PresenceFilter.rescue
        ? const Color(0xFF2563EB)
        : const Color(0xFF0F766E);
    final accentInk = dark ? Color.lerp(accent, Colors.white, .45)! : accent;
    final title = switch (filter) {
      PresenceFilter.sos => 'คนที่ต้องการความช่วยเหลือ',
      PresenceFilter.rescue => 'ผู้พร้อมช่วยเหลือ',
      PresenceFilter.all => 'คนรอบตัวคุณ',
    };
    final subtitle = switch (filter) {
      PresenceFilter.sos => 'คำขอ SOS ที่ยังใช้งานอยู่ • แตะดูรายละเอียด',
      PresenceFilter.rescue =>
        'รายชื่อผู้เปิดสถานะพร้อมช่วยเหลือ • แตะเพื่อส่งข้อความ',
      PresenceFilter.all => 'ค้นพบและเชื่อมต่ออัตโนมัติ ไม่ต้องกดจับคู่',
    };
    final grouped = filter == PresenceFilter.all;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: grouped ? 6 : 1,
              child: grouped
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : Text(
                      title,
                      textAlign: grouped ? TextAlign.end : TextAlign.start,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: grouped ? 17 : 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            if (grouped && headerAction != null) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: headerAction!,
                ),
              ),
            ],
            if (!grouped)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: grouped ? 10 : 16,
                  vertical: grouped ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entries.length} รายชื่อ',
                  style: TextStyle(
                    color: accentInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        if (!grouped) ?headerAction,
        SizedBox(height: grouped ? 4 : 8),
        Text(
          subtitle,
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        SizedBox(height: grouped ? 10 : 16),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1E293B) : const Color(0xFFFCF7F1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dark ? const Color(0xFF334155) : const Color(0xFFEAE2D8),
                width: 1,
              ),
              boxShadow: flat
                  ? null
                  : dark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: .1),
                  child: Icon(Icons.radar_rounded, color: accentInk, size: 30),
                ),
                const SizedBox(height: 16),
                const Text(
                  'กำลังเชื่อมต่อ...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        for (final entry in entries)
          PresencePeerCard(
            service: service,
            peerId: entry.key,
            state: entry.value,
            showRole: filter == PresenceFilter.all,
            grouped: grouped,
          ),
      ],
    );
    return Container(
      padding: EdgeInsets.fromLTRB(18, 18, 18, grouped ? 6 : 18),
      decoration: BoxDecoration(
        color: dark ? RescueTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? RescueTheme.darkBorder : const Color(0xFFEAE2D8),
        ),
      ),
      child: content,
    );
  }
}
