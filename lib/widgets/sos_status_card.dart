import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';
import 'emergency_type_chip.dart';
import 'incident_status_chip.dart';

class SosStatusCard extends StatelessWidget {
  const SosStatusCard({
    super.key,
    required this.alert,
    required this.deliveries,
    this.announced = false,
    this.sending = false,
    this.confirmedMessageIds = const {},
  });
  final SosAlert alert;
  final List<MessageModel> deliveries;
  final bool announced;
  final bool sending;
  final Set<String> confirmedMessageIds;
  @override
  Widget build(BuildContext context) {
    final received = deliveries
        .where(
          (m) =>
              m.status == MessageStatus.delivered ||
              confirmedMessageIds.contains(m.id),
        )
        .map((m) => m.receiverId)
        .toSet()
        .length;
    final broadcast =
        announced ||
        received > 0 ||
        deliveries.any((m) => m.status == MessageStatus.sent);
    final expired = alert.isExpired(DateTime.now().toUtc());
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = !alert.active || expired
        ? RescueTheme.mutedFor(context)
        : received > 0
        ? (dark ? const Color(0xFF8CDAC1) : const Color(0xFF167347))
        : broadcast
        ? (dark ? const Color(0xFF9BC9FF) : const Color(0xFF245A91))
        : sosWarningColor(context);
    final label = !alert.active
        ? 'ยกเลิกแล้ว'
        : expired
        ? 'SOS หมดอายุ'
        : sending
        ? 'กำลังส่ง SOS...'
        : 'ส่ง SOS แล้ว';
    final icon = !alert.active || expired
        ? Icons.block
        : received > 0
        ? Icons.devices
        : broadcast
        ? Icons.wifi_tethering
        : Icons.schedule;
    final time = alert.updatedAt.toLocal();
    return SosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IncidentStatusChip(label: label, color: color, icon: icon),
          const SizedBox(height: 16),
          EmergencyTypeChips(types: alert.categories),
          const SizedBox(height: 8),
          Text('${alert.name} • ${alert.people} คน'),
          Text(
            '${sosClock(time)} • ${sosAge(time)}',
            style: TextStyle(
              fontSize: 12,
              color: RescueTheme.mutedFor(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ยังไม่ใช่การตอบรับจากเจ้าหน้าที่',
            style: TextStyle(
              fontSize: 12,
              color: RescueTheme.mutedFor(context),
            ),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('รายละเอียด', style: TextStyle(fontSize: 14)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${time.day}/${time.month}/${time.year} ${sosClock(time)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (alert.details.isNotEmpty) Text(alert.details),
                    Text(
                      alert.location == null
                          ? 'ไม่ได้แนบพิกัด'
                          : '${sosCoordinates(alert.location!)}\n${sosLocationAge(alert.location!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
