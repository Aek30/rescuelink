import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/models/offline_map_data.dart';
import 'package:rescuelink/screens/nearby_test_screen.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:rescuelink/services/sos_location_service.dart';
import 'package:rescuelink/widgets/my_location_summary.dart';
import 'package:rescuelink/widgets/bundled_offline_map.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Native extends Fake implements Nearby {}

class _Nearby extends NearbyService {
  _Nearby() : super(nearby: _Native()) {
    permissions.statuses.updateAll((_, _) => 'Granted');
  }
  Completer<void>? pendingStart;
  @override
  Future<void> startNearby() async {
    await pendingStart?.future;
  }

  @override
  Future<void> stopAll() async {}
}

class _Messages extends MessageService {
  _Messages(NearbyService nearby)
    : super(
        nearbyService: nearby,
        database: LocalDatabaseService(factory: databaseFactoryFfi),
      ) {
    myId = 'me';
  }
  @override
  Future<void> initialize() async {}
}

class _Location extends SosLocationService {
  bool allowed = true;
  @override
  Future<bool> hasPermission() async => allowed;
  SosLocation? saved = SosLocation(
    latitude: 14.036,
    longitude: 100.728,
    accuracy: 20,
    capturedAt: DateTime.utc(2026, 1, 1),
  );
  Completer<SosLocation> pending = Completer<SosLocation>();
  int captures = 0;
  @override
  Future<SosLocation?> lastKnown() async => saved;
  @override
  Future<SosLocation> capture() {
    captures++;
    return pending.future;
  }
}

void main() {
  testWidgets('map waits for the shared permission flow before reading GPS', (
    tester,
  ) async {
    await tester.runAsync(OfflineMapData.load);
    final nearby = _Nearby()..pendingStart = Completer<void>();
    final messages = _Messages(nearby);
    final location = _Location();
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyTestScreen(
          nearbyService: nearby,
          messageService: messages,
          locationService: location,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(location.captures, 0);
    nearby.pendingStart!.complete();
    await tester.pump();
    await tester.pump();
    expect(location.captures, 1);
    location.pending.complete(location.saved!);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('denied map permission does not automatically ask again', (
    tester,
  ) async {
    final nearby = _Nearby();
    final messages = _Messages(nearby);
    await tester.runAsync(OfflineMapData.load);
    final location = _Location()..allowed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyTestScreen(
          nearbyService: nearby,
          messageService: messages,
          locationService: location,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(location.captures, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(location.captures, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final inside in [true, false]) {
    testWidgets('home hides map until GPS; in-area=$inside', (tester) async {
      await tester.runAsync(OfflineMapData.load);
      final nearby = _Nearby();
      final messages = _Messages(nearby);
      final location = _Location()..saved = null;
      await tester.pumpWidget(
        MaterialApp(
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
            locationService: location,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final viewport = find.byKey(const ValueKey('home-map-viewport'));
      final action = find.byKey(const ValueKey('home-location-action'));
      final initialButtonPosition = tester.getTopLeft(action);
      expect(tester.getSize(viewport).height, 320);
      expect(location.captures, 1);
      expect(find.byType(BundledOfflineMap), findsNothing);
      expect(find.text('กำลังค้นหาตำแหน่งของคุณ'), findsNothing);
      expect(find.text('ยังไม่มีตำแหน่งของคุณ'), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('กำลังค้นหาตำแหน่งของคุณ'), findsOneWidget);
      expect(tester.getTopLeft(action), initialButtonPosition);
      expect(find.byTooltip('ซูมเข้า'), findsNothing);
      location.pending.completeError(StateError('GPS ปิดอยู่'));
      await tester.pumpAndSettle();
      expect(find.text('ยังไม่มีตำแหน่งของคุณ'), findsOneWidget);
      expect(tester.getSize(viewport).height, 320);
      expect(tester.getTopLeft(action), initialButtonPosition);
      expect(find.byType(BundledOfflineMap), findsNothing);
      location.pending = Completer<SosLocation>();
      final retry = find.text('ลองอัปเดตตำแหน่งอีกครั้ง');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pump();
      final fix = SosLocation(
        latitude: inside ? 14.036 : 13.75,
        longitude: inside ? 100.728 : 100.5,
        accuracy: 8,
        capturedAt: DateTime.now().toUtc(),
      );
      location.pending.complete(fix);
      await tester.pump();
      expect(tester.getSize(viewport).height, 320);
      if (inside) {
        final map = find.byKey(const ValueKey('full-home-map'));
        expect(map, findsOneWidget);
        expect(tester.widget<BundledOfflineMap>(map).focus, same(fix));
        final marker = find.byKey(const ValueKey('map-marker-self'));
        expect(marker, findsOneWidget);
        expect(
          (tester.getCenter(marker) - tester.getCenter(map)).distance,
          lessThan(1),
        );
        expect(find.byTooltip('ซูมเข้า'), findsOneWidget);
      } else {
        expect(find.byType(BundledOfflineMap), findsNothing);
        expect(find.text('ตำแหน่งของคุณอยู่นอกพื้นที่แผนที่'), findsOneWidget);
        expect(
          tester
              .widget<MyLocationSummary>(find.byType(MyLocationSummary))
              .location,
          same(fix),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
    'cache remains visible while refreshing; resumes throttle and do not overlap; failure can retry',
    (tester) async {
      await tester.runAsync(OfflineMapData.load);
      final nearby = _Nearby();
      final messages = _Messages(nearby);
      final location = _Location();
      var now = DateTime.utc(2026, 10, 30);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
            locationService: location,
            now: () => now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final map = find.byKey(const ValueKey('full-home-map'));
      final mapViewer = find.descendant(
        of: map,
        matching: find.byType(InteractiveViewer),
      );
      final originalController = tester
          .widget<InteractiveViewer>(mapViewer)
          .transformationController;
      SosLocation? shown() => tester
          .widget<MyLocationSummary>(find.byType(MyLocationSummary))
          .location;
      void resume() {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }

      expect(shown(), same(location.saved));
      expect(location.captures, 1);
      now = now.add(const Duration(minutes: 2));
      resume();
      await tester.pump();
      expect(location.captures, 1); // A pending GPS read is reused.
      final fresh = SosLocation(
        latitude: 14.04,
        longitude: 100.73,
        accuracy: 5,
        capturedAt: now,
      );
      location.pending.complete(fresh);
      await tester.pumpAndSettle();
      expect(shown(), same(fresh));
      expect(
        tester.widget<InteractiveViewer>(mapViewer).transformationController,
        same(originalController),
      );
      location.pending = Completer<SosLocation>();
      resume();
      await tester.pump();
      expect(location.captures, 2);
      location.pending.completeError(StateError('กรุณาเปิดบริการตำแหน่ง/GPS'));
      await tester.pumpAndSettle();
      expect(shown(), same(fresh));
      expect(find.text('กรุณาเปิดบริการตำแหน่ง/GPS'), findsOneWidget);
      resume();
      await tester.pumpAndSettle();
      expect(location.captures, 2);
      location.pending = Completer<SosLocation>();
      final retry = find.text('ลองอัปเดตตำแหน่งอีกครั้ง');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pump();
      expect(
        location.captures,
        3,
      ); // Explicit retry bypasses the resume cooldown.
      location.pending.complete(fresh);
      await tester.pumpAndSettle();
      expect(find.text('กรุณาเปิดบริการตำแหน่ง/GPS'), findsNothing);
      expect(
        messages.rescueLocation,
        isNull,
      ); // Reading does not enable sharing.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
