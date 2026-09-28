import 'package:flutter/material.dart';
import '../models/nearby_device.dart';
import '../theme/rescue_theme.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, required this.onPressed});
  final NearbyDevice device;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: RescueTheme.peach,
        foregroundColor: RescueTheme.orangeInk,
        child: Icon(device.isConnected ? Icons.link : Icons.phone_android),
      ),
      title: Text(device.name),
      subtitle: Text(
        device.isConnected
            ? 'เชื่อมต่อแล้ว'
            : device.isConnecting
            ? 'กำลังเชื่อมต่อ…'
            : device.isAvailable
            ? 'พร้อมเชื่อมต่อ'
            : 'อยู่นอกระยะ',
      ),
      trailing: TextButton(
        onPressed: device.isConnecting ? null : onPressed,
        child: Text(device.isConnected ? 'ตัดการเชื่อมต่อ' : 'เชื่อมต่อ'),
      ),
    ),
  );
}
