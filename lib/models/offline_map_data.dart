import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'sos_alert.dart';

/// A bundled OSM extract. Loading it never invokes a tile server.
class OfflineMapData {
  OfflineMapData.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      date = json['extractedAt'] as String,
      bounds = (json['bounds'] as List).cast<num>(),
      features = (json['features'] as List).cast<Map<String, dynamic>>();
  final String name, date;
  final List<num> bounds; // west, south, east, north
  final List<Map<String, dynamic>> features;
  static Future<OfflineMapData>? _loaded;
  static OfflineMapData? _cached;
  static Future<OfflineMapData> load() {
    if (_cached != null) return SynchronousFuture(_cached!);
    return _loaded ??= rootBundle
        .loadString('assets/maps/rmutt.json')
        .then((text) {
          return _cached = OfflineMapData.fromJson(
            jsonDecode(text) as Map<String, dynamic>,
          );
        })
        .catchError((Object error) {
          _loaded = null;
          throw error;
        });
  }

  double get _cos => math.cos((bounds[1] + bounds[3]) / 2 * math.pi / 180);
  double get widthMeters => (bounds[2] - bounds[0]) * 111320 * _cos;
  double get heightMeters => (bounds[3] - bounds[1]) * 111320;
  bool contains(SosLocation p) =>
      p.longitude >= bounds[0] &&
      p.longitude <= bounds[2] &&
      p.latitude >= bounds[1] &&
      p.latitude <= bounds[3];
  Offset project(double longitude, double latitude, Size size) => Offset(
    (longitude - bounds[0]) / (bounds[2] - bounds[0]) * size.width,
    (bounds[3] - latitude) / (bounds[3] - bounds[1]) * size.height,
  );
}
