import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'sos_alert.dart';

/// Only the small provincial index is resident. Geometry is loaded by tile.
class OfflineMapData {
  OfflineMapData.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      date = json['extractedAt'] as String,
      bounds = (json['bounds'] as List).cast<num>(),
      levels = (json['levels'] as List).cast<int>(),
      tiles = (json['tiles'] as Map).cast<String, dynamic>(),
      sourceCounts = (json['sourceCounts'] as Map).cast<String, dynamic>() {
    final boundary = json['boundary'] as Map;
    final coordinates = boundary['coordinates'] as List;
    final polygons = boundary['type'] == 'Polygon'
        ? [coordinates]
        : coordinates;
    rings = [
      for (final polygon in polygons)
        [
          for (final ring in polygon as List)
            [
              for (final p in ring as List)
                Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            ],
        ],
    ];
    boundaryPath = Path()..fillType = PathFillType.evenOdd;
    for (final polygon in rings) {
      for (final ring in polygon) {
        if (ring.isEmpty) continue;
        final points = ring
            .map((p) => project(p.dx, p.dy, const Size(1, 1)))
            .toList();
        boundaryPath.addPolygon(points, true);
      }
    }
  }
  final String name, date;
  final List<num> bounds;
  final List<int> levels;
  final Map<String, dynamic> tiles, sourceCounts;
  late final List<List<List<Offset>>> rings;
  late final Path boundaryPath;
  static Future<OfflineMapData>? _loaded;
  static OfflineMapData? _cached;
  static Future<OfflineMapData> load() {
    if (_cached != null) return SynchronousFuture(_cached!);
    return _loaded ??= rootBundle
        .loadString('assets/maps/pathum/index.json')
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
      containsPoint(Offset(p.longitude, p.latitude));
  bool containsPoint(Offset point) {
    if (point.dx < bounds[0] ||
        point.dx > bounds[2] ||
        point.dy < bounds[1] ||
        point.dy > bounds[3]) {
      return false;
    }
    for (final polygon in rings) {
      if (_inside(point, polygon.first) &&
          !polygon.skip(1).any((ring) => _inside(point, ring))) {
        return true;
      }
    }
    return false;
  }

  static bool _inside(Offset p, List<Offset> ring) {
    var inside = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  Offset project(double longitude, double latitude, Size size) => Offset(
    (longitude - bounds[0]) / (bounds[2] - bounds[0]) * size.width,
    (bounds[3] - latitude) / (bounds[3] - bounds[1]) * size.height,
  );

  /// Choose a level whose cells are roughly 150-600 screen pixels wide.
  int levelFor(double displayedWidth) {
    var level = 0;
    for (var i = 1; i < levels.length; i++) {
      if (displayedWidth / levels[i] >= 140) level = i;
    }
    return level;
  }

  List<String> visibleTiles(int level, Rect normalizedViewport) {
    final rect = normalizedViewport.intersect(const Rect.fromLTWH(0, 0, 1, 1));
    if (rect.isEmpty) return [];
    final n = levels[level];
    final x0 = (rect.left * n).floor().clamp(0, n - 1),
        x1 = (rect.right * n).floor().clamp(0, n - 1);
    final y0 = (rect.top * n).floor().clamp(0, n - 1),
        y1 = (rect.bottom * n).floor().clamp(0, n - 1);
    return [
      for (var y = y0; y <= y1; y++)
        for (var x = x0; x <= x1; x++)
          if (tiles.containsKey('${level}_${x}_$y')) '${level}_${x}_$y',
    ];
  }
}
