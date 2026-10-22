import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/incident_detail_screen.dart';
import 'package:rescuelink/widgets/bundled_offline_map.dart';
import 'package:rescuelink/widgets/incident_status_chip.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'sos_screen_test.dart' show UiMessages;

class IncidentMessages extends UiMessages {
  bool reachable = false;
  @override
  bool isReachable(String peerId) => reachable;
  @override
  String connectionLabel(String peerId) =>
      reachable ? 'เชื่อมต่อโดยตรง' : 'ยังติดต่อไม่ได้ • รอเชื่อมต่อ';
  void connect() {
    reachable = true;
    notifyListeners();
  }
}

void main() {
  for (final width in [320.0, 600.0]) {
    testWidgets('incident summary, sticky contact and live status at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = IncidentMessages();
      final now = DateTime.now().toUtc();
      final location = SosLocation(
        latitude: 14.036,
        longitude: 100.728,
        accuracy: 52,
        capturedAt: now.subtract(const Duration(minutes: 66)),
      );
      service.presence['peer'] = PeerPresence(
        sequence: 1,
        rescue: false,
        receivedAt: now,
        sos: SosAlert(
          incidentId: 'demo',
          revision: 1,
          active: true,
          name: 'สมชาย ใจดี',
          people: 4,
          category: EmergencyType.other,
          categories: [EmergencyType.other, EmergencyType.supplies],
          details: 'ติดอยู่ชั้นสอง ต้องการน้ำดื่ม',
          updatedAt: now,
          location: location,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          home: IncidentDetailScreen(service: service, peerId: 'peer'),
        ),
      );
      await tester.pump();
      expect(find.text('รายละเอียด SOS'), findsOneWidget);
      expect(find.text('สมชาย ใจดี'), findsOneWidget);
      expect(find.text('4 คน'), findsOneWidget);
      expect(find.textContaining('อัปเดตเมื่อ'), findsOneWidget);
      expect(find.text('รายละเอียดทางเทคนิค'), findsNothing);
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('incident-header')))
            .decoration,
        isA<BoxDecoration>().having(
          (d) => d.color,
          'active header color',
          const Color(0xFFFFF0F1),
        ),
      );
      expect(find.text('ออฟไลน์ • ข้อมูลเก่า'), findsOneWidget);
      expect(find.byType(PeerConnectionChip), findsOneWidget);
      final contact = find.widgetWithText(FilledButton, 'ติดต่อผ่านแชต');
      expect(contact.hitTestable(), findsOneWidget);
      expect(tester.getSize(contact).height, greaterThanOrEqualTo(56));
      service.connect();
      await tester.pump();
      expect(find.text('เชื่อมต่อโดยตรง'), findsOneWidget);
      expect(find.text('ออฟไลน์ • ข้อมูลเก่า'), findsNothing);
      await tester.scrollUntilVisible(
        find.byTooltip('คัดลอกพิกัด'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('14.03600, 100.72800'), findsOneWidget);
      expect(find.text('อายุตำแหน่ง 66 นาที • ข้อมูลเก่า'), findsOneWidget);
      expect(find.text('ความแม่นยำ ±52 ม.'), findsOneWidget);
      expect(
        find.textContaining(location.capturedAt.toIso8601String()),
        findsNothing,
      );
      expect(contact.hitTestable(), findsOneWidget);
      final map = tester.widget<BundledOfflineMap>(
        find.byType(BundledOfflineMap),
      );
      expect(map.compact, isTrue);
      expect(map.showAccuracyCircles, isTrue);
      expect(map.markers.single.color.a, lessThan(1));
      await tester.ensureVisible(find.byTooltip('ข้อมูลแผนที่'));
      await tester.tap(find.byTooltip('ข้อมูลแผนที่'));
      await tester.pumpAndSettle();
      expect(find.text('เกี่ยวกับแผนที่'), findsOneWidget);
      await tester.ensureVisible(find.text('ปิด'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ปิด'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('เปิดแผนที่เต็มจอ'));
      await tester.pumpAndSettle();
      expect(find.text('ตำแหน่งเหตุ SOS'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('คัดลอกพิกัด'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.tap(find.byTooltip('คัดลอกพิกัด'));
      await tester.pump();
      expect(copied, '14.03600, 100.72800');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      await tester.scrollUntilVisible(
        find.text('ได้รับข้อความ ≠ มีหน่วยกู้ภัยตอบรับ'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(contact.hitTestable(), findsOneWidget);
      expect(find.text('รายละเอียดทางเทคนิค'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      service.dispose();
      service.nearbyService.dispose();
    });
  }
}
