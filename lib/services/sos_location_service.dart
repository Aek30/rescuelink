import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sos_alert.dart';

class SosLocationService {
  SosLocationService({
    Future<bool> Function()? requestPermission,
    this.timeout = const Duration(seconds: 65),
  }) : _requestPermission = requestPermission ?? _permission;
  final Future<bool> Function() _requestPermission;
  final Duration timeout;
  static const channel = MethodChannel('com.rmutt.rescuelink/location');
  static Future<bool> _permission() async =>
      (await Permission.locationWhenInUse.request()).isGranted;
  static const timeoutMessage =
      'ยังจับสัญญาณตำแหน่งไม่ได้ กรุณาออกไปบริเวณโล่ง เปิดตำแหน่งแบบแม่นยำ ปิดโหมดประหยัดพลังงาน แล้วลองอีกครั้ง หรือส่ง SOS โดยไม่แนบพิกัด';

  Future<SosLocation> capture() async {
    if (!await _requestPermission()) {
      throw StateError(
        'ไม่ได้รับสิทธิ์ตำแหน่ง เปิดสิทธิ์ในการตั้งค่า หรือส่งโดยไม่แนบพิกัด',
      );
    }
    try {
      final map = await channel
          .invokeMapMethod<String, dynamic>('capture')
          .timeout(timeout);
      if (map == null) throw const FormatException('Empty location');
      final fix = SosLocation.fromMap(map);
      final age = DateTime.now().toUtc().difference(fix.capturedAt);
      if (age.isNegative || age > const Duration(minutes: 2)) {
        throw const FormatException('Stale location');
      }
      return fix;
    } on TimeoutException {
      try {
        await channel
            .invokeMethod<void>('cancel')
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      throw StateError(timeoutMessage);
    } on PlatformException catch (e) {
      throw StateError(switch (e.code) {
        'disabled' => 'กรุณาเปิดบริการตำแหน่ง/GPS ในการตั้งค่า แล้วลองใหม่',
        'permission' => 'กรุณาอนุญาตตำแหน่งแบบแม่นยำในการตั้งค่าแอป',
        'timeout' => '$timeoutMessage${_diagnostics(e.details)}',
        'canceled' =>
          'หยุดอ่านตำแหน่งแล้ว กรุณาเปิดหน้านี้ค้างไว้ระหว่างอ่าน GPS',
        'busy' => 'กำลังอ่านตำแหน่ง กรุณารอสักครู่',
        _ =>
          'อ่านตำแหน่งไม่ได้ กรุณาตรวจการตั้งค่าตำแหน่งแล้วลองใหม่ หรือส่งโดยไม่แนบพิกัด',
      });
    } on FormatException {
      throw StateError(
        'พิกัดที่ได้รับไม่สมบูรณ์หรือเก่าเกินไป กรุณาลองอ่าน GPS ใหม่',
      );
    }
  }

  static String _diagnostics(Object? details) {
    if (details is! Map) return '';
    final satellites = details['satellites'];
    final used = details['usedSatellites'];
    final fixes = details['fixesReceived'];
    final providers = details['providers'];
    return '\nข้อมูลตรวจสอบ: ${providers is List && providers.contains('gps') ? 'GPS เปิด' : 'GPS ไม่พร้อม'}'
        ' • ดาวเทียม ${satellites is int ? satellites : 'ไม่ทราบ'} ดวง'
        ' • ใช้คำนวณ ${used is int ? used : 'ไม่ทราบ'} ดวง'
        ' • พิกัดที่ระบบส่งกลับ ${fixes is int ? fixes : 0} ครั้ง';
  }
}
