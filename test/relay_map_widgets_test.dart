import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/widgets/relay_badge.dart';

void main() {
  testWidgets('relay separates intermediary devices from radio hops', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RelayBadge(
            route: ['a', 'b', 'c', 'd'],
            peers: {'b': 'Rescue B'},
          ),
        ),
      ),
    );
    expect(find.text('ผ่าน Rescue B'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('Rescue B'), findsOneWidget);
    expect(find.textContaining('เส้นทางแรกที่ได้รับ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown route never invents a relay count', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RelayBadge(route: null, peers: {})),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });
}
