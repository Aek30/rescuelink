import 'dart:convert';
import 'sos_alert.dart';

/// Location messages retain the existing text-message envelope for storage,
/// radio forwarding, receipts and offline retry.
abstract final class ChatLocationMessage {
  // Older app versions display text verbatim, so the wire format must also be
  // understandable without a location-card renderer.
  static String encode(SosLocation location) {
    final coordinates = '${location.latitude}, ${location.longitude}';
    final source = location.manuallySelected
        ? 'ปักหมุดเอง'
        : 'ความแม่นยำ: ${location.accuracy} เมตร';
    return '📍 แชร์ตำแหน่ง\n'
        'พิกัด: $coordinates\n'
        '$source\n'
        'เวลาบันทึก: ${location.capturedAt.toUtc().toIso8601String()}\n'
        'https://www.google.com/maps?q=${location.latitude},${location.longitude}';
  }

  static final _readableLocation = RegExp(
    r'^📍 แชร์ตำแหน่ง\nพิกัด: ([^,\n]+), ([^\n]+)\n'
    r'(ปักหมุดเอง|ความแม่นยำ: ([^\n]+) เมตร)\n'
    r'เวลาบันทึก: ([^\n]+)\nhttps://www\.google\.com/maps\?q=([^,\n]+),([^\n]+)$',
  );

  static SosLocation? parse(String text) {
    if (text.length > 4096) return null;
    try {
      final readable = _readableLocation.firstMatch(text);
      if (readable != null) {
        final latitude = double.parse(readable[1]!);
        final longitude = double.parse(readable[2]!);
        if (double.parse(readable[6]!) != latitude ||
            double.parse(readable[7]!) != longitude) {
          return null;
        }
        return SosLocation(
          latitude: latitude,
          longitude: longitude,
          accuracy: readable[4] == null ? 0 : double.parse(readable[4]!),
          capturedAt: DateTime.parse(readable[5]!),
          manuallySelected: readable[3] == 'ปักหมุดเอง',
        );
      }
      if (!text.startsWith('{')) return null;
      final value = jsonDecode(text);
      if (value is! Map ||
          value['type'] != 'rescuelink.location' ||
          value['version'] != 1) {
        return null;
      }
      return SosLocation.fromMap(
        Map<String, dynamic>.from(value['location'] as Map),
      );
    } catch (_) {
      return null;
    }
  }
}
