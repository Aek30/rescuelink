import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/my_sos_screen.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'package:rescuelink/widgets/sos_history_card.dart';
import 'package:rescuelink/widgets/sos_history_section_header.dart';
import 'my_sos_screen_test.dart' show UiStore;

SosRecord record(
  String id,
  DateTime time, {
  bool active = false,
  String name = 'ผู้ทดสอบ',
}) => SosRecord.fromMap({
  'payload': SosAlert(
    incidentId: id,
    revision: 1,
    active: active,
    name: name,
    people: 1,
    category: EmergencyType.other,
    details: '',
    updatedAt: time,
  ).toJson(),
  'version': 1,
  'deleted': 0,
});

void main() {
  test('blank and placeholder names use a display fallback', () {
    for (final name in ['', '  ', '-', 'unknown', 'ชื่อผู้แจ้ง', 'null']) {
      expect(sosHistoryDisplayName(name), 'ไม่ระบุชื่อ');
    }
    expect(sosHistoryDisplayName(' สมชาย '), 'สมชาย');
  });

  testWidgets(
    'active section precedes closed cases with dates and timestamps descending',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final old = today.subtract(const Duration(days: 1));
      final store = UiStore()
        ..records = [
          record('old', old),
          record('today-early', today.add(const Duration(minutes: 1))),
          record('active', now.toUtc(), active: true),
          record(
            'today-new',
            today.add(const Duration(minutes: 2)),
            name: 'unknown',
          ),
          record(
            'expired',
            old.subtract(const Duration(days: 2)),
            active: true,
          ),
        ];
      final originalOrder = store.records
          .map((r) => r.alert.incidentId)
          .toList();
      await tester.pumpWidget(
        MaterialApp(
          home: MySosScreen(store: store, onCreate: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      final children =
          (list.childrenDelegate as SliverChildListDelegate).children;
      final cards = children.whereType<SosHistoryCard>().toList();
      expect(cards.map((c) => c.record.alert.incidentId), [
        'active',
        'today-new',
        'today-early',
        'old',
        'expired',
      ]);
      expect(cards.first.active, isTrue);
      expect(cards.skip(1).every((c) => !c.active), isTrue);
      expect(
        children
            .whereType<SosHistorySectionHeader>()
            .where((h) => !h.date)
            .map((h) => h.title),
        ['กำลังดำเนินการ', 'ยุติแล้ว'],
      );
      final closedStart = children.indexWhere(
        (w) => w is SosHistorySectionHeader && w.title == 'ยุติแล้ว',
      );
      final closedDates = children
          .skip(closedStart)
          .whereType<SosHistorySectionHeader>()
          .where((h) => h.date)
          .toList();
      expect(closedDates.length, 3);
      expect(closedDates[0].title, startsWith('${today.day} '));
      expect(closedDates[1].title, startsWith('${old.day} '));
      expect(store.records.map((r) => r.alert.incidentId), originalOrder);
      expect(
        list.padding!.resolve(TextDirection.ltr).bottom,
        greaterThanOrEqualTo(96),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('sos-history-expired'));
      expect(
        tester.getBottomLeft(last).dy,
        lessThan(tester.getTopLeft(find.byType(FloatingActionButton)).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
