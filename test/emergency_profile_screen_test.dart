import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/emergency_profile_screen.dart';
import 'package:rescuelink/screens/register_screen.dart';
import 'package:rescuelink/services/emergency_profile_service.dart';
import 'package:rescuelink/services/emergency_profile_store.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'emergency_profile_test.dart' show sampleProfile;

class ProfileScreenFake implements EmergencyProfileRepository {
  Map<String, dynamic> data = Map.from(sampleProfile);
  int saves = 0, deletions = 0;
  @override
  Future<EmergencyProfileResult> read() async => EmergencyProfileResult(data);
  @override
  Future<EmergencyProfileResult> save(Map<String, dynamic> value) async {
    saves++;
    data = normalizeProfile(value);
    return EmergencyProfileResult(data);
  }

  @override
  Future<EmergencyProfileResult> deleteHealth() async {
    deletions++;
    data = normalizeProfile({...data, 'health_consent': false});
    return EmergencyProfileResult(data, pending: true);
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'medical editor saves and withdraws consent on small screen dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = ProfileScreenFake();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? RescueTheme.dark : RescueTheme.light,
            home: EmergencyProfileScreen(repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final allergy = find.byKey(const ValueKey('profile-allergies'));
        await tester.scrollUntilVisible(
          allergy,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(allergy, 'Updated allergy');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'บันทึกข้อมูล');
        await tester.scrollUntilVisible(
          save,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repo.saves, 1);
        expect(repo.data['allergies'], 'Updated allergy');
        final delete = find.widgetWithText(
          OutlinedButton,
          'ถอนความยินยอมและลบสุขภาพ',
        );
        await tester.ensureVisible(delete);
        await tester.pumpAndSettle();
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'ลบข้อมูลสุขภาพ'));
        await tester.pumpAndSettle();
        expect(repo.deletions, 1);
        expect(repo.data.containsKey('allergies'), isFalse);
        expect(repo.data['full_name'], sampleProfile['full_name']);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('verification dialog scrolls without overflow at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationDialog(
          email: 'longemailaddress@example.com',
          onResend: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
