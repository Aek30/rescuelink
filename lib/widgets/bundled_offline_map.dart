import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/offline_map_data.dart';
import '../models/sos_alert.dart';

class OfflineMapMarker {
  const OfflineMapMarker({
    required this.id,
    required this.label,
    required this.location,
    required this.color,
    this.onTap,
    this.isMe = false,
  });
  final String id, label;
  final SosLocation location;
  final Color color;
  final VoidCallback? onTap;
  final bool isMe;
}

/// All geography, labels and controls work without network access.
class BundledOfflineMap extends StatefulWidget {
  const BundledOfflineMap({
    super.key,
    this.markers = const [],
    this.focus,
    this.height = 330,
  });
  final List<OfflineMapMarker> markers;
  final SosLocation? focus;
  final double height;
  @override
  State<BundledOfflineMap> createState() => _BundledOfflineMapState();
}

class _BundledOfflineMapState extends State<BundledOfflineMap> {
  final _controller = TransformationController();
  final _data = OfflineMapData.load();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double factor, Size size, {Offset? target}) {
    final center = size.center(Offset.zero);
    final point = target ?? _controller.toScene(center);
    final scale = (_controller.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      10.0,
    );
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, center.dx - point.dx * scale)
      ..setEntry(1, 3, center.dy - point.dy * scale);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OfflineMapData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'เปิดไฟล์แผนที่ไม่ได้ • ยังดูตัวเลขพิกัดและติดต่อผ่านแชตได้',
          ),
        );
      }
      if (!snapshot.hasData) {
        return SizedBox(
          height: widget.height,
          child: const Center(child: Text('กำลังเปิดแผนที่ออฟไลน์…')),
        );
      }
      final data = snapshot.requireData;
      final outside = widget.markers
          .where((m) => !data.contains(m.location))
          .length;
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, widget.height);
                final mapSize = _fit(data, size);
                final origin = Offset(
                  (size.width - mapSize.width) / 2,
                  (size.height - mapSize.height) / 2,
                );
                Offset project(SosLocation p) =>
                    origin + data.project(p.longitude, p.latitude, mapSize);
                return ClipRect(
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _controller,
                        minScale: 1,
                        maxScale: 10,
                        boundaryMargin: const EdgeInsets.all(200),
                        child: CustomPaint(
                          size: size,
                          painter: _RoadPainter(data, dark),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => Stack(
                          children: [
                            for (final marker in widget.markers.where(
                              (m) => data.contains(m.location),
                            ))
                              _marker(
                                marker,
                                MatrixUtils.transformPoint(
                                  _controller.value,
                                  project(marker.location),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Positioned(
                        top: 10,
                        left: 12,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('↑ N • ออฟไลน์'),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 8,
                        child: Card(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'ซูมเข้า',
                                onPressed: () => _zoom(1.7, size),
                                icon: const Icon(Icons.add),
                              ),
                              IconButton(
                                tooltip: 'ซูมออก',
                                onPressed: () => _zoom(1 / 1.7, size),
                                icon: const Icon(Icons.remove),
                              ),
                              IconButton(
                                tooltip: 'ดูทั้งพื้นที่',
                                onPressed: () =>
                                    _controller.value = Matrix4.identity(),
                                icon: const Icon(Icons.fit_screen),
                              ),
                              if (widget.focus != null &&
                                  data.contains(widget.focus!))
                                IconButton(
                                  tooltip: 'ไปยังพิกัดที่เลือก',
                                  onPressed: () => _zoom(
                                    1,
                                    size,
                                    target: project(widget.focus!),
                                  ),
                                  icon: const Icon(Icons.my_location),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: .93),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: const Text(
                              '© OpenStreetMap contributors • ODbL 1.0',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.name} • แผนที่บันทึก ${data.date}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'เลื่อน/กางนิ้วเพื่อซูม • ไม่มีระบบนำทางตามถนน',
                  style: TextStyle(fontSize: 11),
                ),
                if (outside > 0)
                  Text(
                    '$outside ตำแหน่งอยู่นอกพื้นที่แผนที่ • ดูพิกัดในรายการด้านล่าง',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.deepOrange,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _marker(OfflineMapMarker marker, Offset position) => Positioned(
    left: position.dx - 22,
    top: position.dy - 22,
    child: IconButton.filled(
      key: ValueKey('map-marker-${marker.id}'),
      tooltip: marker.label,
      style: IconButton.styleFrom(
        backgroundColor: marker.color,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        maximumSize: const Size(44, 44),
      ),
      onPressed:
          marker.onTap ??
          () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(marker.label),
              content: Text(marker.location.summary),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
              ],
            ),
          ),
      icon: Icon(
        marker.isMe ? Icons.my_location : Icons.person_pin_circle_outlined,
      ),
    ),
  );
}

Size _fit(OfflineMapData data, Size size) {
  final scale = math.min(
    (size.width - 24) / data.widthMeters,
    (size.height - 24) / data.heightMeters,
  );
  return Size(data.widthMeters * scale, data.heightMeters * scale);
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.data, this.dark);
  final OfflineMapData data;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF172624) : const Color(0xFFEAF0E6),
    );
    final mapSize = _fit(data, size);
    final origin = Offset(
      (size.width - mapSize.width) / 2,
      (size.height - mapSize.height) / 2,
    );
    canvas.save();
    canvas.clipRect(origin & mapSize);
    final labels = <({String name, Offset point, bool road})>[];
    for (final kind in ['campus', 'land', 'water', 'building', 'road']) {
      for (final f in data.features.where((f) => f['kind'] == kind)) {
        final coordinates = f['points'] as List;
        final points = coordinates
            .map(
              (p) =>
                  origin +
                  data.project(
                    (p[0] as num).toDouble(),
                    (p[1] as num).toDouble(),
                    mapSize,
                  ),
            )
            .toList();
        if (points.length < 2) continue;
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        final closed = f['closed'] == true;
        if (closed) path.close();
        final road = kind == 'road';
        final major = [
          'primary',
          'secondary',
          'tertiary',
          'trunk',
        ].contains(f['roadClass']);
        final color = switch (kind) {
          'campus' => dark ? const Color(0xFF263931) : const Color(0xFFDFEAD5),
          'land' => dark ? const Color(0xFF254338) : const Color(0xFFD0E3C8),
          'water' => dark ? const Color(0xFF214C62) : const Color(0xFFA9D8EC),
          'building' =>
            dark ? const Color(0xFF54625E) : const Color(0xFFD5CEBF),
          _ =>
            major
                ? const Color(0xFFE8C078)
                : (dark ? const Color(0xFFA7B3AD) : Colors.white),
        };
        if (road) {
          canvas.drawPath(
            path,
            Paint()
              ..color = dark ? const Color(0xFF263530) : const Color(0xFFC6CDBF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = major ? 4 : 2.6
              ..strokeJoin = StrokeJoin.round,
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = closed && !road
                ? PaintingStyle.fill
                : PaintingStyle.stroke
            ..strokeWidth = road ? (major ? 2.7 : 1.5) : 2
            ..strokeJoin = StrokeJoin.round,
        );
        final name = f['name'] as String?;
        if (name != null &&
            name.isNotEmpty &&
            (road || kind == 'campus' || kind == 'building')) {
          final anchor = road
              ? points[points.length ~/ 2]
              : path.getBounds().center;
          if ((origin & mapSize).contains(anchor)) {
            labels.add((name: name, point: anchor, road: road));
          }
        }
      }
    }
    final occupied = <Rect>[];
    for (final label in labels) {
      final text = TextPainter(
        text: TextSpan(
          text: label.name,
          style: TextStyle(
            fontFamily: 'NotoSansThai',
            fontSize: label.road ? 5.5 : 6,
            color: dark ? Colors.white : const Color(0xFF3E5147),
            backgroundColor: (dark ? const Color(0xFF172624) : Colors.white)
                .withValues(alpha: .8),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: 90);
      final box = Rect.fromCenter(
        center: label.point,
        width: text.width + 3,
        height: text.height + 3,
      );
      if (occupied.any((r) => r.overlaps(box))) continue;
      occupied.add(box);
      text.paint(canvas, label.point - Offset(text.width / 2, text.height / 2));
    }
    canvas.restore();
    canvas.drawRect(
      origin & mapSize,
      Paint()
        ..color = Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5,
    );
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.dark != dark;
}
