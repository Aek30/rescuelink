import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/screens/my_sos_screen.dart';
import 'package:rescuelink/screens/sync_screen.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'package:rescuelink/services/sos_sync_service.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/theme/rescue_theme.dart';

class UiStore extends SosStore {
  UiStore() : super(LocalDatabaseService(factory: databaseFactoryFfi));
  List<SosRecord> records = [
    SosRecord.fromMap({
      'payload': SosAlert(
        incidentId: 'demo',
        revision: 1,
        active: false,
        name: 'ผู้ทดสอบ',
        people: 2,
        category: EmergencyType.medical,
        details: 'ได้รับความช่วยเหลือแล้ว',
        updatedAt: DateTime.utc(2026, 9, 29, 8),
      ).toJson(),
      'version': 1,
      'deleted': 0,
    }),
  ];
  @override
  Future<List<SosRecord>> list({bool includeDeleted = false}) async => records;
  @override
  Future<List<Map<String, Object?>>> queue() async => [];
  @override
  Future<void> editClosed(SosAlert alert, {bool delete = false}) async {
    records = delete
        ? []
        : [
            SosRecord.fromMap({
              'payload': alert.toJson(),
              'version': 2,
              'deleted': 0,
            }),
          ];
  }
}

void main() {
  testWidgets('history edit/delete and responsive SOS and Sync screens', (
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
    final store = UiStore();
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('UX_CAPTURE')) return;
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/ui-audit/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
        home: RepaintBoundary(
          key: boundary,
          child: MySosScreen(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ได้รับความช่วยเหลือแล้ว'), findsOneWidget);
    await capture('phase3-history');
    await tester.tap(find.byTooltip('แก้ไขเหตุ'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'แก้ไขรายละเอียดแล้ว',
    );
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('แก้ไขรายละเอียดแล้ว'), findsOneWidget);
    await tester.tap(find.byTooltip('ลบเหตุ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีเหตุ SOS'), findsOneWidget);
    final sync = SosSyncService(store, null);
    addTearDown(sync.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.dark,
        home: RepaintBoundary(
          key: boundary,
          child: SyncScreen(service: sync),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture('phase3-sync');
    for (final size in [const Size(320, 640), const Size(1100, 800)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
