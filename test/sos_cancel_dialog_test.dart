import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/widgets/sos_cancel_dialog.dart';

void main() {
  testWidgets(
    'standard reasons return immediately and back leaves SOS unchanged',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const SosCancelDialog(),
                  );
                },
                child: const Text('เปิด'),
              ),
            ),
          ),
        ),
      );
      for (final reason in [
        'ได้รับความช่วยเหลือแล้ว',
        'ปลอดภัยแล้ว',
        'แจ้งผิด',
      ]) {
        await tester.tap(find.text('เปิด'));
        await tester.pumpAndSettle();
        expect(find.byType(CancelReasonTile), findsNWidgets(4));
        await tester.ensureVisible(find.text(reason));
        await tester.tap(find.text(reason));
        await tester.pumpAndSettle();
        expect(result, reason);
      }
      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('กลับ'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'other reason needs text and confirmation on small screen, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? RescueTheme.dark : RescueTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (_) => const SosCancelDialog(),
                    );
                  },
                  child: const Text('เปิด'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('เปิด'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('อื่น ๆ'));
        await tester.tap(find.text('อื่น ๆ'));
        await tester.pumpAndSettle();
        expect(find.byType(SosCancelDialog), findsOneWidget);
        expect(result, isNull);
        final confirm = find.widgetWithText(FilledButton, 'ยืนยันยกเลิก SOS');
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(
          find.byType(TextField),
          '  ขอเปลี่ยนรายละเอียดเหตุ  ',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(result, 'อื่น ๆ: ขอเปลี่ยนรายละเอียดเหตุ');
        expect(find.byType(SosCancelDialog), findsNothing);
      },
    );
  }
}
