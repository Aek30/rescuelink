import 'package:flutter/material.dart';
import '../services/message_service.dart';

class IncidentStatusChip extends StatelessWidget {
  const IncidentStatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Both Nearby and incident details read the same route/reachability source.
class PeerConnectionChip extends StatelessWidget {
  const PeerConnectionChip({
    super.key,
    required this.service,
    required this.peerId,
    this.compact = false,
  });
  final MessageService service;
  final String peerId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reachable = service.isReachable(peerId);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = reachable
        ? (dark ? const Color(0xFF8CDAC1) : const Color(0xFF166447))
        : (dark ? const Color(0xFFBCC7D1) : const Color(0xFF536572));
    final via = reachable ? service.relayViaName(peerId) : null;
    final path = via == null ? null : service.relayPathForPeer(peerId);
    final relayCount = path == null ? 1 : path.length - 2;
    final label = !reachable
        ? 'ออฟไลน์ • ข้อมูลเก่า'
        : via == null
        ? 'เชื่อมต่อโดยตรง'
        : 'เชื่อมต่อผ่าน $via${relayCount > 1 ? ' · รวม $relayCount เครื่องกลาง' : ''}';
    return Tooltip(
      message: service.connectionLabel(peerId),
      child: compact
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            )
          : IncidentStatusChip(
              label: label,
              icon: reachable ? Icons.link : Icons.link_off,
              color: color,
            ),
    );
  }
}
