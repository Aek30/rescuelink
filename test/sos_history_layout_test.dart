import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/my_sos_screen.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'my_sos_screen_test.dart' show UiStore;

void main() {
  testWidgets('history fits narrow screens and large text in both themes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await (FontLoader(
      'NotoSansThai',
    )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final store = UiStore();
    final now = DateTime.now().toUtc();
    store.records = [
      for (var i = 0; i < 3; i++)
        SosRecord.fromMap({
          'payload': SosAlert(
            incidentId: 'history-$i',
            revision: 1,
            active: i != 0,
            name: 'สมชาย ใจดี',
            people: 3,
            category: EmergencyType.flood,
            categories: [EmergencyType.flood, EmergencyType.medical],
            details: 'ติดอยู่ชั้นสอง มีผู้สูงอายุ 1 คน ต้องการความช่วยเหลือ',
            updatedAt: now.subtract(i == 1 ? const Duration(hours: 1) : Duration(days: i)),
            location: SosLocation(
              latitude: 14.036,
              longitude: 100.728,
              accuracy: 20,
              capturedAt: now,
            ),
          ).toJson(),
          'version': 1,
          'deleted': 0,
        }),
    ];
    for (final dark in [false, true]) {
      for (final narrow in [false, true]) {
        tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
        final key = GlobalKey();
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
              key: key,
              child: MySosScreen(store: store, onCreate: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('ทั้งหมด 3 เหตุ'), findsOneWidget);
        if (!narrow && const bool.fromEnvironment('UX_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'output/sos-history-${dark ? 'dark' : 'light'}.png',
            );
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
          find.text('หมดอายุ'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
