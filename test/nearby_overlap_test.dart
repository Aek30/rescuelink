import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:rescuelink/models/offline_map_data.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/nearby_test_screen.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/widgets/presence_list.dart';
import 'package:rescuelink/widgets/my_location_summary.dart';
import 'package:rescuelink/widgets/bundled_offline_map.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Native extends Fake implements Nearby {}

class _Nearby extends NearbyService {
  _Nearby() : super(nearby: _Native()) {
    permissions.statuses.updateAll((_, _) => 'Granted');
  }
  @override
  Future<void> startNearby() async {
    isAdvertising = isDiscovering = true;
    notifyListeners();
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
    rescueMode = true;
    final now = DateTime.now().toUtc();
    rescueLocation = SosLocation(
      latitude: 14.036,
      longitude: 100.728,
      accuracy: 20,
      capturedAt: now,
    );
    peers = {'sos': 'ผู้ขอความช่วยเหลือชื่อยาว', 'friend': 'เพื่อนใกล้เคียง'};
    presence['sos'] = PeerPresence(
      sequence: 1,
      rescue: false,
      receivedAt: now.subtract(const Duration(minutes: 2)),
      sos: SosAlert(
        incidentId: 'help',
        revision: 1,
        active: true,
        name: peers['sos']!,
        people: 4,
        category: EmergencyType.flood,
        details: 'มีผู้สูงอายุติดอยู่ชั้นสอง',
        updatedAt: now,
      ),
    );
    presence['friend'] = PeerPresence(
      sequence: 1,
      rescue: false,
      receivedAt: now,
    );
  }
  @override
  Future<void> initialize() async {}
  @override
  bool isReachable(String peerId) => reachable.contains(peerId);
  final reachable = <String>{'friend'};
}

void main() {
  testWidgets('map follows reachable peers and current SOS/rescue roles', (
    tester,
  ) async {
    await tester.runAsync(OfflineMapData.load);
    final nearby = _Nearby();
    final messages = _Messages(nearby)..reachable.add('sos');
    final now = DateTime.now().toUtc();
    final sosLocation = SosLocation(
      latitude: 14.036,
      longitude: 100.728,
      accuracy: 10,
      capturedAt: now,
    );
    final rescueLocation = SosLocation(
      latitude: 14.04,
      longitude: 100.73,
      accuracy: 10,
      capturedAt: now,
    );
    void update({required bool rescue, required bool active}) {
      messages.presence['sos'] = PeerPresence(
        sequence: 2,
        rescue: rescue,
        receivedAt: now.subtract(const Duration(minutes: 2)),
        rescueLocation: rescueLocation,
        sos: SosAlert(
          incidentId: 'help',
          revision: 2,
          active: active,
          name: 'ผู้ขอความช่วยเหลือ',
          people: 1,
          category: EmergencyType.flood,
          details: '',
          updatedAt: now,
          location: sosLocation,
        ),
      );
      messages.notifyListeners();
    }

    update(rescue: true, active: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
        home: NearbyTestScreen(nearbyService: nearby, messageService: messages),
      ),
    );
    await tester.pumpAndSettle();
    OfflineMapMarker marker() => tester
        .widget<BundledOfflineMap>(find.byKey(const ValueKey('full-home-map')))
        .markers
        .singleWhere((m) => m.id == 'sos');
    expect(marker().color, kSosRed);
    expect(marker().location.latitude, sosLocation.latitude);
    OfflineMapMarker selfMarker() => tester
        .widget<BundledOfflineMap>(find.byKey(const ValueKey('full-home-map')))
        .markers
        .singleWhere((m) => m.id == 'self');
    expect(selfMarker().color, RescueTheme.rescue);
    expect(selfMarker().isMe, isTrue);
    messages.mySos = SosAlert(
      incidentId: 'own',
      revision: 1,
      active: true,
      name: 'ฉัน',
      people: 1,
      category: EmergencyType.other,
      details: '',
      updatedAt: now,
      location: sosLocation,
    );
    messages.notifyListeners();
    await tester.pumpAndSettle();
    expect(selfMarker().color, kSosRed);
    messages.mySos = null;
    messages.rescueMode = false;
    messages.notifyListeners();
    await tester.pumpAndSettle();
    expect(selfMarker().color, const Color(0xFF167A65));
    messages.rescueMode = true;
    messages.notifyListeners();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('nearby-home-scroll')),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('มีพิกัด'), findsNothing);
    expect(find.text('ออฟไลน์/ปิดแล้ว'), findsNothing);
    expect(find.text('ผู้ใช้ทั่วไป'), findsWidgets);
    update(rescue: true, active: false);
    await tester.pumpAndSettle();
    expect(marker().color, RescueTheme.rescue);
    expect(marker().location.latitude, rescueLocation.latitude);
    update(rescue: false, active: false);
    await tester.pumpAndSettle();
    expect(marker().color, Colors.grey);
    messages.reachable.remove('sos');
    messages.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('presence-peer-sos')), findsNothing);
    expect(find.text('ออฟไลน์ • ข้อมูลเก่า'), findsNothing);
    expect(
      tester
          .widget<BundledOfflineMap>(
            find.byKey(const ValueKey('full-home-map')),
          )
          .markers
          .where((m) => m.id == 'sos'),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home shows directory and map without overlapping cards', (
    tester,
  ) async {
    await tester.runAsync(OfflineMapData.load);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await (FontLoader(
      'NotoSansThai',
    )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final dark in [false, true]) {
      for (final narrow in [false, true]) {
        tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
        final nearby = _Nearby();
        final messages = _Messages(nearby)..reachable.add('sos');
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? RescueTheme.dark : RescueTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundary,
              child: NearbyTestScreen(
                nearbyService: nearby,
                messageService: messages,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = find.byKey(const ValueKey('nearby-home-scroll'));
        final scrollable = find
            .descendant(of: scroll, matching: find.byType(Scrollable))
            .first;
        await tester.scrollUntilVisible(
          find.text('คนที่ต้องการความช่วยเหลือ'),
          240,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final card = find.byKey(const ValueKey('presence-peer-sos'));
        expect(card, findsOneWidget);
        expect(find.text('รอเชื่อมต่อ'), findsNothing);
        final nameRect = tester.getRect(find.text('ผู้ขอความช่วยเหลือชื่อยาว'));
        final connectionRect = tester.getRect(
          find.descendant(of: card, matching: find.text('เชื่อมต่อโดยตรง')),
        );
        expect(nameRect.overlaps(connectionRect), isFalse);
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        expect(
          find.byKey(const ValueKey('nearby-connection-hero')),
          findsNothing,
        );
        expect(find.byType(MyLocationSummary), findsOneWidget);
        if (!narrow && const bool.fromEnvironment('NEARBY_CAPTURE')) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 300)),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'output/nearby-overlap-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
          find.text('เพื่อนใกล้เคียง'),
          200,
          scrollable: scrollable,
        );
        expect(find.text('เพื่อนใกล้เคียง'), findsOneWidget);
        expect(
          tester.widgetList<PresenceList>(find.byType(PresenceList)).length,
          2,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    }
  });
}
