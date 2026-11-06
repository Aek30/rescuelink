import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/models/sos_emergency_info.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'package:rescuelink/services/auth_service.dart';
import 'package:rescuelink/services/account_storage.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/widgets/sos_emergency_info_summary.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'account_auth_test.dart' show MemoryVault;
import 'sos_screen_test.dart' show UiMessages;
import 'message_service_test.dart' show Transport;

const profile = <String, dynamic>{
  'full_name': 'Private Full Name',
  'phone': '0812345678',
  'health_consent': true,
  'allergies': 'แพ้ยาทดสอบ',
  'medical_conditions': 'โรคที่ไม่ได้เลือก',
  'blood_group': 'ไม่ทราบ',
  'emergency_contact_name': 'สมหญิง ใจดี',
  'emergency_contact_phone': '0891234567',
};

void main() {
  sqfliteFfiInit();
  if (const bool.fromEnvironment('SOS_INFO_PREVIEW')) {
    for (final dark in [false, true]) {
      testWidgets('emergency information card preview dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await (FontLoader(
          'NotoSansThai',
        )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? RescueTheme.dark : RescueTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: key,
                    child: const SosEmergencyInfoSummary(
                      info: {
                        'full_name': 'สมชาย ใจดี',
                        'phone': '081 234 5678',
                        'medical_conditions': 'หอบหืด',
                        'allergies': 'แพ้ยาเพนิซิลลิน และอาหารทะเล',
                        'blood_group': 'O Positive (+)',
                        'emergency_contact':
                            'สมหญิง ใจดี • 089 123 4567\nพี่สาว',
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await Directory('output/previews').create(recursive: true);
          await File(
            'output/previews/sos-emergency-info-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  test(
    'options require recorded consent for health; old SOS stays compatible',
    () {
      final options = sosEmergencyOptions(profile);
      expect(options.keys, containsAll(['full_name', 'phone', 'allergies']));
      expect(options, isNot(contains('blood_group')));
      expect(sosEmergencyOptions({...profile, 'health_consent': false}).keys, [
        'full_name',
        'phone',
      ]);
      final alert = SosAlert(
        incidentId: 'case',
        revision: 1,
        active: true,
        name: 'Me',
        people: 1,
        category: EmergencyType.medical,
        details: '',
        updatedAt: DateTime.now().toUtc(),
      );
      expect(jsonDecode(alert.toJson()), isNot(contains('emergencyInfo')));
      expect(SosAlert.fromJson(alert.toJson()).emergencyInfo, isEmpty);
      expect(validSosEmergencyInfo({'unknown': 'value'}), isFalse);
    },
  );

  test(
    'only selected fields persist, round-trip, and survive cancellation',
    () async {
      final db = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final transport = Transport();
      final service = MessageService(nearbyService: transport, database: db);
      await service.initialize();
      await service.publishSos(
        name: 'Me',
        people: 1,
        category: EmergencyType.medical,
        details: 'Help',
        recipients: {},
        emergencyInfo: {'allergies': profile['allergies'] as String},
      );
      final alert = SosAlert.fromJson(service.mySos!.toJson());
      expect(alert.emergencyInfo, {'allergies': 'แพ้ยาทดสอบ'});
      expect(alert.summary, contains('แพ้ยาทดสอบ'));
      expect(alert.toJson(), isNot(contains(profile['phone'])));
      expect(alert.toJson(), isNot(contains(profile['medical_conditions'])));
      await service.cancelSos();
      expect(service.mySos!.emergencyInfo, alert.emergencyInfo);
      expect(service.mySos!.active, isFalse);
      service.dispose();
      transport.dispose();
      await db.close();
    },
  );

  for (final signedIn in [false, true]) {
    for (final select in signedIn ? [false, true] : [false]) {
      testWidgets(
        'step 4 is optional and member only: signedIn=$signedIn select=$select',
        (tester) async {
          final auth = AuthService(
            storage: AccountStorage(factory: databaseFactoryFfi),
            vault: MemoryVault(),
          );
          if (signedIn) {
            auth.session = const AccountSession(
              'owner',
              'me@example.com',
              'session',
            );
          }
          final messages = UiMessages();
          var loads = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: SosScreen(
                service: messages,
                auth: auth,
                loadEmergencyProfile: (owner) async {
                  loads++;
                  expect(owner, 'owner');
                  return profile;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('ข้อมูลฉุกเฉินที่ต้องการแนบ'),
            signedIn ? findsOneWidget : findsNothing,
          );
          expect(loads, signedIn ? 1 : 0);
          expect(
            tester
                .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
                .every((tile) => tile.value == false),
            isTrue,
          );
          if (signedIn) {
            expect(
              tester
                  .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
                  .map((tile) => (tile.title! as Text).data)
                  .toList(),
              ['ข้อมูลส่วนตัว', 'ข้อมูลสุขภาพ', 'ผู้ติดต่อฉุกเฉิน'],
            );
          }
          await tester.tap(find.text('เจ็บป่วย / บาดเจ็บ'));
          await tester.pumpAndSettle();
          if (select) {
            final choice = find.widgetWithText(
              CheckboxListTile,
              'ข้อมูลสุขภาพ',
            );
            await tester.ensureVisible(choice);
            await tester.pumpAndSettle();
            await tester.tap(choice);
            await tester.pumpAndSettle();
          }
          final send = find.text('ส่ง SOS');
          await tester.ensureVisible(send);
          await tester.pumpAndSettle();
          await tester.tap(send);
          await tester.pumpAndSettle();
          expect(
            find.byType(SosEmergencyInfoSummary),
            select ? findsOneWidget : findsNothing,
          );
          if (select) {
            final summary = tester.widget<SosEmergencyInfoSummary>(
              find.byType(SosEmergencyInfoSummary),
            );
            expect(summary.info, {
              'allergies': 'แพ้ยาทดสอบ',
              'medical_conditions': 'โรคที่ไม่ได้เลือก',
            });
          }
          await tester.tap(find.text('ยืนยันส่ง SOS'));
          await tester.pumpAndSettle();
          expect(
            messages.sentEmergencyInfo,
            select
                ? {
                    'allergies': 'แพ้ยาทดสอบ',
                    'medical_conditions': 'โรคที่ไม่ได้เลือก',
                  }
                : isEmpty,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          messages.dispose();
          messages.nearbyService.dispose();
          auth.dispose();
        },
      );
    }
  }

  testWidgets('late data cannot reveal a previous account profile', (
    tester,
  ) async {
    final auth = AuthService(
      storage: AccountStorage(factory: databaseFactoryFfi),
      vault: MemoryVault(),
    )..session = const AccountSession('A', 'a@example.com', 'session');
    final messages = UiMessages();
    final pending = Completer<Map<String, dynamic>?>();
    await tester.pumpWidget(
      MaterialApp(
        home: SosScreen(
          service: messages,
          auth: auth,
          loadEmergencyProfile: (_) => pending.future,
        ),
      ),
    );
    await tester.pump();
    auth.session = null;
    auth.notifyListeners();
    pending.complete(profile);
    await tester.pumpAndSettle();
    expect(find.text('ข้อมูลฉุกเฉินที่ต้องการแนบ'), findsNothing);
    expect(find.text('Private Full Name'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.pumpWidget(const SizedBox());
    messages.dispose();
    messages.nearbyService.dispose();
    auth.dispose();
  });
}
