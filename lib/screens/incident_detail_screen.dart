import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../widgets/location_button.dart';
import 'chat_screen.dart';
import '../widgets/brand_header.dart';
import '../theme/rescue_theme.dart';

class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({
    super.key,
    required this.service,
    required this.peerId,
  });
  final MessageService service;
  final String peerId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final presence = service.presence[peerId];
      final alert = presence?.sos;
      final fresh = presence?.isFresh(DateTime.now().toUtc()) == true;
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดเหตุ')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BrandHeader(
              title: service.peers[peerId] ?? peerId,
              eyebrow: 'รายละเอียดคำขอ • ข้อมูลจากผู้ส่ง',
              icon: Icons.health_and_safety_outlined,
              subtitle: alert?.isActiveAt(DateTime.now().toUtc()) == true
                  ? 'SOS • กำลังขอความช่วยเหลือ${fresh ? '' : ' • สถานะการเชื่อมต่อเก่า'}'
                  : alert?.isExpired(DateTime.now().toUtc()) == true
                  ? 'SOS หมดอายุ'
                  : 'ไม่มี SOS ที่เปิดอยู่',
            ),
            const SizedBox(height: 16),
            Text(service.connectionLabel(peerId)),
            if (alert != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(alert.summary),
                ),
              ),
              Text('อัปเดตจากผู้ส่ง: ${alert.updatedAt.toLocal()}'),
              if (alert.location != null)
                LocationButton(location: alert.location!)
              else
                const Text('ไม่แนบพิกัด • ขอรายละเอียดเพิ่มเติมผ่านแชต'),
            ] else
              const Text('ยังไม่มีรายละเอียดเหตุที่ได้รับ'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(service: service, peerId: peerId),
                ),
              ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('ติดต่อผ่านแชต'),
            ),
            const SizedBox(height: 16),
            const Text(
              'การได้รับข้อความไม่ได้หมายถึงมีหน่วยกู้ภัยตอบรับแล้ว',
              textAlign: TextAlign.center,
              style: TextStyle(color: RescueTheme.muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}
