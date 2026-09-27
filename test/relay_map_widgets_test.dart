import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/widgets/relay_badge.dart';
import 'package:rescuelink/widgets/offline_location_map.dart';
import 'package:rescuelink/models/sos_alert.dart';

void main() {
  testWidgets('relay separates intermediary devices from radio hops', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RelayBadge(
            route: ['a', 'b', 'c', 'd'],
            peers: {'b': 'Rescue B'},
          ),
        ),
      ),
    );
    expect(find.text('ผ่าน 2 เครื่อง · 3 hops'), findsOneWidget);
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(find.text('Rescue B'), findsOneWidget);
    expect(find.textContaining('เส้นทางแรกที่ได้รับ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown route never invents a relay count', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RelayBadge(route: null, peers: {})),
      ),
    );
    expect(find.text('ยังไม่ทราบเส้นทาง'), findsOneWidget);
  });
  testWidgets('offline coordinate diagram is readable on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OfflineLocationMap(
              location: SosLocation(
                latitude: 13.7563,
                longitude: 100.5018,
                accuracy: 12,
                capturedAt: DateTime.utc(2026),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('13.756300, 100.501800'), findsOneWidget);
    expect(find.textContaining('ไม่มีข้อมูลถนน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
