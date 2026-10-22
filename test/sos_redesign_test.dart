import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'package:rescuelink/models/offline_map_data.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'sos_screen_test.dart' show UiMessages;

void main() {
  testWidgets('SOS mobile layout, large text and role navigation', (
    tester,
  ) async {
    await tester.runAsync(OfflineMapData.load);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'));
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
        theme: RescueTheme.light,
        home: RepaintBoundary(
          key: boundaryKey,
          child: SosScreen(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('น้ำท่วม'));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('UX_CAPTURE')) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/sos-ui/form.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(find.text('หน่วยกู้ภัย'), findsNothing);
    expect(service.rescueMode, isFalse);
    final send = find.text('ส่ง SOS');
    await tester.ensureVisible(find.text('จำนวนผู้ต้องการความช่วยเหลือ'));
    expect(tester.getCenter(send).dy, lessThan(844));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('UX_CAPTURE')) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'output/sos-ui/form-sticky.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
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
    await tester.ensureVisible(find.text('ส่ง SOS'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('active SOS shows receipt state, edit and cancel confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = UiMessages();
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    final alert = SosAlert(
      incidentId: 'active',
      revision: 1,
      active: true,
      name: 'สมชาย ใจดี',
      people: 3,
      category: EmergencyType.flood,
      categories: [EmergencyType.flood, EmergencyType.medical],
      details: 'ติดอยู่ชั้นสอง มีผู้สูงอายุ 1 คน',
      updatedAt: DateTime.now().toUtc(),
      location: SosLocation(
        latitude: 14.036,
        longitude: 100.728,
        accuracy: 20,
        capturedAt: DateTime.now().toUtc(),
      ),
    );
    service.mySos = alert;
    service.messages = [
      MessageModel(
        id: 'receipt',
        senderId: service.myId!,
        senderName: alert.name,
        receiverId: 'peer',
        text: alert.toJson(),
        timestamp: alert.updatedAt,
        type: MessageType.sos,
        status: MessageStatus.delivered,
      ),
    ];
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
        home: RepaintBoundary(
          key: key,
          child: SosScreen(service: service, mainTab: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('มีผู้รับแล้ว 1 เครื่อง'), findsOneWidget);
    expect(find.text('ส่งซ้ำ'), findsOneWidget);
    expect(find.text('เพิ่มข้อมูล / อัปเดต SOS'), findsOneWidget);
    if (const bool.fromEnvironment('UX_CAPTURE')) {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'output/sos-ui/status.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('ยกเลิก SOS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('จะแจ้งผู้รับเดิมว่ายกเลิก'), findsOneWidget);
    await tester.tap(find.text('กลับ'));
    await tester.pumpAndSettle();
    expect(service.mySos!.active, isTrue);
    expect(tester.takeException(), isNull);
  });
}
