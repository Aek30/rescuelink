import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/offline_map_data.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/widgets/bundled_offline_map.dart';
import 'package:rescuelink/widgets/sos_status_card.dart';
import 'sos_screen_test.dart' show UiMessages;

SosAlert alert({List<EmergencyType>? categories, bool active = true}) =>
    SosAlert(
      incidentId: 'sos',
      revision: 1,
      active: active,
      name: 'สมใจ',
      people: 2,
      category: EmergencyType.medical,
      categories: categories,
      details: 'รอที่ชั้นสอง',
      updatedAt: DateTime.now().toUtc(),
    );

void main() {
  test(
    'typed categories round trip independently of notes and retain legacy wire category',
    () {
      final original = alert(
        categories: [
          EmergencyType.flood,
          EmergencyType.fire,
          EmergencyType.other,
        ],
      );
      final wire = jsonDecode(original.toJson()) as Map<String, dynamic>;
      expect(
        wire['category'],
        'other',
      ); // Accepted by existing server and older clients.
      expect(wire['categories'], ['flood', 'fire']);
      final restored = SosAlert.fromJson(original.toJson());
      expect(restored.categories, [EmergencyType.flood, EmergencyType.fire]);
      expect(restored.details, 'รอที่ชั้นสอง');
      expect(restored.categoriesLabel, isNot(contains('เหตุฉุกเฉินอื่น')));
      expect(
        () => restored.categories.add(EmergencyType.accident),
        throwsUnsupportedError,
      );
      final legacy = alert();
      expect(jsonDecode(legacy.toJson()), isNot(contains('categories')));
      expect(SosAlert.fromJson(legacy.toJson()).categories, [
        EmergencyType.medical,
      ]);
      expect(() => alert(categories: []), throwsFormatException);
    },
  );

  testWidgets(
    'selection, reviewed multi-type payload and sticky send survive scrolling and keyboard',
    (tester) async {
      await tester.runAsync(OfflineMapData.load);
      final service = UiMessages();
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          home: SosScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      await tester.tap(find.text('น้ำท่วม'));
      await tester.tap(find.text('ไฟไหม้'));
      final details = find.byType(TextField);
      await tester.ensureVisible(details);
      await tester.enterText(details, 'มีผู้สูงอายุ');
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final send = find.text('ส่ง SOS');
      expect(
        tester.getBottomRight(send).dy,
        lessThan(tester.view.physicalSize.height - 250),
      );
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(service.sentCategories, isNull);
      await tester.tap(find.text('ยืนยันส่ง SOS'));
      await tester.pumpAndSettle();
      expect(service.sentCategories, [EmergencyType.flood, EmergencyType.fire]);
      expect(service.sentDetails, 'มีผู้สูงอายุ');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cloud sync is not receipt proof; ACK survives cloud status; cancellation has a block icon',
    (tester) async {
      final message = MessageModel(
        id: 'm',
        senderId: 'a',
        senderName: 'a',
        receiverId: 'b',
        text: '',
        timestamp: DateTime.now(),
        status: MessageStatus.synced,
      );
      Future<void> show({
        bool canceled = false,
        Set<String> receipts = const {},
      }) => tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SosStatusCard(
                alert: alert(active: !canceled),
                deliveries: [message],
                confirmedMessageIds: receipts,
              ),
            ),
          ),
        ),
      );
      await show();
      expect(find.text('ส่ง SOS แล้ว'), findsOneWidget);
      expect(find.textContaining('มีผู้รับแล้ว'), findsNothing);
      await show(receipts: {'m'});
      expect(find.text('ส่ง SOS แล้ว'), findsOneWidget);
      expect(find.text('ประกาศผ่าน P2P'), findsNothing);
      expect(find.text('มีผู้รับยืนยัน'), findsNothing);
      await show(canceled: true, receipts: {'m'});
      expect(find.text('ยกเลิกแล้ว'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fullscreen map tap creates a manual pin and preserves it through JSON',
    (tester) async {
      final data = await tester.runAsync(OfflineMapData.load);
      expect(data, isNotNull);
      SosLocation? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BundledOfflineMap(
              fullScreen: true,
              onPickLocation: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(BundledOfflineMap)));
      await tester.pump();
      expect(selected, isNotNull);
      expect(selected!.manuallySelected, isTrue);
      expect(data!.contains(selected!), isTrue);
      final restored = SosLocation.fromMap(selected!.toMap());
      expect(restored.manuallySelected, isTrue);
      expect(restored.summary, contains('ปักหมุดเอง'));
      expect(restored.summary, isNot(contains('±0')));
      expect(tester.takeException(), isNull);
    },
  );

  test('SOS red meets AA for white labels', () {
    expect(
      (Colors.white.computeLuminance() + .05) /
          (kSosRed.computeLuminance() + .05),
      greaterThanOrEqualTo(4.5),
    );
  });
}
