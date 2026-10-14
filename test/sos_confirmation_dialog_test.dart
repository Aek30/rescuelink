import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/widgets/sos_confirmation_dialog.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'SOS review scrolls with large text and returns edit or confirm, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await (FontLoader(
          'NotoSansThai',
        )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        bool? result;
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? RescueTheme.dark : RescueTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () async {
                        result = await showDialog<bool>(
                          context: context,
                          builder: (_) => SosConfirmationDialog(
                            name: 'สมชาย ใจดี',
                            people: '3',
                            category: 'น้ำท่วม',
                            details: List.filled(
                              20,
                              'ติดอยู่บนชั้นสอง ต้องการความช่วยเหลือ',
                            ).join(' '),
                            location: 'ส่งโดยไม่แนบพิกัด',
                            recipients: const [
                              'ทีมกู้ภัยในพื้นที่',
                              'ผู้ติดต่อฉุกเฉิน',
                            ],
                            translate: (key) => key,
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('ยืนยันข้อมูล SOS'), findsOneWidget);
        expect(result, isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('กลับไปแก้ไข'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ยืนยันส่ง SOS'));
        await tester.pumpAndSettle();
        expect(result, isTrue);

        // Capture a realistic phone preview of the same dialog when requested.
        if (const bool.fromEnvironment('UX_CAPTURE')) {
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? RescueTheme.dark : RescueTheme.light,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => SosConfirmationDialog(
                          name: 'สมชาย ใจดี',
                          people: '3',
                          category: 'น้ำท่วม',
                          details:
                              'ติดอยู่ชั้นสอง มีผู้สูงอายุ 1 คน ต้องการเรือรับส่ง',
                          location: 'ส่งโดยไม่แนบพิกัด',
                          recipients: const [],
                          translate: (key) => key,
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'output/sos-confirmation-${dark ? 'dark' : 'light'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
