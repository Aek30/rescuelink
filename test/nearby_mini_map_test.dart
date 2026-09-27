import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/widgets/nearby_mini_map.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'sos_screen_test.dart' show UiMessages;

void main() {
  testWidgets(
    'map shows no invented location and reads local GPS only on request',
    (tester) async {
      final service = UiMessages();
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NearbyMiniMap(
                service: service,
                capture: () async {
                  calls++;
                  return SosLocation(
                    latitude: 13.75,
                    longitude: 100.5,
                    accuracy: 8,
                    capturedAt: DateTime.utc(2026),
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(calls, 0);
      expect(find.textContaining('ยังไม่มีพิกัด'), findsOneWidget);
      await tester.ensureVisible(find.text('ตำแหน่งของฉัน'));
      await tester.tap(find.text('ตำแหน่งของฉัน'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('13.75000, 100.50000'), findsOneWidget);
      expect(service.mySos, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
