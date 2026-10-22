import 'package:flutter/material.dart';
import '../models/peer_presence.dart';
import '../screens/chat_screen.dart';
import '../screens/incident_detail_screen.dart';
import '../services/message_service.dart';
import '../theme/rescue_theme.dart';
import 'emergency_type_chip.dart';
import 'incident_status_chip.dart';

/// Identity, connection state and actions each get their own wrapping row.
class PresencePeerCard extends StatelessWidget {
  const PresencePeerCard({
    super.key,
    required this.service,
    required this.peerId,
    required this.state,
    required this.showRole,
    this.grouped = false,
  });
  final MessageService service;
  final String peerId;
  final PeerPresence state;
  final bool showRole;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final fresh = state.isFresh(now);
    final sos = state.sos?.isActiveAt(now) == true;
    final rescue = fresh && state.rescue && !sos;
    final reachable = service.isReachable(peerId);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = RescueTheme.mutedFor(context);
    final color = sos
        ? kSosRed
        : rescue
        ? const Color(0xFF2563EB)
        : const Color(0xFF0F766E);
    final ink = dark ? Color.lerp(color, Colors.white, .45)! : color;
    final name = service.peers[peerId] ?? 'ผู้ใช้ใกล้เคียง';
    final role = sos
        ? 'ต้องการความช่วยเหลือ'
        : rescue
        ? 'พร้อมช่วยเหลือ'
        : fresh
        ? 'พร้อมพูดคุย'
        : 'รออัปเดตสถานะ';
    void chat() => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(service: service, peerId: peerId),
      ),
    );
    void details() => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => IncidentDetailScreen(service: service, peerId: peerId),
      ),
    );

    final surface = dark ? RescueTheme.darkSurface : Colors.white;
    final border = dark ? RescueTheme.darkBorder : RescueTheme.border;

    return Container(
      key: ValueKey('presence-peer-$peerId'),
      margin: EdgeInsets.only(bottom: grouped ? 0 : 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: grouped ? null : BorderRadius.circular(18),
        border: grouped
            ? Border(top: BorderSide(color: border))
            : Border.all(color: sos ? color.withValues(alpha: .25) : border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: sos
              ? details
              : reachable
              ? chat
              : null,
          child: Padding(
            padding: grouped
                ? const EdgeInsets.symmetric(vertical: 12)
                : const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── แถวหลัก: อวตาร + ชื่อ + สถานะ + ปุ่มแชต ──
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: color.withValues(alpha: .12),
                          child: sos || rescue
                              ? Icon(
                                  sos
                                      ? Icons.warning_amber_rounded
                                      : Icons.shield_outlined,
                                  color: ink,
                                  size: 22,
                                )
                              : Text(
                                  name.trim().isEmpty
                                      ? '?'
                                      : name
                                            .trim()
                                            .characters
                                            .first
                                            .toUpperCase(),
                                  style: TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        if (reachable)
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E9B6F),
                                shape: BoxShape.circle,
                                border: Border.all(color: surface, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (showRole)
                                Text(
                                  role,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ink,
                                  ),
                                ),
                              PeerConnectionChip(
                                service: service,
                                peerId: peerId,
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // กรณีปกติ: ปุ่มแชตเป็นไอคอนท้ายแถว (ไม่ต้องมีแถวปุ่มแยก)
                    if (!sos && reachable) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'ส่งข้อความ',
                        onPressed: chat,
                        style: IconButton.styleFrom(
                          backgroundColor: color.withValues(alpha: .10),
                          foregroundColor: ink,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),

                // ── กรอบ SOS แยกชัดเจน ──
                if (sos) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: dark ? .14 : .07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final type in state.sos!.categories)
                              EmergencyTypeChip(type: type),
                            Text(
                              'ผู้ต้องการความช่วยเหลือ ${state.sos!.people} คน',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                        if (state.sos!.details.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            state.sos!.details,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: details,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            side: BorderSide(
                              color: color.withValues(alpha: .5),
                            ),
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.article_outlined, size: 18),
                          label: const Text(
                            'รายละเอียด SOS',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      if (reachable) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: chat,
                            style: FilledButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'ส่งข้อความ',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
