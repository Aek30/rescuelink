import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../screens/chat_screen.dart';
import '../screens/incident_detail_screen.dart';
import 'location_button.dart';
import '../theme/rescue_theme.dart';

class PresenceList extends StatelessWidget {
  const PresenceList({super.key, required this.service});
  final MessageService service;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'สถานะ SOS / หน่วยกู้ภัยใกล้เคียง',
            style: TextStyle(
              color: isDark ? const Color(0xFFF1F5F9) : RescueTheme.navy,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        if (service.presence.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161C24) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF283442) : RescueTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.radar_rounded,
                  color: isDark ? const Color(0xFFFF9E7D) : RescueTheme.orangeInk,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ยังไม่มีสถานะ • เชื่อมต่ออุปกรณ์ใกล้เคียงเพื่อรับข้อมูล',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : RescueTheme.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      for (final entry in service.presence.entries)
        Builder(
          builder: (context) {
            final state = entry.value;
            final fresh = state.isFresh(DateTime.now().toUtc());
            final sos = state.sos?.active == true;
            final color = !fresh
                ? Colors.grey
                : sos
                ? Colors.red
                : state.rescue
                ? Colors.blue
                : Colors.grey;
            final label = !fresh
                ? 'สถานะหมดอายุ • ข้อมูลล่าสุด'
                : sos
                ? 'SOS ขอความช่วยเหลือ'
                : state.rescue
                ? 'หน่วยกู้ภัยพร้อมช่วยเหลือ'
                : 'ปิด SOS / Rescue';
            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(
                      sos ? Icons.sos : Icons.health_and_safety,
                      color: color,
                    ),
                    title: Text(service.peers[entry.key] ?? entry.key),
                    subtitle: Text(
                      '$label${fresh && sos && state.rescue ? ' • เปิด Rescue ด้วย' : ''}\n${service.isOnline(entry.key) ? 'เชื่อมต่ออยู่' : 'ขาดการเชื่อมต่อ'} • แตะเพื่อแชต',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ChatScreen(service: service, peerId: entry.key),
                      ),
                    ),
                  ),
                  if (state.sos != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(state.sos!.summary),
                          TextButton.icon(
                            icon: const Icon(Icons.article_outlined),
                            label: const Text('ดูรายละเอียดเหตุ'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => IncidentDetailScreen(
                                  service: service,
                                  peerId: entry.key,
                                ),
                              ),
                            ),
                          ),
                          if (state.sos!.location != null)
                            LocationButton(location: state.sos!.location!),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
    ],
    );
  }
}
