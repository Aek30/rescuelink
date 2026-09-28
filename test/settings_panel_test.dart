import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/settings_panel.dart';
import 'package:rescuelink/services/app_preferences.dart';

void main() {
  testWidgets('flat settings fit a small screen and open the real queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'NotoSansThai',
    )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    var queueOpened = false;
    final key = GlobalKey();
    Widget app() => MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansThai'),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: SettingsPanel(
            pending: 12,
            rescue: false,
            ready: false,
            onRescue: (_) {},
            onQueue: () => queueOpened = true,
            onDevice: () {},
            onConnection: () {},
            onExit: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Card), findsNothing);
    await tester.tap(find.text('คิวข้อความออฟไลน์'));
    expect(queueOpened, isTrue);
    if (const bool.fromEnvironment('UX_CAPTURE')) {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/ui-audit/settings-redesign.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    AppPreferences.instance.dark = true;
    AppPreferences.instance.english = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Dark mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
    AppPreferences.instance.dark = false;
    AppPreferences.instance.english = false;
  });
}
