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
    expect(
      map.features.where((f) => f['kind'] == 'road').length,
      greaterThan(50),
    );
    expect(
      map.features.where((f) => f['kind'] == 'building').length,
      greaterThan(50),
    );
    expect(map.contains(fix(14.036, 100.728)), isTrue);
    expect(map.contains(fix(13.75, 100.5)), isFalse);
    expect(map.project(100.719, 14.045, const Size(100, 100)), Offset.zero);
    expect(
      map.project(100.738, 14.026, const Size(100, 100)),
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
    await tester.runAsync(OfflineMapData.load);
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
                    'แผนที่ออฟไลน์ • มทร.ธัญบุรี',
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
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    await tester.tap(find.byTooltip('ซูมเข้า'));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await tester.tap(find.byTooltip('ดูทั้งพื้นที่'));
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
          'output/offline-map-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
