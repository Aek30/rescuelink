import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';
import 'emergency_type_chip.dart';

class SosStatusCard extends StatelessWidget {
  const SosStatusCard({
    super.key,
    required this.alert,
    required this.deliveries,
    this.announced = false,
    this.confirmedMessageIds = const {},
  });
  final SosAlert alert;
  final List<MessageModel> deliveries;
  final bool announced;
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
        : received > 0
        ? 'มีผู้รับแล้ว $received เครื่อง'
        : broadcast
        ? 'ประกาศแล้ว'
        : 'รอประกาศ';
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < 3; index++)
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        [
                          Icons.save_outlined,
                          Icons.wifi_tethering,
                          Icons.devices,
                        ][index],
                        color:
                            (index == 0 ||
                                index == 1 && broadcast ||
                                index == 2 && received > 0)
                            ? color
                            : color.withValues(alpha: .25),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'บันทึกแล้ว',
                          'ประกาศผ่าน P2P',
                          'มีผู้รับยืนยัน',
                        ][index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              (index == 0 ||
                                  index == 1 && broadcast ||
                                  index == 2 && received > 0)
                              ? color
                              : RescueTheme.mutedFor(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
