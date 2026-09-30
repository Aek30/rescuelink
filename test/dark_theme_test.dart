import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'sos_screen_test.dart' show UiMessages;

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
}

void main() {
  testWidgets('SOS adapts live to dark theme with readable secondary text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'NotoSansThai',
    )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final service = UiMessages();
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    final capture = GlobalKey();
    Widget app(ThemeData theme) => MaterialApp(
      theme: theme,
      home: RepaintBoundary(
        key: capture,
        child: SosScreen(service: service),
      ),
    );
    await tester.pumpWidget(app(RescueTheme.light));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(RescueTheme.dark));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      RescueTheme.darkBackground,
    );
    final context = tester.element(find.byType(SosScreen));
    for (final background in [
      RescueTheme.darkBackground,
      RescueTheme.darkSurface,
      RescueTheme.darkSurfaceElevated,
    ]) {
      expect(
        contrast(RescueTheme.mutedFor(context), background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(RescueTheme.accentFor(context), background),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('UX_CAPTURE')) {
      await tester.runAsync(() async {
        final image =
            await (capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/ui-audit/sos-dark.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('หน่วยกู้ภัย'));
    await tester.pumpAndSettle();
    final subtitle = tester.widget<Text>(
      find.text('ติดตามคำขอและติดต่อผู้ที่ต้องการความช่วยเหลือ'),
    );
    expect(subtitle.style!.color, RescueTheme.darkTextMuted);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(RescueTheme.light));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      RescueTheme.cream,
    );
  });
}
