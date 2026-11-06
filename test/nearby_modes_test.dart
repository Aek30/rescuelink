import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/models/incoming_notice.dart';
import 'package:rescuelink/widgets/in_app_message_banner.dart';
import 'package:rescuelink/models/nearby_device.dart';
import 'package:rescuelink/screens/nearby_test_screen.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:rescuelink/services/connection_session.dart';
import 'package:rescuelink/services/permission_service.dart';
import 'package:rescuelink/services/sos_location_service.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/widgets/presence_list.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Native extends Fake implements Nearby {}

class _FeedbackSession extends ConnectionSession {
  int starts = 0, stops = 0, notifications = 0, chatSounds = 0;
  @override
  Future<void> playChatFeedback() async {
    chatSounds++;
  }

  @override
  Future<void> startSosFeedback() async {
    starts++;
  }

  @override
  Future<void> stopSosFeedback() async {
    stops++;
  }

  @override
  Future<void> notify(IncomingNotice notice, {int unreadCount = 1}) async {
    notifications++;
  }
}

class _Nearby extends NearbyService {
  _Nearby({PermissionService? permissionService, super.session})
    : super(nearby: _Native(), permissions: permissionService) {
    if (permissionService == null) {
      permissions.statuses.updateAll((_, _) => 'Granted');
    }
  }
  bool verifyPermissions = false;
  int searches = 0;
  Future<void>? pendingStart;
  final pendingDevices = <NearbyDevice>[];
  @override
  List<NearbyDevice> get discoveredDevices => pendingDevices;
  @override
  Future<void> startNearby() async {
    searches++;
    final pending = pendingStart;
    pendingStart = null;
    await pending;
    if (verifyPermissions && !await checkPermissions()) return;
    isAdvertising = true;
    isDiscovering = true;
    notifyListeners();
  }

  @override
  Future<void> stopAll() async {
    pendingDevices.clear();
    isAdvertising = isDiscovering = false;
    notifyListeners();
  }
}

class _DelayedPermissions extends PermissionService {
  final result = Completer<bool>();
  @override
  Future<bool> ensureReady() async {
    final allowed = await result.future;
    statuses.updateAll((_, _) => allowed ? 'Granted' : 'Denied');
    error = allowed ? null : 'Permission denied';
    return allowed;
  }
}

class _Settings extends LocalDatabaseService {
  _Settings() : super(factory: databaseFactoryFfi);
  @override
  Future<String?> getSetting(String key) async => null;
}

class _NoLocation extends SosLocationService {
  @override
  Future<SosLocation?> lastKnown() async => null;
  @override
  Future<SosLocation> capture() async => throw StateError('GPS unavailable');
}

class _Messages extends MessageService {
  _Messages({required super.nearbyService}) : super(database: _Settings()) {
    myId = 'me';
  }
  @override
  Future<void> initialize() async {}
  void mode({bool sos = false, bool rescue = false}) {
    rescueMode = rescue;
    mySos = sos
        ? SosAlert(
            incidentId: 'own',
            revision: 1,
            active: true,
            name: 'ฉัน',
            people: 1,
            category: EmergencyType.other,
            details: 'ขอความช่วยเหลือ',
            updatedAt: DateTime.now().toUtc(),
          )
        : null;
    notifyListeners();
  }

  @override
  Future<void> cancelSos() async => mode();
  @override
  Future<void> setRescueMode(bool value) async => mode(rescue: value);
}

void main() {
  testWidgets(
    'focus loss uses in-app sound without duplicate notifications; SOS starts/stops feedback',
    (tester) async {
      final session = _FeedbackSession();
      final nearby = _Nearby(session: session);
      final messages = _Messages(nearbyService: nearby);
      await tester.pumpWidget(
        MaterialApp(
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
            locationService: _NoLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      messages.onNotice!(
        const IncomingNotice(
          id: 'chat',
          peerId: 'peer',
          name: 'เพื่อน',
          body: 'สวัสดี',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsOneWidget);
      expect(session.notifications, 0);
      expect(session.starts, 0);
      expect(session.chatSounds, 1);
      messages.onNotice!(
        IncomingNotice(
          id: 'sos',
          peerId: 'peer',
          name: 'เพื่อน',
          body: 'ช่วยด้วย',
          sos: SosAlert(
            incidentId: 'case',
            revision: 1,
            active: true,
            name: 'เพื่อน',
            people: 1,
            category: EmergencyType.medical,
            details: 'ช่วยด้วย',
            updatedAt: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsOneWidget);
      expect(session.starts, 1);
      expect(session.chatSounds, 1);
      await tester.tap(find.byTooltip('ปิดแจ้งเตือน SOS'));
      await tester.pumpAndSettle();
      expect(session.stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      messages.onNotice!(
        const IncomingNotice(
          id: 'background',
          peerId: 'peer',
          name: 'เพื่อน',
          body: 'ข้อความ',
        ),
      );
      await tester.pump();
      expect(session.notifications, 1);
      expect(session.starts, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'floating message banner does not shift content; expires, swipes and opens chat: dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final nearby = _Nearby();
        final messages = _Messages(nearbyService: nearby);
        messages.peers['peer'] = 'เพื่อน';
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? RescueTheme.dark : RescueTheme.light,
            home: NearbyTestScreen(
              nearbyService: nearby,
              messageService: messages,
              locationService: _NoLocation(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final content = find.byKey(const ValueKey('nearby-primary-presence'));
        final before = tester.getTopLeft(content);
        IncomingNotice notice(String body) => IncomingNotice(
          id: body,
          peerId: 'peer',
          name: 'เพื่อน',
          body: body,
        );
        messages.onNotice!(notice('สวัสดี'));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(content), before);
        expect(find.byType(InAppMessageBanner), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        messages.onNotice!(notice('ข้อความใหม่ล่าสุด'));
        await tester.pumpAndSettle();
        expect(find.text('สวัสดี'), findsNothing);
        await tester.pump(const Duration(seconds: 3));
        expect(find.byType(InAppMessageBanner), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(InAppMessageBanner), findsNothing);
        messages.onNotice!(notice('ปัดขึ้นเพื่อปิด'));
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(InAppMessageBanner),
          const Offset(0, -150),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.byType(InAppMessageBanner), findsNothing);
        messages.onNotice!(notice('แตะเปิดแชท'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('แตะเปิดแชท'));
        await tester.pumpAndSettle();
        expect(find.byType(InAppMessageBanner), findsNothing);
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
  testWidgets(
    'foreground SOS banner expires, opens details and cancels safely',
    (tester) async {
      final nearby = _Nearby();
      final messages = _Messages(nearbyService: nearby);
      messages.peers['peer'] = 'ผู้ส่ง';
      await tester.pumpWidget(
        MaterialApp(
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
            locationService: _NoLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      IncomingNotice notice(int revision) => IncomingNotice(
        id: 'incident:$revision',
        peerId: 'peer',
        name: 'ผู้ส่ง',
        body: 'ช่วยด้วย',
        sos: SosAlert(
          incidentId: 'incident',
          revision: revision,
          active: true,
          name: 'ผู้ส่ง',
          people: 2,
          category: EmergencyType.medical,
          details: 'ช่วยด้วย',
          updatedAt: DateTime.now(),
        ),
      );
      messages.onNotice!(
        const IncomingNotice(
          id: 'chat',
          peerId: 'peer',
          name: 'ผู้ส่ง',
          body: 'สวัสดี',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsOneWidget);
      messages.onNotice!(notice(1));
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsOneWidget);
      expect(find.text('SOS จาก ผู้ส่ง'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('ข้อความ').last);
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(find.byType(InAppMessageBanner), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsNothing);
      messages.onNotice!(notice(2));
      await tester.pumpAndSettle();
      messages.onNotice!(notice(3));
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsOneWidget);
      messages.onNoticeCancelled!('sos:incident');
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsNothing);
      messages.onNotice!(notice(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ดู SOS'));
      await tester.pumpAndSettle();
      expect(find.byType(InAppMessageBanner), findsNothing);
      expect(find.text('รายละเอียด SOS'), findsOneWidget);
      expect(find.text('2 คน'), findsOneWidget);
      expect(find.text('ติดต่อผ่านแชต'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  for (final allowed in [true, false]) {
    for (final slow in [false, true]) {
      testWidgets(
        'permission checks do not flash or shift content: allowed=$allowed slow=$slow',
        (tester) async {
          final permissions = _DelayedPermissions();
          final nearby = _Nearby(permissionService: permissions)
            ..verifyPermissions = true;
          final messages = _Messages(nearbyService: nearby);
          await tester.pumpWidget(
            MaterialApp(
              home: NearbyTestScreen(
                nearbyService: nearby,
                messageService: messages,
                locationService: _NoLocation(),
              ),
            ),
          );
          expect(find.text('กำลังตรวจสอบสิทธิ์'), findsNothing);
          final content = find.byKey(const ValueKey('nearby-primary-presence'));
          final initialPosition = tester.getTopLeft(content);
          final progress = find.byKey(
            const ValueKey('nearby-delayed-progress'),
          );
          expect(progress, findsNothing);
          expect(find.text('สิทธิ์การเข้าถึง'), findsNothing);
          expect(find.text('ตรวจสอบ / อนุญาตสิทธิ์'), findsNothing);
          await tester.pump();
          expect(nearby.isCheckingPermissions, isTrue);
          await tester.pump(const Duration(milliseconds: 300));
          expect(progress, findsNothing);
          if (slow) {
            await tester.pump(const Duration(milliseconds: 400));
            expect(progress, findsOneWidget);
            expect(find.text('กำลังตรวจสอบสิทธิ์'), findsNothing);
            expect(tester.getTopLeft(content), initialPosition);
          }
          permissions.result.complete(allowed);
          await tester.pumpAndSettle();
          expect(nearby.hasCheckedPermissions, isTrue);
          expect(nearby.isCheckingPermissions, isFalse);
          expect(progress, findsNothing);
          if (allowed) {
            expect(tester.getTopLeft(content), initialPosition);
          }
          expect(find.text('กำลังตรวจสอบสิทธิ์'), findsNothing);
          expect(
            find.text('สิทธิ์การเข้าถึง'),
            allowed ? findsNothing : findsOneWidget,
          );
          expect(
            find.text('ตรวจสอบ / อนุญาตสิทธิ์'),
            allowed ? findsNothing : findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  testWidgets(
    'resume during permission work retries once; explicit stop stays stopped',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final permission = Completer<void>();
      final nearby = _Nearby()..pendingStart = permission.future;
      final messages = _Messages(nearbyService: nearby);
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
            locationService: _NoLocation(),
          ),
        ),
      );
      await tester.pump();
      expect(nearby.searches, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      permission.complete();
      await tester.pumpAndSettle();
      expect(nearby.searches, 2);
      expect(find.text('กำลังค้นหาคนรอบตัวคุณ…'), findsOneWidget);
      nearby.pendingDevices.add(
        NearbyDevice(endpointId: 'peer', name: 'Phone B', isConnecting: true),
      );
      nearby.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('กำลังเชื่อมต่อ…'), findsOneWidget);
      expect(find.text('กำลังค้นหาคนรอบตัวคุณ…'), findsNothing);
      await tester.ensureVisible(find.text('กำลังค้นหา •'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('กำลังค้นหา •'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('หยุดการค้นหา'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'หยุดการค้นหา'));
      await tester.pumpAndSettle();
      expect(find.text('หยุดค้นหาแล้ว'), findsOneWidget);
      expect(find.text('กำลังเชื่อมต่อ…'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(nearby.searches, 2);
      expect(find.text('หยุดค้นหาแล้ว'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final dark in [false, true]) {
    testWidgets('home changes priority using own mode, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nearby = _Nearby();
      final messages = _Messages(nearbyService: nearby);
      // A remote SOS must not turn this phone's hero into SOS mode.
      messages.presence['remote'] = PeerPresence(
        sequence: 1,
        rescue: false,
        receivedAt: DateTime.now().toUtc(),
        sos: SosAlert(
          incidentId: 'remote',
          revision: 1,
          active: true,
          name: 'อีกเครื่อง',
          people: 1,
          category: EmergencyType.other,
          details: 'Help',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? RescueTheme.dark : RescueTheme.light,
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
            locationService: _NoLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(nearby.searches, 1);
      expect(find.text('กำลังขอความช่วยเหลือ'), findsNothing);
      final primary = find.byKey(const ValueKey('nearby-primary-presence'));
      final secondary = find.byKey(const ValueKey('nearby-secondary-presence'));
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('nearby-home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(primary, 200, scrollable: scrollable);
      expect(tester.widget<PresenceList>(primary).filter, PresenceFilter.all);
      expect(tester.widget<PresenceList>(primary).reachableOnly, isTrue);
      messages.mode(sos: true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PresenceList>(primary).filter,
        PresenceFilter.rescue,
      );
      expect(
        tester.widget<PresenceList>(secondary).excludeFilter,
        PresenceFilter.rescue,
      );
      expect(tester.widget<PresenceList>(secondary).reachableOnly, isTrue);
      expect(find.text('ผู้พร้อมช่วยเหลือ'), findsOneWidget);
      expect(tester.widget<PresenceList>(primary).reachableOnly, isTrue);
      messages.mode(rescue: true);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(primary, 200, scrollable: scrollable);
      expect(tester.widget<PresenceList>(primary).filter, PresenceFilter.sos);
      expect(tester.widget<PresenceList>(primary).reachableOnly, isTrue);
      expect(
        tester.widget<PresenceList>(secondary).excludeFilter,
        PresenceFilter.sos,
      );
      expect(tester.widget<PresenceList>(secondary).reachableOnly, isTrue);
      expect(find.text('คนที่ต้องการความช่วยเหลือ'), findsOneWidget);
      messages.mode();
      await tester.pumpAndSettle();
      expect(tester.widget<PresenceList>(primary).filter, PresenceFilter.all);
      expect(tester.widget<PresenceList>(primary).reachableOnly, isTrue);
      expect(secondary, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
