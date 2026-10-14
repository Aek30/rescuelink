import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../screens/chat_screen.dart';
import '../screens/incident_detail_screen.dart';
import '../theme/rescue_theme.dart';

enum PresenceFilter { all, sos, rescue }

/// Live people directory. Historical incidents belong on the incident screens.
class PresenceList extends StatelessWidget {
  const PresenceList({
    super.key,
    required this.service,
    this.filter = PresenceFilter.all,
  });
  final MessageService service;
  final PresenceFilter filter;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final entries =
        service.presence.entries.where((entry) {
          if (entry.key == service.myId) return false;
          final state = entry.value;
          final sos = state.sos?.isActiveAt(now) == true;
          final rescue = state.isFresh(now) && state.rescue && !sos;
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
        ? const Color(0xFFB91C1C)
        : filter == PresenceFilter.rescue
        ? const Color(0xFF2563EB)
        : const Color(0xFF0F766E);
    final accentInk = dark ? Color.lerp(accent, Colors.white, .45)! : accent;
    final title = switch (filter) {
      PresenceFilter.sos => 'คนที่ต้องการความช่วยเหลือ',
      PresenceFilter.rescue => 'ผู้พร้อมช่วยเหลือใกล้คุณ',
      PresenceFilter.all => 'คนรอบตัวคุณ',
    };
    final subtitle = switch (filter) {
      PresenceFilter.sos => 'คำขอ SOS ที่ยังใช้งานอยู่ • แตะเพื่อส่งข้อความ',
      PresenceFilter.rescue =>
        'รายชื่อผู้เปิดสถานะพร้อมช่วยเหลือ • แตะเพื่อส่งข้อความ',
      PresenceFilter.all => 'ค้นพบและเชื่อมต่ออัตโนมัติ ไม่ต้องกดจับคู่',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${entries.length} คน',
                style: TextStyle(color: accentInk, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: .15),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: .1),
                  child: Icon(Icons.radar_rounded, color: accentInk, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  switch (filter) {
                    PresenceFilter.sos => 'ยังไม่มีคำขอความช่วยเหลือใกล้เคียง',
                    PresenceFilter.rescue => 'กำลังค้นหาผู้พร้อมช่วยเหลือ',
                    PresenceFilter.all => 'กำลังค้นหาคนรอบตัวคุณ',
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'เปิด RescueLink บนอีกเครื่องและเปิด Bluetooth / Wi-Fi\nเมื่อพบกัน ระบบจะเชื่อมต่อให้อัตโนมัติ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        for (final entry in entries)
          Builder(
            builder: (context) {
              final state = entry.value;
              final fresh = state.isFresh(now);
              final sos = state.sos?.isActiveAt(now) == true;
              final rescue = fresh && state.rescue && !sos;
              final reachable = service.isReachable(entry.key);
              final color = sos
                  ? const Color(0xFFB91C1C)
                  : rescue
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF0F766E);
              final ink = dark ? Color.lerp(color, Colors.white, .45)! : color;
              final name = service.peers[entry.key] ?? 'ผู้ใช้ใกล้เคียง';
              final label = sos
                  ? 'ต้องการความช่วยเหลือ'
                  : rescue
                  ? 'พร้อมช่วยเหลือ'
                  : fresh
                  ? 'พร้อมพูดคุย'
                  : 'รออัปเดตสถานะ';
              void chat() => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChatScreen(service: service, peerId: entry.key),
                ),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(color: color.withValues(alpha: .2)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: reachable ? chat : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: color.withValues(alpha: .1),
                                child: Icon(
                                  sos
                                      ? Icons.sos
                                      : rescue
                                      ? Icons.volunteer_activism_outlined
                                      : Icons.person_outline,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      service.connectionLabel(entry.key),
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // A helper may still carry a cancelled SOS snapshot. Never render it here.
                          if (sos && filter != PresenceFilter.rescue) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${state.sos!.category.label} • ${state.sos!.people} คน',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (state.sos!.details.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  state.sos!.details,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: muted, height: 1.5),
                                ),
                              ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: reachable ? chat : null,
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                ),
                                label: Text(
                                  reachable ? 'ส่งข้อความ' : 'รอการเชื่อมต่อ',
                                ),
                              ),
                              if (sos && filter != PresenceFilter.rescue)
                                TextButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => IncidentDetailScreen(
                                        service: service,
                                        peerId: entry.key,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.article_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('รายละเอียด SOS'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
