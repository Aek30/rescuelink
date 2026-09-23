import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  final Map<String, String> statuses = {
    'Bluetooth': 'Not checked',
    'Nearby Devices': 'Not checked',
    'Location': 'Not checked',
    'Location service': 'Not checked',
  };
  String? error;

  // Android 12/12L still use location with this version of Nearby SDK.
  // Android 13+ uses Nearby Wi-Fi permission instead.
  static List<Permission> requiredPermissions(int sdk) => [
    if (sdk <= 32) Permission.locationWhenInUse,
    if (sdk >= 31) ...[
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ],
    if (sdk >= 33) Permission.nearbyWifiDevices,
  ];

  Future<bool> ensureReady() async {
    error = null;
    if (!Platform.isAndroid) {
      error = 'This POC requires a physical Android phone.';
      return false;
    }
    try {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      final required = requiredPermissions(sdk);
      final results = await required.request();
      bool granted(Permission p) => results[p]?.isGranted ?? false;
      final bluetooth =
          sdk < 31 ||
          [
            Permission.bluetoothAdvertise,
            Permission.bluetoothConnect,
            Permission.bluetoothScan,
          ].every(granted);
      statuses['Bluetooth'] = bluetooth ? 'Granted' : 'Denied';
      statuses['Nearby Devices'] = sdk < 31
          ? 'Uses Location on this Android version'
          : bluetooth && (sdk < 33 || granted(Permission.nearbyWifiDevices))
          ? 'Granted'
          : 'Denied';
      statuses['Location'] = sdk >= 33
          ? 'Not required for permission on Android 13+'
          : granted(Permission.locationWhenInUse)
          ? 'Granted'
          : 'Denied';
      if (!required.every(granted)) {
        final permanent = results.values.any((s) => s.isPermanentlyDenied);
        error =
            !bluetooth || (sdk >= 33 && !granted(Permission.nearbyWifiDevices))
            ? 'Nearby Devices permission is required to discover nearby RescueLink devices.'
            : 'Location permission (Precise location) is required on this Android version.';
        if (permanent) error = '$error Open App Settings to allow it.';
        return false;
      }
      // Check/enable the service only; Phase 1 never reads GPS coordinates.
      final location = Location();
      var enabled = await location.serviceEnabled();
      if (!enabled) enabled = await location.requestService();
      statuses['Location service'] = enabled ? 'On' : 'Off';
      if (!enabled) {
        error = 'Turn on Location service for reliable Nearby Connections.';
        return false;
      }
      final radio = await Permission.bluetooth.serviceStatus;
      if (radio == ServiceStatus.disabled) {
        statuses['Bluetooth'] = 'Permission granted; radio off';
        error = 'Turn on Bluetooth and Wi-Fi radio, then try again.';
        return false;
      }
      return true;
    } catch (e) {
      error = 'Unable to check permissions or radios: $e';
      return false;
    }
  }

  Future<bool> openSettings() => openAppSettings();
}
