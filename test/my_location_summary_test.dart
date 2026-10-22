import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/widgets/my_location_summary.dart';

void main() {
  testWidgets('details expand and copy works without accuracy or age summary', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final location = SosLocation(
      latitude: 14.036,
      longitude: 100.728,
      accuracy: 100,
      capturedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 34)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MyLocationSummary(location: location)),
      ),
    );
    expect(find.text('34 นาทีที่แล้ว'), findsNothing);
    expect(find.textContaining('ความแม่นยำ'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.byTooltip('คัดลอกพิกัด'));
    await tester.pump();
    expect(copied, '14.036, 100.728');
    await tester.tap(find.byTooltip('ขยายรายละเอียดตำแหน่ง'));
    await tester.pump();
    expect(find.textContaining('บันทึกเมื่อ'), findsOneWidget);
    await tester.tap(find.byTooltip('ย่อรายละเอียดตำแหน่ง'));
    await tester.pump();
    expect(find.byType(SelectableText), findsNothing);
    expect(find.textContaining('พิกัดเป็นจุดที่บันทึก'), findsNothing);
    await tester.tap(find.byTooltip('เกี่ยวกับพิกัดที่บันทึก'));
    await tester.pumpAndSettle();
    expect(find.textContaining('พิกัดเป็นจุดที่บันทึก'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing location disables copy and expansion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MyLocationSummary(location: null)),
      ),
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'คัดลอกพิกัด',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'ขยายรายละเอียดตำแหน่ง',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
