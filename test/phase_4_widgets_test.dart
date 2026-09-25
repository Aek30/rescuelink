import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/widgets/location_button.dart';
import 'package:rescuelink/widgets/presence_list.dart';
import 'sos_screen_test.dart' show UiMessages;

void main() {
  testWidgets(
    'presence uses red SOS, blue rescue, grey expired and opens chat',
    (tester) async {
      final service = UiMessages();
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      final now = DateTime.now().toUtc();
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
          details: '',
          updatedAt: now,
        ),
      );
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PresenceList(key: UniqueKey(), service: service),
            ),
          ),
        ),
      );
      await show();
      expect(tester.widget<Icon>(find.byIcon(Icons.sos)).color, Colors.red);
      service.presence['peer'] = PeerPresence(
        sequence: 2,
        rescue: true,
        receivedAt: now,
      );
      await show();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.health_and_safety)).color,
        Colors.blue,
      );
      service.presence['peer'] = PeerPresence(
        sequence: 3,
        rescue: true,
        receivedAt: now.subtract(const Duration(seconds: 31)),
      );
      await show();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.health_and_safety)).color,
        Colors.grey,
      );
      expect(find.textContaining('สถานะหมดอายุ'), findsOneWidget);
      await tester.tap(find.text('Phone B'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
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
            body: LocationButton(
              location: SosLocation(
                latitude: 14.123,
                longitude: 100.456,
                accuracy: 15,
                capturedAt: DateTime.now(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('เปิดตำแหน่งบนแผนที่'));
      await tester.pumpAndSettle();
      expect(captured!.method, 'open');
      expect(captured!.arguments, {'latitude': 14.123, 'longitude': 100.456});
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await tester.tap(find.text('เปิดตำแหน่งบนแผนที่'));
      await tester.pumpAndSettle();
      expect(find.textContaining('เปิดแผนที่ไม่ได้'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
