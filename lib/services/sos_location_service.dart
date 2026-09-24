import 'dart:async';
import 'package:location/location.dart';
import '../models/sos_alert.dart';

class SosLocationService {
  Future<SosLocation> capture() async {
    final location = Location();
    if (!await location.serviceEnabled() && !await location.requestService()) {
      throw StateError('กรุณาเปิดบริการตำแหน่ง หรือส่ง SOS โดยไม่แนบพิกัด');
    }
    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
    }
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      throw StateError(
        'ไม่ได้รับสิทธิ์ตำแหน่ง เปิดสิทธิ์ในการตั้งค่า หรือส่งโดยไม่แนบพิกัด',
      );
    }
    final fix = await location.getLocation().timeout(
      const Duration(seconds: 25),
    );
    if (fix.accuracy == null || fix.time == null) {
      throw StateError('ยังไม่มีพิกัด GPS กรุณาลองใหม่ หรือส่งโดยไม่แนบพิกัด');
    }
    return SosLocation(
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracy: fix.accuracy!,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        fix.time!.toInt(),
        isUtc: true,
      ),
    );
  }
}
