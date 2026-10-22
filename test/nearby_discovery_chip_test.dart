import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/widgets/nearby_discovery_chip.dart';

void main() {
  testWidgets('stopping requires confirmation; cancel preserves discovery', (
    tester,
  ) async {
    var stops = 0;
    var settings = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NearbyDiscoveryChip(
      active: true,
      busy: false,
      onStart: () {},
      onStop: () => stops++,
      onSettings: () => settings++,
    ))));
    Future<void> openStop() async {
      await tester.tap(find.text('กำลังค้นหา •'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('หยุดการค้นหา'));
      await tester.pumpAndSettle();
    }
    await openStop();
    expect(stops, 0);
    expect(find.textContaining('คุณจะไม่เห็นและไม่ถูกเห็น'), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(stops, 0);
    await openStop();
    await tester.tap(find.widgetWithText(FilledButton, 'หยุดการค้นหา'));
    await tester.pumpAndSettle();
    expect(stops, 1);
    await tester.tap(find.text('กำลังค้นหา •'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('การเชื่อมต่อและสิทธิ์'));
    await tester.pumpAndSettle();
    expect(settings, 1);
  });

  testWidgets('stopped discovery can restart; busy controls cannot open', (
    tester,
  ) async {
    var starts = 0;
    Widget app(bool busy) => MaterialApp(home: Scaffold(body: NearbyDiscoveryChip(
      active: false,
      busy: busy,
      onStart: () => starts++,
      onStop: () {},
      onSettings: () {},
    )));
    await tester.pumpWidget(app(false));
    await tester.tap(find.text('หยุดค้นหาแล้ว •'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เริ่มค้นหา'));
    await tester.pumpAndSettle();
    expect(starts, 1);
    await tester.pumpWidget(app(true));
    await tester.tap(find.text('กำลังดำเนินการ •'));
    await tester.pumpAndSettle();
    expect(find.text('เริ่มค้นหา'), findsNothing);
  });
}
