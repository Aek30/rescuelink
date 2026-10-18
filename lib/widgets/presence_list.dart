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
    this.excludeFilter,
    this.reachableOnly = false,
  });
  final MessageService service;
  final PresenceFilter filter;
  final PresenceFilter? excludeFilter;
  final bool reachableOnly;

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
        ? const Color(0xFFB91C1C)
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
              color: dark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: dark
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
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sos
                        ? (dark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFECACA))
                        : (dark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    width: 1,
                  ),
                  boxShadow: dark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: reachable ? chat : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── แถวแนวนอน (Row): ฝั่งซ้าย (ข้อมูลผู้ใช้) vs ฝั่งขวา (ปุ่มกระทำ) ───
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ─── ฝั่งซ้าย: รูปโปรไฟล์ (Avatar) + ชื่อผู้ใช้ + สถานะเชื่อมต่อ ───
                              Expanded(
                                child: Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: sos
                                              ? (dark
                                                    ? const Color(0xFF451A1A)
                                                    : const Color(0xFFFFEAEA))
                                              : rescue
                                              ? (dark
                                                    ? const Color(0xFF1E2D45)
                                                    : const Color(0xFFEBF3FF))
                                              : color.withValues(alpha: .12),
                                          child: sos
                                              ? const Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: Color(0xFFFF4D4D),
                                                  size: 22,
                                                )
                                              : rescue
                                              ? const Icon(
                                                  Icons.shield_outlined,
                                                  color: Color(0xFF3B82F6),
                                                  size: 22,
                                                )
                                              : Text(
                                                  name.trim().isNotEmpty
                                                      ? name
                                                            .trim()
                                                            .characters
                                                            .first
                                                            .toUpperCase()
                                                      : 'A',
                                                  style: TextStyle(
                                                    color: ink,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                        ),
                                        Positioned(
                                          right: -1,
                                          bottom: -1,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: reachable
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF94A3B8),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: dark
                                                    ? const Color(0xFF1E293B)
                                                    : Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            service.connectionLabel(entry.key),
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 11.5,
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: .1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                color: ink,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ─── ฝั่งขวา: ย้ายปุ่ม "ส่งข้อความ" มาไว้มุมขวาสุดของการ์ด ───
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: reachable
                                      ? color
                                      : (dark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0)),
                                  foregroundColor: reachable
                                      ? Colors.white
                                      : (dark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: reachable ? chat : null,
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 15,
                                ),
                                label: Text(
                                  reachable ? 'ส่งข้อความ' : 'รอเชื่อมต่อ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // ข้อมูลรายละเอียด SOS เมื่อมีคำขอฉุกเฉิน
                          if (sos && filter != PresenceFilter.rescue) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(
                                        0xFF451A1A,
                                      ).withValues(alpha: 0.5)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: dark
                                      ? const Color(0xFF7F1D1D)
                                      : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.emergency_outlined,
                                        size: 16,
                                        color: color,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${state.sos!.category.label} • ${state.sos!.people} คน',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (state.sos!.details.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      state.sos!.details,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        side: BorderSide(
                                          color: color.withValues(alpha: 0.5),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => IncidentDetailScreen(
                                            service: service,
                                            peerId: entry.key,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.article_outlined,
                                        size: 14,
                                        color: ink,
                                      ),
                                      label: Text(
                                        'รายละเอียด SOS',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
