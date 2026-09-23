import 'package:flutter/material.dart';
import '../models/nearby_device.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, required this.onPressed});
  final NearbyDevice device;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(device.isConnected ? Icons.link : Icons.phone_android),
      title: Text(device.name),
      subtitle: Text(
        '${device.endpointId}\nStatus: ${device.isConnected
            ? 'Connected'
            : device.isConnecting
            ? 'Connecting...'
            : device.isAvailable
            ? 'Available'
            : 'Out of range'}',
      ),
      isThreeLine: true,
      trailing: TextButton(
        onPressed: device.isConnecting ? null : onPressed,
        child: Text(device.isConnected ? 'DISCONNECT' : 'CONNECT'),
      ),
    ),
  );
}
