import 'package:flutter/material.dart';
import '../models/nearby_device.dart';
import '../models/peer_presence.dart';
import '../theme/rescue_theme.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.onPressed,
    this.presence,
    this.onChat,
    this.onDetails,
  });
  final NearbyDevice device;
  final VoidCallback? onPressed;
  final PeerPresence? presence;
  final VoidCallback? onChat;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final sos = presence?.sos?.isActiveAt(now) == true;
    final fresh = presence?.isFresh(now) == true;
    final rescue = fresh && presence!.rescue && !sos;
    final color = sos
        ? RescueTheme.danger
        : rescue
        ? Colors.blue
        : RescueTheme.accentFor(context);
    final role = sos
        ? 'กำลังขอความช่วยเหลือ'
        : rescue
        ? 'หน่วยกู้ภัย'
        : fresh
        ? 'ผู้ใช้ทั่วไป'
        : 'ยังไม่ทราบสถานะ';
    final connection = device.isConnected
        ? 'เชื่อมต่อแล้ว'
        : device.isConnecting
        ? 'กำลังเชื่อมต่อ…'
        : device.isAvailable
        ? 'พร้อมเชื่อมต่อ'
        : 'อยู่นอกระยะ';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(
            sos
                ? Icons.sos
                : rescue
                ? Icons.shield
                : device.isConnected
                ? Icons.link
                : Icons.phone_android,
          ),
        ),
        title: Text(device.name),
        onTap: sos && onDetails != null
            ? onDetails
            : device.isConnected
            ? onChat
            : null,
        subtitle: Text('$role • $connection', style: TextStyle(color: color)),
        trailing: device.isConnected && onChat != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: onChat, child: const Text('แชต')),
                  PopupMenuButton<String>(
                    tooltip: 'จัดการการเชื่อมต่อ',
                    onSelected: (_) => onPressed?.call(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'disconnect',
                        enabled: onPressed != null,
                        child: const Text('ตัดการเชื่อมต่อ'),
                      ),
                    ],
                  ),
                ],
              )
            : TextButton(
                onPressed: device.isConnecting
                    ? null
                    : device.isConnected && onChat != null
                    ? onChat
                    : onPressed,
                child: Text(
                  device.isConnected
                      ? onChat != null
                            ? 'แชต'
                            : 'ตัดการเชื่อมต่อ'
                      : 'เชื่อมต่อ',
                ),
              ),
      ),
    );
  }
}
