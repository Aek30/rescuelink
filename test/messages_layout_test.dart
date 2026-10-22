import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/messages_screen.dart';
import 'package:rescuelink/services/app_preferences.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'sos_screen_test.dart' show UiMessages;

class _Messages extends UiMessages {
  @override
  bool isOnline(String id) => id == 'peer';
  @override
  bool isReachable(String id) => id == 'other';
  @override
  String? relayViaName(String id) => id == 'other' ? 'นนท์' : null;
}

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets('messages status, badges and layout at $width dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        await (FontLoader(
          'NotoSansThai',
        )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppPreferences.instance.reset();
        final service = _Messages();
        addTearDown(() {
          service.dispose();
          service.nearbyService.dispose();
          AppPreferences.instance.reset();
        });
        final now = DateTime.now();
        service.peers.addAll({
          'peer': 'สมชาย ใจดี ชื่อผู้ติดต่อยาวมาก',
          'other': 'อาสาสมัคร',
          'offline': 'เพื่อนบ้าน',
        });
        service.messages = [
          for (final id in ['peer', 'other', 'offline'])
            MessageModel(
              id: id,
              senderId: id == 'peer' ? 'me' : id,
              senderName: id,
              receiverId: id == 'peer' ? id : 'me',
              text: 'ข้อความล่าสุดที่ยาวมากเพื่อทดสอบการตัดข้อความ',
              timestamp: now,
              status: id == 'peer'
                  ? MessageStatus.pending
                  : MessageStatus.delivered,
            ),
        ];
        service.unreadCounts = {'peer': 12};
        service.presence['peer'] = PeerPresence(
          sequence: 1,
          rescue: false,
          receivedAt: now,
          sos: SosAlert(
            incidentId: 'sos',
            revision: 1,
            active: true,
            name: 'สมชาย',
            people: 1,
            category: EmergencyType.other,
            details: '',
            updatedAt: now,
          ),
        );
        service.presence['other'] = PeerPresence(
          sequence: 1,
          rescue: true,
          receivedAt: now,
        );
        final boundary = GlobalKey();
        Future<void> show() => tester.pumpWidget(
          MaterialApp(
            theme: dark ? RescueTheme.dark : RescueTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.3 : 1)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: MessagesScreen(service: service, onNearby: () {}),
              ),
            ),
          ),
        );
        await show();
        await tester.pumpAndSettle();
        expect(find.text('SOS'), findsOneWidget);
        expect(find.text('หน่วยกู้ภัย'), findsOneWidget);
        expect(find.text('ผู้ใช้ทั่วไป'), findsNothing);
        expect(find.text('เชื่อมต่ออยู่'), findsNothing);
        expect(find.text('ไม่ได้เชื่อมต่อ'), findsOneWidget);
        expect(find.text('ส่งผ่านเครื่อง นนท์'), findsOneWidget);
        expect(find.byTooltip('มีข้อความรอส่ง'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.byType(Divider), findsNothing);
        expect(tester.takeException(), isNull);
        if (width == 390 && const bool.fromEnvironment('MESSAGES_CAPTURE')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'output/messages-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        service.error = 'ยังโหลดข้อมูลไม่ได้ กรุณาลองใหม่';
        service.notifyListeners();
        await tester.pump();
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text(service.error!), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
