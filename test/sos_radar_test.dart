import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/widgets/sos_radar.dart';
import 'sos_screen_test.dart' show UiMessages;

void main() {
  test('distance uses coordinates in metres', () {
    SosLocation point(double lat) => SosLocation(
      latitude: lat,
      longitude: 0,
      accuracy: 5,
      capturedAt: DateTime.now().toUtc(),
    );
    expect(sosDistance(point(0), point(0)), 0);
    expect(sosDistance(point(0), point(.001)), closeTo(111.2, .1));
  });
  testWidgets('filters range, keeps stale SOS and expires by incident age', (
    tester,
  ) async {
    final service = UiMessages();
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    final now = DateTime.now().toUtc();
    final origin = SosLocation(
      latitude: 0,
      longitude: 0,
      accuracy: 5,
      capturedAt: now,
    );
    service.presence = {
      'peer': PeerPresence(
        sequence: 1,
        rescue: false,
        receivedAt: now,
        sos: SosAlert(
          incidentId: 'one',
          revision: 1,
          active: true,
          name: 'ผู้ส่งทดสอบ',
          people: 1,
          category: EmergencyType.medical,
          details: '',
          updatedAt: now,
          location: SosLocation(
            latitude: .001,
            longitude: 0,
            accuracy: 5,
            capturedAt: now,
          ),
        ),
      ),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SosRadar(
              service: service,
              captureLocation: () async => origin,
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('ไม่ทราบระยะ 1 ราย • ไม่มีพิกัดหรือพิกัดเก่า'),
      findsOneWidget,
    );
    await tester.tap(find.text('อัปเดตตำแหน่งเพื่อคำนวณระยะ'));
    await tester.pumpAndSettle();
    expect(find.text('รายการ SOS ในรัศมี 1 ราย'), findsOneWidget);
    await tester.tap(find.text('100 ม.'));
    await tester.pumpAndSettle();
    expect(find.text('รายการ SOS ในรัศมี 0 ราย'), findsOneWidget);
    expect(find.text('ผู้ส่งทดสอบ'), findsNothing);
    service.presence['peer'] = PeerPresence(
      sequence: 2,
      rescue: false,
      receivedAt: now.subtract(const Duration(seconds: 31)),
      sos: service.presence['peer']!.sos,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('นอกระยะที่เลือก'), findsOneWidget);
    await tester.tap(find.text('200 ม.'));
    await tester.pumpAndSettle();
    expect(find.text('ผู้ส่งทดสอบ'), findsOneWidget);
    expect(
      find.text('สถานะการเชื่อมต่อเก่า • SOS ยังไม่หมดอายุ'),
      findsOneWidget,
    );
    final old = service.presence['peer']!.sos!;
    service.presence['peer'] = PeerPresence(
      sequence: 3,
      rescue: false,
      receivedAt: now,
      sos: SosAlert(
        incidentId: old.incidentId,
        revision: old.revision,
        active: true,
        name: old.name,
        people: old.people,
        category: old.category,
        details: old.details,
        location: old.location,
        updatedAt: now.subtract(const Duration(hours: 25)),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('นอกระยะที่เลือก'), findsNothing);
    expect(find.text('ผู้ส่งทดสอบ'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
