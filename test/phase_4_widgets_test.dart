import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/widgets/location_button.dart';
import 'package:rescuelink/widgets/presence_list.dart';
import 'sos_screen_test.dart' show UiMessages;

class ReachableMessages extends UiMessages {
  bool reachable = false;
  @override
  bool isReachable(String peerId) => reachable;
}

class SelectivelyReachableMessages extends UiMessages {
  final reachablePeers = <String>{};
  @override
  bool isReachable(String peerId) => reachablePeers.contains(peerId);
}

void main() {
  for (final excluded in [PresenceFilter.rescue, PresenceFilter.sos]) {
    testWidgets('nearby excludes $excluded and unreachable peers', (
      tester,
    ) async {
      final service = SelectivelyReachableMessages();
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      final now = DateTime.now().toUtc();
      for (final id in [
        'helper',
        'sos',
        'both',
        'ordinary',
        'offline',
        'stale',
        'me',
      ]) {
        service.peers[id] = 'Person $id';
        service.presence[id] = PeerPresence(
          sequence: 1,
          rescue: id == 'helper' || id == 'both' || id == 'stale',
          receivedAt: id == 'stale'
              ? now.subtract(const Duration(minutes: 1))
              : now,
          sos: id == 'sos' || id == 'both'
              ? SosAlert(
                  incidentId: id,
                  revision: 1,
                  active: true,
                  name: id,
                  people: 1,
                  category: EmergencyType.other,
                  details: '',
                  updatedAt: now,
                )
              : null,
        );
      }
      service.myId = 'me';
      service.reachablePeers.addAll([
        'helper',
        'sos',
        'both',
        'ordinary',
        'stale',
        'me',
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PresenceList(
                service: service,
                excludeFilter: excluded,
                reachableOnly: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('คนรอบตัวคุณ'), findsOneWidget);
      expect(find.text('Person ordinary'), findsOneWidget);
      expect(find.text('Person stale'), findsOneWidget);
      expect(find.text('Person offline'), findsNothing);
      expect(find.text('Person me'), findsNothing);
      expect(
        find.text('Person helper'),
        excluded == PresenceFilter.rescue ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Person sos'),
        excluded == PresenceFilter.sos ? findsNothing : findsOneWidget,
      );
      // An active SOS takes precedence over a simultaneous rescue flag.
      expect(
        find.text('Person both'),
        excluded == PresenceFilter.sos ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(excluded == PresenceFilter.rescue ? '4 รายชื่อ' : '3 รายชื่อ'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('live directory hides stale people and opens reachable chat', (
    tester,
  ) async {
    final service = ReachableMessages();
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    final now = DateTime.now().toUtc();
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PresenceList(key: UniqueKey(), service: service),
          ),
        ),
      ),
    );
    service.presence['peer'] = PeerPresence(
      sequence: 1,
      rescue: false,
      receivedAt: now,
      sos: SosAlert(
        incidentId: 'sos',
        revision: 1,
        active: true,
        name: 'B',
        people: 1,
        category: EmergencyType.other,
        details: 'ช่วยด้วย',
        updatedAt: now,
      ),
    );
    await show();
    expect(find.text('ต้องการความช่วยเหลือ'), findsOneWidget);
    service.presence['peer'] = PeerPresence(
      sequence: 2,
      rescue: true,
      receivedAt: now,
    );
    await show();
    expect(find.text('พร้อมช่วยเหลือ'), findsOneWidget);
    service.presence['peer'] = PeerPresence(
      sequence: 3,
      rescue: true,
      receivedAt: now.subtract(const Duration(seconds: 31)),
    );
    await show();
    expect(find.text('Phone B'), findsNothing);
    service.reachable = true;
    await show();
    expect(find.text('รออัปเดตสถานะ'), findsOneWidget);
    await tester.tap(find.byTooltip('ส่งข้อความ'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets(
    'SOS requester sees helper names without their cancelled SOS history',
    (tester) async {
      final service = ReachableMessages()..reachable = true;
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      final now = DateTime.now().toUtc();
      service.presence['peer'] = PeerPresence(
        sequence: 2,
        rescue: true,
        receivedAt: now,
        sos: SosAlert(
          incidentId: 'old',
          revision: 2,
          active: false,
          name: 'B',
          people: 3,
          category: EmergencyType.other,
          details: 'ประวัติ SOS ของผู้ช่วย',
          updatedAt: now,
        ),
      );
      service.presence['other'] = PeerPresence(
        sequence: 1,
        rescue: false,
        receivedAt: now,
        sos: SosAlert(
          incidentId: 'active',
          revision: 1,
          active: true,
          name: 'C',
          people: 1,
          category: EmergencyType.other,
          details: 'SOS ของคนอื่น',
          updatedAt: now,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PresenceList(
                service: service,
                filter: PresenceFilter.rescue,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Phone B'), findsOneWidget);
      expect(find.text('Phone C'), findsNothing);
      expect(find.textContaining('ประวัติ SOS'), findsNothing);
      expect(find.text('รายละเอียด SOS'), findsNothing);
      await tester.tap(find.byTooltip('ส่งข้อความ'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'map sends exact coordinates and handles missing map application',
    (tester) async {
      const channel = MethodChannel('com.rmutt.rescuelink/maps');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocationButton(
                location: SosLocation(
                  latitude: 14.123,
                  longitude: 100.456,
                  accuracy: 15,
                  capturedAt: DateTime.now(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.text('เปิดในแอปแผนที่ (ต้องมีเน็ตหรือแผนที่ที่ดาวน์โหลดไว้)'),
      );
      await tester.tap(
        find.text('เปิดในแอปแผนที่ (ต้องมีเน็ตหรือแผนที่ที่ดาวน์โหลดไว้)'),
      );
      await tester.pumpAndSettle();
      expect(captured!.method, 'open');
      expect(captured!.arguments, {'latitude': 14.123, 'longitude': 100.456});
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await tester.ensureVisible(
        find.text('เปิดในแอปแผนที่ (ต้องมีเน็ตหรือแผนที่ที่ดาวน์โหลดไว้)'),
      );
      await tester.tap(
        find.text('เปิดในแอปแผนที่ (ต้องมีเน็ตหรือแผนที่ที่ดาวน์โหลดไว้)'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('เปิดแผนที่ไม่ได้'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
