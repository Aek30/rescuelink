import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../screens/chat_screen.dart';
import 'location_button.dart';

class PresenceList extends StatelessWidget {
  const PresenceList({super.key, required this.service});
  final MessageService service;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('สถานะ SOS / หน่วยกู้ภัยใกล้เคียง'),
      if (service.presence.isEmpty)
        const Text(
          'ยังไม่มีสถานะ เชื่อมต่อเครื่องที่ใช้ Phase 4 เพื่อรับข้อมูล',
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
