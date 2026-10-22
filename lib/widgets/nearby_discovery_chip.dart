import 'package:flutter/material.dart';

/// Compact discovery controls with confirmation before becoming invisible.
class NearbyDiscoveryChip extends StatelessWidget {
  const NearbyDiscoveryChip({
    super.key,
    required this.active,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.onSettings,
  });

  final bool active, busy;
  final VoidCallback onStart, onStop, onSettings;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    enabled: !busy,
    tooltip: 'สถานะการค้นหาและการเชื่อมต่อ',
    onSelected: (action) async {
      if (action == 'settings') {
        onSettings();
      } else if (action == 'start') {
        onStart();
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('หยุดการค้นหา?'),
            content: const Text(
              'คุณจะไม่เห็นและไม่ถูกเห็นโดยคนรอบตัวผ่านการเชื่อมต่อใกล้เคียง '
              'การเชื่อมต่อกับอุปกรณ์รอบตัวจะหยุดลง '
              'จนกว่าคุณจะเริ่มค้นหาอีกครั้ง',
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('หยุดการค้นหา'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) onStop();
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        value: active ? 'stop' : 'start',
        child: Text(active ? 'หยุดการค้นหา' : 'เริ่มค้นหา'),
      ),
      const PopupMenuItem(
        value: 'settings',
        child: Text('การเชื่อมต่อและสิทธิ์'),
      ),
    ],
    child: Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Chip(
        label: Text(
          busy
              ? 'กำลังดำเนินการ •'
              : active
              ? 'กำลังค้นหา •'
              : 'หยุดค้นหาแล้ว •',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        visualDensity: VisualDensity.compact,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        side: BorderSide.none,
      ),
    ),
  );
}
