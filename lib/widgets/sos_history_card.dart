import 'package:flutter/material.dart';
import '../services/sos_store.dart';
import '../theme/rescue_theme.dart';
import 'emergency_type_chip.dart';
import 'incident_status_chip.dart';

String sosHistoryDisplayName(String value) {
  final name = value.trim();
  const placeholders = {
    '',
    '-',
    '—',
    'unknown',
    'null',
    'undefined',
    'n/a',
    'name',
    'your name',
    'ชื่อผู้แจ้ง',
    'ผู้แจ้ง',
    'ชื่อของคุณ',
    'ไม่ทราบชื่อ',
    'ยังไม่ระบุชื่อ',
    'ไม่ระบุ',
  };
  return placeholders.contains(name.toLowerCase()) ? 'ไม่ระบุชื่อ' : name;
}

class SosHistoryCard extends StatelessWidget {
  const SosHistoryCard({
    super.key,
    required this.record,
    required this.active,
    this.onEdit,
    this.onDelete,
  });
  final SosRecord record;
  final bool active;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final alert = record.alert;
    final expired = alert.isExpired(DateTime.now().toUtc());
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = RescueTheme.mutedFor(context);
    final statusColor = active
        ? (dark ? const Color(0xFFFFA6A6) : kSosRed)
        : expired
        ? sosWarningColor(context)
        : (dark ? const Color(0xFF8CDAC1) : const Color(0xFF167347));
    Widget detail(IconData icon, Widget text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(child: text),
      ],
    );
    return Container(
      key: ValueKey('sos-history-${record.alert.incidentId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.fromLTRB(
        active ? 16 : 14,
        active ? 16 : 14,
        active ? 16 : 14,
        8,
      ),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF161C24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? kSosRed.withValues(alpha: .35)
              : dark
              ? const Color(0xFF283442)
              : RescueTheme.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IncidentStatusChip(
                label: !alert.active
                    ? 'ยุติแล้ว'
                    : expired
                    ? 'หมดอายุ'
                    : 'กำลังขอความช่วยเหลือ',
                color: statusColor,
                icon: active
                    ? Icons.sos_rounded
                    : expired
                    ? Icons.schedule_rounded
                    : Icons.check_circle_outline_rounded,
              ),
              Text(
                'อัปเดต ${sosClock(alert.updatedAt)} น.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
          SizedBox(height: active ? 16 : 10),
          Text(
            alert.categories.map((type) => type.shortLabel).join(' • '),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          detail(
            Icons.person_outline_rounded,
            Text(
              sosHistoryDisplayName(alert.name),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          detail(
            Icons.people_outline_rounded,
            Text(
              'ผู้ต้องการความช่วยเหลือ ${alert.people} คน',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (alert.details.isNotEmpty) ...[
            SizedBox(height: active ? 16 : 10),
            const Divider(height: 1),
            SizedBox(height: active ? 16 : 10),
            Text(
              'รายละเอียดเหตุ',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 6),
            SelectableText(
              alert.details,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
          SizedBox(height: active ? 16 : 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: muted.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: detail(
              Icons.location_on_outlined,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ตำแหน่งที่บันทึก',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 4),
                  if (alert.location != null) ...[
                    SelectableText(
                      sosCoordinates(alert.location!),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${alert.location!.manuallySelected ? 'ปักหมุดเอง' : 'ความแม่นยำ ${alert.location!.accuracy.round()} ม.'} • ${sosAge(alert.location!.capturedAt)}',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ] else
                    Text(
                      'ไม่ได้แนบพิกัด',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                ],
              ),
            ),
          ),
          if (record.conflict != null) ...[
            const SizedBox(height: 12),
            detail(
              Icons.cloud_off_outlined,
              Text(
                'ข้อมูลขัดแย้งกับ Cloud',
                style: TextStyle(fontSize: 13, color: sosWarningColor(context)),
              ),
            ),
          ],
          if (!alert.active) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 16,
                children: [
                  Tooltip(
                    message: 'แก้ไขเหตุ',
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('แก้ไข'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ลบเหตุ',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    style: IconButton.styleFrom(foregroundColor: muted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
