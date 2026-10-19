import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/offline_map_data.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/widgets/bundled_offline_map.dart';
import 'package:rescuelink/services/offline_tile_store.dart';

SosLocation fix(double lat, double lon) => SosLocation(
  latitude: lat,
  longitude: lon,
  accuracy: 8,
  capturedAt: DateTime.utc(2026, 10, 18),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled data has real roads, buildings and bounded projection', (
    tester,
  ) async {
    final map = (await tester.runAsync(OfflineMapData.load))!;
    expect(map.sourceCounts['road'], greaterThan(50));
    expect(map.sourceCounts['building'], greaterThan(50));
    expect(map.contains(fix(14.036, 100.728)), isTrue);
    expect(map.contains(fix(13.75, 100.5)), isFalse);
    for (final point in [
      fix(14.0208, 100.525),
      fix(14.065, 100.647),
      fix(14.02, 100.735),
      fix(14.133, 100.826),
      fix(14.039, 100.407),
      fix(13.932, 100.78),
      fix(14.069, 100.523),
    ]) {
      expect(
        map.contains(point),
        isTrue,
        reason: 'All seven districts must be covered',
      );
    }
    expect(map.levels, [1, 4, 16, 64]);
    expect(map.visibleTiles(3, const Rect.fromLTWH(-2, -2, .1, .1)), isEmpty);
    final campus = map.project(100.728, 14.036, const Size(1, 1));
    expect(
      map
          .visibleTiles(
            3,
            Rect.fromCenter(center: campus, width: .01, height: .01),
          )
          .length,
      lessThanOrEqualTo(4),
    );
    expect(
      map.project(
        map.bounds[0].toDouble(),
        map.bounds[3].toDouble(),
        const Size(100, 100),
      ),
      Offset.zero,
    );
    expect(
      map.project(
        map.bounds[2].toDouble(),
        map.bounds[1].toDouble(),
        const Size(100, 100),
      ),
      const Offset(100, 100),
    );
  });

  test('old presence decodes without invented rescue coordinates', () {
    final old = PeerPresence.decode(
      '{"version":1,"sequence":1,"rescue":true,"receivedAt":"2026-10-18T00:00:00Z"}',
    );
    expect(old.mapLocation, isNull);
    final location = fix(14.036, 100.728);
    final decoded = PeerPresence.decode(
      PeerPresence(
        sequence: 2,
        rescue: true,
        receivedAt: DateTime.utc(2026, 10, 18),
        rescueLocation: location,
      ).encode(),
    );
    expect(decoded.mapLocation!.longitude, location.longitude);
    expect(decoded.mapLocation!.capturedAt, location.capturedAt);
  });

  testWidgets('offline roads, outside-area warning, zoom and marker actions', (
    tester,
  ) async {
    final data = (await tester.runAsync(OfflineMapData.load))!;
    final warmOwner = Object();
    await tester.runAsync(() async {
      final p = data.project(100.728, 14.036, const Size(1, 1));
      final keys = <String>{
        '0_0_0',
        ...data.visibleTiles(
          3,
          Rect.fromCenter(center: p, width: .034, height: .07),
        ),
      }.toList();
      OfflineTileStore.shared.request(warmOwner, keys);
      for (var i = 0; i < 200 && OfflineTileStore.shared.activeLoads > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(OfflineTileStore.shared.failures, isEmpty);
    });
    addTearDown(() => OfflineTileStore.shared.release(warmOwner));
    await tester.runAsync(() async {
      final font = FontLoader('NotoSansThai')
        ..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var tapped = false;
    final key = GlobalKey();
    Future<void> preview(String name) async {
      if (!const bool.fromEnvironment('MAP_PREVIEW')) return;
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('output').create(recursive: true);
        await File(
          'output/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansThai'),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    'แผนที่ออฟไลน์ • ปทุมธานี',
                    style: TextStyle(fontSize: 20),
                  ),
                  BundledOfflineMap(
                    height: 470,
                    focus: fix(14.036, 100.728),
                    markers: [
                      OfflineMapMarker(
                        id: 'me',
                        label: 'ฉัน',
                        location: fix(14.036, 100.728),
                        color: Colors.green,
                        isMe: true,
                      ),
                      OfflineMapMarker(
                        id: 'sos',
                        label: 'SOS',
                        location: fix(14.038, 100.726),
                        color: Colors.red,
                        onTap: () => tapped = true,
                      ),
                      OfflineMapMarker(
                        id: 'rescue',
                        label: 'กู้ภัย',
                        location: fix(14.034, 100.73),
                        color: Colors.blue,
                      ),
                      OfflineMapMarker(
                        id: 'outside',
                        label: 'นอกพื้นที่',
                        location: fix(13.75, 100.5),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 ตำแหน่งอยู่นอกพื้นที่'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-marker-outside')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('map-marker-sos')));
    expect(tapped, isTrue);
    await preview('pathum-map-detail');
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    await tester.tap(find.byTooltip('ซูมเข้า'));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await tester.longPress(find.byTooltip('ซูมออก'));
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('MAP_PREVIEW')) {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('output').create(recursive: true);
        await File(
          'output/pathum-map-overview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
