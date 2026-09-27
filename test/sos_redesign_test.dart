import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'sos_screen_test.dart' show UiMessages;

void main() {
  testWidgets('SOS mobile layout, large text and role navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('ui-preview/assets/NotoSansThai.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final service = UiMessages();
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansThai'),
        home: RepaintBoundary(
          key: boundaryKey,
          child: SosScreen(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('UX_CAPTURE')) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/ui-audit/sos-redesign.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('หน่วยกู้ภัย'));
    await tester.pumpAndSettle();
    expect(find.text('พร้อมเป็นคนช่วย'), findsOneWidget);
    // Navigating roles must not broadcast a Rescue state change.
    expect(service.rescueMode, isFalse);
    await tester.tap(find.text('ขอความช่วยเหลือ'));
    await tester.pumpAndSettle();
    final send = find.text('ตรวจข้อมูลและส่ง SOS');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('UX_CAPTURE')) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/ui-audit/sos-redesign-details.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSansThai'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: SosScreen(service: service),
      ),
    );
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ตรวจข้อมูลและส่ง SOS'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
