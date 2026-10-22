import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'package:rescuelink/widgets/sos_status_card.dart';

import 'sos_screen_test.dart' show UiMessages;

class LifecycleMessages extends UiMessages {
  LifecycleMessages()
    : super(
        cachedLocation: SosLocation(
          latitude: 14.036,
          longitude: 100.728,
          accuracy: 20,
          capturedAt: DateTime.now().toUtc(),
        ),
      );

  void update(SosAlert alert) {
    mySos = alert;
    notifyListeners();
  }
}

SosAlert incident({bool active = true, DateTime? updatedAt}) => SosAlert(
  incidentId: 'previous-incident',
  revision: 1,
  active: active,
  name: 'ผู้แจ้ง',
  people: 4,
  category: EmergencyType.flood,
  details: 'รายละเอียดเหตุเดิม',
  updatedAt: updatedAt ?? DateTime.now().toUtc(),
);

void expectNewForm(WidgetTester tester) {
  expect(find.byType(SosStatusCard), findsNothing);
  expect(find.text('ส่ง SOS'), findsOneWidget);
  expect(find.text('ส่งซ้ำ'), findsNothing);
  expect(find.text('1 คน'), findsOneWidget);
  expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  final send = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'ส่ง SOS'),
  );
  expect(send.onPressed, isNull); // A new incident requires a fresh category.
  expect(find.byTooltip('รายการเหตุ SOS ของฉัน'), findsOneWidget);
}

void main() {
  testWidgets(
    'active SOS actions stay below scrolling content and confirm cancellation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = LifecycleMessages()..mySos = incident();
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      await tester.pumpWidget(MaterialApp(home: SosScreen(service: service)));
      await tester.pumpAndSettle();
      final retry = find.widgetWithText(FilledButton, 'ส่งซ้ำ');
      final edit = find.widgetWithText(
        OutlinedButton,
        'เพิ่มข้อมูล / อัปเดต SOS',
      );
      final cancel = find.widgetWithText(OutlinedButton, 'ยกเลิก SOS');
      expect(find.text('ส่ง SOS แล้ว'), findsOneWidget);
      expect(find.text('บันทึกแล้ว'), findsNothing);
      expect(find.textContaining('P2P'), findsNothing);
      expect(find.textContaining('ผู้รับยืนยัน'), findsNothing);
      expect(
        tester.getBottomLeft(retry).dy,
        lessThan(tester.getTopLeft(edit).dy),
      );
      expect(
        tester.getBottomLeft(edit).dy,
        lessThan(tester.getTopLeft(cancel).dy),
      );
      expect(
        find.ancestor(of: cancel, matching: find.byType(SafeArea)),
        findsOneWidget,
      );
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(cancel, findsNothing);
      final update = find.widgetWithText(FilledButton, 'อัปเดต SOS');
      final updateTop = tester.getTopLeft(update).dy;
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(update).dy, closeTo(updateTop, 1));
      expect(cancel, findsNothing);
      await tester.tap(find.text('กลับไปหน้าสถานะ'));
      await tester.pumpAndSettle();
      expect(cancel, findsOneWidget);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('ยกเลิก SOS?'), findsOneWidget);
      expect(service.mySos!.active, isTrue);
      await tester.tap(find.text('กลับ'));
      await tester.pumpAndSettle();
      expect(service.mySos!.active, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final expired in [false, true]) {
    testWidgets(
      'opening ${expired ? 'expired' : 'cancelled'} SOS starts a new form',
      (tester) async {
        final service = LifecycleMessages()
          ..mySos = incident(
            active: expired,
            updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
          );
        addTearDown(() {
          service.dispose();
          service.nearbyService.dispose();
        });
        await tester.pumpWidget(MaterialApp(home: SosScreen(service: service)));
        await tester.pumpAndSettle();
        expectNewForm(tester);
        expect(service.mySos!.details, 'รายละเอียดเหตุเดิม');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('ending an SOS resets its edit form and retains the incident', (
    tester,
  ) async {
    final service = LifecycleMessages()..mySos = incident();
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    await tester.pumpWidget(MaterialApp(home: SosScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.byType(SosStatusCard), findsOneWidget);
    await tester.tap(find.text('เพิ่มข้อมูล / อัปเดต SOS'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'รายละเอียดเหตุเดิม',
    );
    service.update(incident(active: false));
    await tester.pumpAndSettle();
    expectNewForm(tester);
    expect(service.mySos!.incidentId, 'previous-incident');
    expect(service.mySos!.active, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SOS expires while the page stays open without service updates', (
    tester,
  ) async {
    final service = LifecycleMessages()
      ..mySos = incident(
        updatedAt: DateTime.now().toUtc().subtract(
          SosAlert.lifetime - const Duration(seconds: 1),
        ),
      );
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    await tester.pumpWidget(MaterialApp(home: SosScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.byType(SosStatusCard), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expectNewForm(tester);
    expect(service.mySos, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
