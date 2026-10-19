import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/offline_map_data.dart';
import '../services/offline_tile_store.dart';

class OfflineMapTileLayer extends StatefulWidget {
  const OfflineMapTileLayer({
    super.key,
    required this.data,
    required this.controller,
    required this.size,
    required this.mapSize,
    required this.origin,
    required this.dark,
    this.markerPoints = const [],
    this.compact = false,
  });
  final OfflineMapData data;
  final TransformationController controller;
  final Size size, mapSize;
  final Offset origin;
  final bool dark;
  final List<Offset> markerPoints;
  final bool compact;
  @override
  State<OfflineMapTileLayer> createState() => _OfflineMapTileLayerState();
}

class _OfflineMapTileLayerState extends State<OfflineMapTileLayer> {
  final _owner = Object();
  final _store = OfflineTileStore.shared;
  Timer? _timer;
  String _signature = '';
  bool _enabled = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_enabled != enabled) {
      _enabled = enabled;
      _timer?.cancel();
      _store.release(_owner);
      _signature = '';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _store.release(_owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.controller, _store]),
    builder: (context, _) {
      final scale = widget.controller.value.getMaxScaleOnAxis();
      final topLeft = widget.controller.toScene(Offset.zero) - widget.origin;
      final bottomRight =
          widget.controller.toScene(
            Offset(widget.size.width, widget.size.height),
          ) -
          widget.origin;
      final viewport = Rect.fromLTRB(
        topLeft.dx / widget.mapSize.width,
        topLeft.dy / widget.mapSize.height,
        bottomRight.dx / widget.mapSize.width,
        bottomRight.dy / widget.mapSize.height,
      );
      var level = widget.data.levelFor(widget.mapSize.width * scale);
      var selected = widget.data.visibleTiles(level, viewport);
      // Tall phones/tablets must still fit the bounded cache without holes.
      bool exceedsBudget() {
        final requested = <String>{...selected, '0_0_0'};
        var bytes = 0;
        var vertices = 0;
        for (final key in requested) {
          final meta = widget.data.tiles[key] as Map?;
          bytes += ((meta?['bytes'] as num?)?.toInt() ?? 0) * 2;
          vertices += (meta?['vertices'] as num?)?.toInt() ?? 0;
        }
        return selected.length > 16 ||
            bytes > _store.maxBytes * .7 ||
            vertices > _store.maxVertices * .7;
      }

      while (exceedsBudget() && level > 0) {
        level--;
        selected = widget.data.visibleTiles(level, viewport);
      }
      final keys = <String>{...selected, '0_0_0'}.toList();
      final signature = keys.join(',');
      if (_enabled && signature != _signature) {
        _signature = signature;
        _timer?.cancel();
        _timer = Timer(
          const Duration(milliseconds: 80),
          () => _store.request(_owner, keys),
        );
      }
      final tiles = <OfflineTile>[
        if (level != 0 && _store.peek('0_0_0') != null) _store.peek('0_0_0')!,
        for (final key in selected)
          if (_store.peek(key) != null) _store.peek(key)!,
      ];
      return CustomPaint(
        size: widget.size,
        painter: _TilePainter(
          widget.data,
          tiles,
          widget.mapSize,
          widget.origin,
          viewport,
          scale,
          widget.dark,
          widget.controller.value.clone(),
          widget.markerPoints,
          widget.compact,
        ),
      );
    },
  );
}

class _TilePainter extends CustomPainter {
  _TilePainter(
    this.data,
    this.tiles,
    this.mapSize,
    this.origin,
    this.viewport,
    this.zoom,
    this.dark,
    this.transform,
    this.markerPoints,
    this.compact,
  );
  final OfflineMapData data;
  final List<OfflineTile> tiles;
  final Size mapSize;
  final Offset origin;
  final Rect viewport;
  final double zoom;
  final bool dark;
  final Matrix4 transform;
  final List<Offset> markerPoints;
  final bool compact;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF142421) : const Color(0xFFE1E5E0),
    );
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(mapSize.width, mapSize.height);
    canvas.drawPath(
      data.boundaryPath,
      Paint()..color = dark ? const Color(0xFF22362D) : const Color(0xFFF0EFE4),
    );
    canvas.restore();
    final labels =
        <
          ({String name, Offset point, bool place, double angle, double length})
        >[];
    for (final tile in tiles) {
      final address = tile.key.split('_').map(int.parse).toList();
      final n = data.levels[address[0]];
      final tileRect = Rect.fromLTWH(
        address[1] / n,
        address[2] / n,
        1 / n,
        1 / n,
      );
      if (!viewport.overlaps(tileRect)) continue;
      final left = origin.dx + tileRect.left * mapSize.width;
      final top = origin.dy + tileRect.top * mapSize.height;
      final width = mapSize.width / n, height = mapSize.height / n;
      final sx = width / 4096, sy = height / 4096;
      final unit = zoom * math.sqrt(sx * sy);
      final visible = viewport.intersect(tileRect);
      final localVisible = Rect.fromLTRB(
        (visible.left - tileRect.left) * n * 4096,
        (visible.top - tileRect.top) * n * 4096,
        (visible.right - tileRect.left) * n * 4096,
        (visible.bottom - tileRect.top) * n * 4096,
      );
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(left, top, width, height));
      // Clear coarse geometry underneath detailed cells, avoiding doubled roads.
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(mapSize.width, mapSize.height);
      canvas.drawPath(
        data.boundaryPath,
        Paint()
          ..color = dark ? const Color(0xFF22362D) : const Color(0xFFF0EFE4),
      );
      canvas.restore();
      canvas.translate(left, top);
      canvas.scale(sx, sy);
      for (final kind in [
        'land',
        'campus',
        'water',
        'building',
        'road',
        'place',
      ]) {
        for (final feature in tile.features) {
          if (feature.kind != kind) continue;
          if (kind != 'place' && !feature.bounds.overlaps(localVisible)) {
            continue;
          }
          final road = kind == 'road';
          final major = const {
            'motorway',
            'motorway_link',
            'trunk',
            'trunk_link',
            'primary',
            'primary_link',
            'secondary',
            'secondary_link',
            'tertiary',
            'tertiary_link',
          }.contains(feature.roadClass);
          final foot = const {
            'footway',
            'path',
            'steps',
            'cycleway',
          }.contains(feature.roadClass);
          final color = switch (kind) {
            'water' => dark ? const Color(0xFF244E64) : const Color(0xFFA9D8EC),
            'land' => dark ? const Color(0xFF304B37) : const Color(0xFFDCE7CD),
            'campus' =>
              dark ? const Color(0xFF374735) : const Color(0xFFE1EACF),
            'building' =>
              dark ? const Color(0xFF65736C) : const Color(0xFFD8CEC0),
            _ =>
              major
                  ? const Color(0xFFE8BF78)
                  : foot
                  ? const Color(0xFFB8B5A7)
                  : dark
                  ? const Color(0xFF9EABA5)
                  : Colors.white,
          };
          final stroke = address[0] == 0
              ? (major ? 1.0 : .6)
              : major
              ? 3.0
              : foot
              ? 1.0
              : 1.7;
          if (road) {
            canvas.drawPath(
              feature.path,
              Paint()
                ..color = dark
                    ? const Color(0xFF192B22)
                    : const Color(0xFFC6CABF)
                ..style = PaintingStyle.stroke
                ..strokeWidth = (stroke + (address[0] == 0 ? .4 : 1.2)) / unit
                ..strokeJoin = StrokeJoin.round,
            );
          }
          canvas.drawPath(
            feature.path,
            Paint()
              ..color = color
              ..style = feature.closed && !road
                  ? PaintingStyle.fill
                  : PaintingStyle.stroke
              ..strokeWidth =
                  (road
                      ? stroke
                      : address[0] == 0
                      ? .6
                      : 1.5) /
                  unit
              ..strokeJoin = StrokeJoin.round,
          );
          if (feature.name.isNotEmpty &&
              feature.anchor != null &&
              localVisible.contains(feature.anchor!)) {
            if (address[0] == 0 &&
                (kind != 'place' ||
                    feature.name.startsWith('บ้าน') ||
                    feature.name.startsWith('หมู่'))) {
              continue;
            }
            if (tiles.length > 1 && address[0] == 0) continue;
            if (kind == 'building' && (address[0] < 3 || zoom < 24)) continue;
            if (!RegExp(r'[\u0E00-\u0E7F]').hasMatch(feature.name)) continue;
            if (compact || kind == 'land' || kind == 'water') continue;
            if (kind == 'place' &&
                zoom < 64 &&
                (feature.name.startsWith('บ้าน') ||
                    feature.name.startsWith('หมู่'))) {
              continue;
            }
            if (road && (foot || zoom < 4 || (!major && zoom < 16))) continue;
            var anchor = feature.anchor!;
            var angle = 0.0;
            var length = double.infinity;
            if (road) {
              final metrics = feature.path.computeMetrics().toList();
              if (metrics.isEmpty) continue;
              metrics.sort((a, b) => b.length.compareTo(a.length));
              final metric = metrics.first;
              final tangent = metric.getTangentForOffset(metric.length / 2);
              if (tangent == null) continue;
              anchor = tangent.position;
              angle = math.atan2(
                tangent.vector.dy * sy,
                tangent.vector.dx * sx,
              );
              if (angle > math.pi / 2) angle -= math.pi;
              if (angle < -math.pi / 2) angle += math.pi;
              length = metric.length * math.min(sx, sy) * zoom;
            }
            labels.add((
              angle: angle,
              length: length,
              name: feature.name,
              point: Offset(left + anchor.dx * sx, top + anchor.dy * sy),
              place: kind == 'place',
            ));
          }
        }
      }
      canvas.restore();
    }
    // Cancel the viewer transform before laying out text. Tiny scene-space
    // fonts have inaccurate shaping/rounding at high zoom, causing overlaps.
    canvas.save();
    canvas.transform(Matrix4.inverted(transform).storage);
    canvas.clipRect(Offset.zero & size);
    labels.sort((a, b) => (b.place ? 1 : 0).compareTo(a.place ? 1 : 0));
    final occupied = <Rect>[
      const Rect.fromLTWH(0, 0, 120, 48),
      if (!compact) Rect.fromLTWH(size.width - 76, 0, 76, 184),
      Rect.fromLTWH(0, size.height - 64, size.width, 64),
      for (final p in markerPoints)
        Rect.fromCenter(
          center: MatrixUtils.transformPoint(transform, p),
          width: 64,
          height: 64,
        ),
    ];
    final names = <String>{};
    var count = 0;
    for (final label in labels) {
      if (count >= 14) break;
      if (names.contains(label.name)) continue;
      final text = TextPainter(
        text: TextSpan(
          text: label.name,
          style: TextStyle(
            fontFamily: 'NotoSansThai',
            fontSize: label.place ? 12 : 10,
            fontWeight: label.place ? FontWeight.w700 : FontWeight.w500,
            color: dark ? Colors.white : const Color(0xFF344C40),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: 130);
      final point = MatrixUtils.transformPoint(transform, label.point);
      final w = text.width + 10, h = text.height + 8;
      final rect = Rect.fromCenter(
        center: point,
        width:
            w * math.cos(label.angle).abs() + h * math.sin(label.angle).abs(),
        height:
            w * math.sin(label.angle).abs() + h * math.cos(label.angle).abs(),
      );
      final safe = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
      if (label.length < w * 1.4 ||
          !safe.contains(rect.topLeft) ||
          !safe.contains(rect.bottomRight) ||
          occupied.any((r) => r.overlaps(rect))) {
        text.dispose();
        continue;
      }
      occupied.add(rect.inflate(6));
      names.add(label.name);
      count++;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(label.angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(3),
        ),
        Paint()
          ..color = (dark ? const Color(0xFF1C3028) : Colors.white).withValues(
            alpha: .88,
          ),
      );
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      canvas.restore();
      text.dispose();
    }
    canvas.restore();
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(mapSize.width, mapSize.height);
    canvas.drawPath(
      data.boundaryPath,
      Paint()
        ..color = dark ? Colors.white38 : const Color(0xFF849782)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / (mapSize.width * zoom),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TilePainter old) => true;
}
