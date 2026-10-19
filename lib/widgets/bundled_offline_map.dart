import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/offline_map_data.dart';
import '../models/sos_alert.dart';
import '../services/offline_tile_store.dart';
import 'offline_map_tile_layer.dart';

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
    this.fullScreen = false,
    this.onLocateMe,
    this.onPickLocation,
    this.compact = false,
  });
  final List<OfflineMapMarker> markers;
  final SosLocation? focus;
  final double height;
  final bool fullScreen;
  final bool compact;
  final VoidCallback? onLocateMe;
  final ValueChanged<SosLocation>? onPickLocation;

  @override
  State<BundledOfflineMap> createState() => _BundledOfflineMapState();
}

class _BundledOfflineMapState extends State<BundledOfflineMap> {
  final _controller = TransformationController();
  final _data = OfflineMapData.load();
  bool _compactPositioned = false;

  @override
  void didUpdateWidget(covariant BundledOfflineMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus) _compactPositioned = false;
  }

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
      256.0,
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
        return widget.fullScreen
            ? const Center(child: Text('กำลังเปิดแผนที่ออฟไลน์…'))
            : SizedBox(
                height: widget.height,
                child: const Center(child: Text('กำลังเปิดแผนที่ออฟไลน์…')),
              );
      }
      final data = snapshot.requireData;
      final outside = widget.markers
          .where((m) => !data.contains(m.location))
          .length;
      final dark = Theme.of(context).brightness == Brightness.dark;

      Widget buildMapStack(BoxConstraints constraints) {
        final size = Size(
          constraints.maxWidth,
          widget.fullScreen ? constraints.maxHeight : widget.height,
        );
        final mapSize = _fit(data, size);
        final origin = Offset(
          (size.width - mapSize.width) / 2,
          (size.height - mapSize.height) / 2,
        );
        Offset project(SosLocation p) =>
            origin + data.project(p.longitude, p.latitude, mapSize);

        if (!_compactPositioned) {
          _compactPositioned = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final focus = widget.focus;
            _zoom(
              (focus != null && data.contains(focus) ? 32.0 : 1.0) /
                  _controller.value.getMaxScaleOnAxis(),
              size,
              target: focus != null && data.contains(focus)
                  ? project(focus)
                  : size.center(Offset.zero),
            );
          });
        }

        return GestureDetector(
          onTapUp: widget.onPickLocation == null
              ? null
              : (details) {
                  final point =
                      _controller.toScene(details.localPosition) - origin;
                  if (point.dx < 0 ||
                      point.dy < 0 ||
                      point.dx > mapSize.width ||
                      point.dy > mapSize.height) {
                    return;
                  }
                  final picked = SosLocation(
                    longitude:
                        data.bounds[0] +
                        point.dx /
                            mapSize.width *
                            (data.bounds[2] - data.bounds[0]),
                    latitude:
                        data.bounds[3] -
                        point.dy /
                            mapSize.height *
                            (data.bounds[3] - data.bounds[1]),
                    accuracy: 0,
                    capturedAt: DateTime.now().toUtc(),
                    manuallySelected: true,
                  );
                  if (data.contains(picked)) widget.onPickLocation!(picked);
                },
          child: ClipRect(
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 256,
                  boundaryMargin: const EdgeInsets.all(200),
                  child: RepaintBoundary(
                    child: OfflineMapTileLayer(
                      data: data,
                      controller: _controller,
                      size: size,
                      mapSize: mapSize,
                      origin: origin,
                      dark: dark,
                      compact: widget.compact,
                      markerPoints: [
                        for (final m in widget.markers.where(
                          (m) => data.contains(m.location),
                        ))
                          project(m.location),
                      ],
                    ),
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
                // 2. ย้าย "↑ N • ออฟไลน์" ให้เป็น chip เล็กๆ ไม่บังแผนที่
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (dark ? const Color(0xFF102D43) : Colors.white)
                          .withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: dark ? Colors.white24 : const Color(0xFFEAE2D8),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.navigation_rounded,
                          size: 13,
                          color: Color(0xFFB94612),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'N • ออฟไลน์',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: dark
                                ? Colors.white
                                : const Color(0xFF102D43),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 2. เหลือแค่ ซูมเข้า/ออก (กลุ่มเดียว) และปุ่ม "ไปที่ตำแหน่งของฉัน" 1 ปุ่ม
                if (!widget.compact)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ซูมเข้า/ออก กลุ่มเดียว
                        Container(
                          decoration: BoxDecoration(
                            color:
                                (dark ? const Color(0xFF102D43) : Colors.white)
                                    .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: dark
                                  ? Colors.white24
                                  : const Color(0xFFEAE2D8),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(13),
                                  ),
                                  onTap: () => _zoom(1.7, size),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Tooltip(
                                      message: 'ซูมเข้า',
                                      child: Icon(
                                        Icons.add,
                                        size: 22,
                                        color: dark
                                            ? Colors.white
                                            : const Color(0xFF102D43),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: dark
                                    ? Colors.white12
                                    : const Color(0xFFEAE2D8),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(13),
                                  ),
                                  onTap: () => _zoom(1 / 1.7, size),
                                  onLongPress: () =>
                                      _controller.value = Matrix4.identity(),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Tooltip(
                                      message: 'ซูมออก',
                                      triggerMode: TooltipTriggerMode.manual,
                                      child: Icon(
                                        Icons.remove,
                                        size: 22,
                                        color: dark
                                            ? Colors.white
                                            : const Color(0xFF102D43),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ปุ่ม "ไปที่ตำแหน่งของฉัน" 1 ปุ่มสะอาด
                        Material(
                          color: (dark ? const Color(0xFF102D43) : Colors.white)
                              .withValues(alpha: 0.92),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: dark
                                  ? Colors.white24
                                  : const Color(0xFFEAE2D8),
                              width: 1,
                            ),
                          ),
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.15),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              if (widget.focus != null &&
                                  data.contains(widget.focus!)) {
                                _zoom(
                                  1.6,
                                  size,
                                  target: project(widget.focus!),
                                );
                              } else {
                                widget.onLocateMe?.call();
                              }
                            },
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Tooltip(
                                message: 'ไปที่ตำแหน่งของฉัน',
                                child: Icon(
                                  Icons.my_location,
                                  size: 22,
                                  color: Color(0xFFB94612),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                if (outside > 0 && widget.fullScreen)
                  Positioned(
                    bottom: 34,
                    left: 12,
                    child: Container(
                      color: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.all(6),
                      child: Text('$outside ตำแหน่งอยู่นอกจังหวัดปทุมธานี'),
                    ),
                  ),
                Positioned(
                  bottom: 34,
                  right: 8,
                  child: ListenableBuilder(
                    listenable: OfflineTileStore.shared,
                    builder: (context, _) =>
                        OfflineTileStore.shared.failures.isEmpty
                        ? const SizedBox.shrink()
                        : TextButton(
                            onPressed: OfflineTileStore.shared.retryFailures,
                            child: const Text(
                              'เปิดแผนที่บางส่วนไม่ได้ • ลองใหม่',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (widget.fullScreen) {
        return LayoutBuilder(
          builder: (context, constraints) => buildMapStack(constraints),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) => buildMapStack(constraints),
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

  // 2. แก้ปุ่มสีเขียวที่มีวงเงาเทาซ้อนอยู่ให้เป็นปุ่มเดียวที่สะอาด
  Widget _marker(OfflineMapMarker marker, Offset position) => Positioned(
    left: position.dx - 22,
    top: position.dy - 22,
    child: Semantics(
      label: marker.label,
      button: true,
      child: GestureDetector(
        key: ValueKey('map-marker-${marker.id}'),
        onTap:
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
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: marker.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            marker.isMe ? Icons.my_location : Icons.person_pin_circle_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
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
