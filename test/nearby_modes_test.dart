import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/nearby_test_screen.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/widgets/nearby_mini_map.dart';
import 'package:rescuelink/widgets/presence_list.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Native extends Fake implements Nearby {}

class _Nearby extends NearbyService {
  _Nearby() : super(nearby: _Native()) {
    permissions.statuses.updateAll((_, _) => 'Granted');
  }
  int searches = 0;
  Future<void>? pendingStart;
  @override
  Future<void> startNearby() async {
    searches++;
    final pending = pendingStart;
    pendingStart = null;
    await pending;
    isAdvertising = true;
    isDiscovering = true;
    notifyListeners();
  }

  @override
  Future<void> stopAll() async {}
}

class _Messages extends MessageService {
  _Messages({required super.nearbyService})
    : super(database: LocalDatabaseService(factory: databaseFactoryFfi)) {
    myId = 'me';
  }
  @override
  Future<void> initialize() async {}
  void mode({bool sos = false, bool rescue = false}) {
    rescueMode = rescue;
    mySos = sos
        ? SosAlert(
            incidentId: 'own',
            revision: 1,
            active: true,
            name: 'ฉัน',
            people: 1,
            category: EmergencyType.other,
            details: 'ขอความช่วยเหลือ',
            updatedAt: DateTime.now().toUtc(),
          )
        : null;
    notifyListeners();
  }

  @override
  Future<void> cancelSos() async => mode();
  @override
  Future<void> setRescueMode(bool value) async => mode(rescue: value);
}

void main() {
  testWidgets(
    'resume during permission work retries once; explicit stop stays stopped',
    (tester) async {
      final permission = Completer<void>();
      final nearby = _Nearby()..pendingStart = permission.future;
      final messages = _Messages(nearbyService: nearby);
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
          ),
        ),
      );
      await tester.pump();
      expect(nearby.searches, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      permission.complete();
      await tester.pumpAndSettle();
      expect(nearby.searches, 2);
      await tester.tap(find.text('หยุดการทำงานใกล้เคียง'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(nearby.searches, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final dark in [false, true]) {
    testWidgets('home changes priority using own mode, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nearby = _Nearby();
      final messages = _Messages(nearbyService: nearby);
      // A remote SOS must not turn this phone's hero into SOS mode.
      messages.presence['remote'] = PeerPresence(
        sequence: 1,
        rescue: false,
        receivedAt: DateTime.now().toUtc(),
        sos: SosAlert(
          incidentId: 'remote',
          revision: 1,
          active: true,
          name: 'อีกเครื่อง',
          people: 1,
          category: EmergencyType.other,
          details: 'Help',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? RescueTheme.dark : RescueTheme.light,
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(nearby.searches, 1);
      expect(find.text('SOS กำลังทำงาน'), findsNothing);
      List<Widget> sections() =>
          tester.widget<ListView>(find.byType(ListView).first).childrenDelegate
              is SliverChildListDelegate
          ? (tester
                        .widget<ListView>(find.byType(ListView).first)
                        .childrenDelegate
                    as SliverChildListDelegate)
                .children
          : [];
      int indexOf<T>() => sections().indexWhere((w) => w is T);
      expect(indexOf<NearbyMiniMap>(), lessThan(indexOf<PresenceList>()));
      messages.mode(sos: true);
      await tester.pumpAndSettle();
      expect(find.text('SOS กำลังทำงาน'), findsOneWidget);
      expect(indexOf<PresenceList>(), lessThan(indexOf<NearbyMiniMap>()));
      expect(
        (sections().whereType<PresenceList>().single).filter,
        PresenceFilter.rescue,
      );
      await tester.tap(find.text('ปิดโหมด SOS'));
      await tester.pumpAndSettle();
      expect(indexOf<NearbyMiniMap>(), lessThan(indexOf<PresenceList>()));
      messages.mode(rescue: true);
      await tester.pumpAndSettle();
      expect(find.text('โหมดหน่วยกู้ภัย'), findsOneWidget);
      expect(indexOf<PresenceList>(), lessThan(indexOf<NearbyMiniMap>()));
      expect(
        (sections().whereType<PresenceList>().single).filter,
        PresenceFilter.sos,
      );
      await tester.tap(find.text('ปิดโหมดหน่วยกู้ภัย'));
      await tester.pumpAndSettle();
      expect(indexOf<NearbyMiniMap>(), lessThan(indexOf<PresenceList>()));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
