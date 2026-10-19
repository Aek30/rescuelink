import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/member_screen.dart';
import 'package:rescuelink/screens/settings_panel.dart';
import 'package:rescuelink/services/app_preferences.dart';
import 'package:rescuelink/services/auth_service.dart';

void main() {
  testWidgets(
    'profile settings fit a small screen without an offline queue card',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
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
      Widget app() => MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansThai'),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            body: SettingsPanel(
              rescue: false,
              ready: false,
              onRescue: (_) {},
              onDevice: () {},
              onConnection: () {},
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Card), findsNothing);
      expect(find.text('คิวข้อความออฟไลน์'), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
      if (const bool.fromEnvironment('UX_CAPTURE')) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'docs/ui-audit/settings-redesign.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      AppPreferences.instance.dark = true;
      AppPreferences.instance.english = true;
      addTearDown(AppPreferences.instance.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Display theme'), findsOneWidget);
      expect(find.text('Assistance'), findsOneWidget);
      expect(find.text('App settings'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile header shows auth name and email, removes role badge and duplicate button, and opens MemberScreen on tap',
    (tester) async {
      final auth = AuthService.instance;
      final previousSession = auth.session;
      addTearDown(() {
        auth.session = previousSession;
        AppPreferences.instance.reset();
      });

      auth.session = const AccountSession(
        'user-123',
        'member@rescuelink.org',
        '{"user":{"user_metadata":{"display_name":"สมชาย ใจดี"}}}',
      );
      AppPreferences.instance.displayName = 'สมชาย ใจดี';

      var responderTapped = false;
      bool? rescueRequested;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(
              rescue: true,
              ready: true,
              onRescue: (value) => rescueRequested = value,
              onDevice: () {},
              onConnection: () {},
              onExit: () {},
              onResponder: () => responderTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows real member name and email from Authentication
      expect(find.text('สมชาย ใจดี'), findsOneWidget);
      expect(find.text('member@rescuelink.org'), findsOneWidget);

      // User type badges and duplicate edit button are completely removed
      expect(find.text('ผู้ช่วยเหลือทั่วไป • ไม่ยืนยันหน่วยงาน'), findsNothing);
      expect(find.text('ผู้ใช้ทั่วไป'), findsNothing);
      expect(find.text('ดู / แก้ไขข้อมูลสมาชิก'), findsNothing);
      expect(find.byIcon(Icons.volunteer_activism_rounded), findsNothing);
      expect(find.byIcon(Icons.manage_accounts_rounded), findsNothing);

      // Menu groups and items remain intact
      expect(find.text('การช่วยเหลือ'), findsOneWidget);
      expect(find.text('การตั้งค่าแอป'), findsOneWidget);
      expect(find.text('ระบบ'), findsOneWidget);
      expect(find.text('หน่วยกู้ภัย'), findsOneWidget);
      expect(find.text('ภาษา'), findsOneWidget);
      expect(find.text('ธีมการแสดงผล'), findsOneWidget);
      expect(find.text('การแจ้งเตือน'), findsOneWidget);
      expect(find.text('การเชื่อมต่อและสิทธิ์'), findsOneWidget);
      expect(find.text('เกี่ยวกับ RescueLink'), findsOneWidget);
      expect(find.text('ออกจากระบบ'), findsOneWidget);

      final rescueSwitch = find.byKey(const ValueKey('rescue-mode-switch'));
      expect(tester.widget<Switch>(rescueSwitch).value, isTrue);
      await tester.tap(rescueSwitch);
      await tester.pump();
      expect(rescueRequested, isFalse);
      expect(responderTapped, isFalse);

      // The label still opens received SOS reports.
      await tester.tap(find.text('หน่วยกู้ภัย'));
      await tester.pump();
      expect(responderTapped, isTrue);

      // Tapping Profile Header opens MemberScreen
      await tester.tap(find.byKey(const ValueKey('profile-header')));
      await tester.pumpAndSettle();
      expect(find.byType(MemberScreen), findsOneWidget);
    },
  );
}
