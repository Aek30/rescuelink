import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/incoming_notice.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/nearby_device.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/services/app_preferences.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'message_service_test.dart' show Transport;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late LocalDatabaseService db;
  late LocalDatabaseService original;
  late Transport transport;
  late MessageService service;
  late List<IncomingNotice> notices;
  late List<String> cancelled;
  final prefs = AppPreferences.instance;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'rescuelink-notifications-',
    );
    original = LocalDatabaseService.instance;
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${directory.path}/test.db',
    );
    LocalDatabaseService.instance = db;
    prefs.reset();
    transport = Transport();
    service = MessageService(nearbyService: transport, database: db);
    await service.initialize();
    transport.devices.add(
      NearbyDevice(endpointId: 'endpoint', name: 'ผู้ส่ง')..isConnected = true,
    );
    await service.handleIncomingPayload(
      endpointId: 'endpoint',
      rawPayload: MessageModel(
        id: 'intro',
        senderId: 'peer',
        senderName: 'ผู้ส่ง',
        receiverId: service.myId!,
        text: '',
        timestamp: DateTime.now(),
        type: MessageType.deviceInfo,
      ).toJson(),
    );
    notices = [];
    cancelled = [];
    service.onNotice = notices.add;
    service.onNoticeCancelled = cancelled.add;
  });

  tearDown(() async {
    service.dispose();
    transport.dispose();
    prefs.reset();
    LocalDatabaseService.instance = original;
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> receive({String id = 'message', SosAlert? sos}) =>
      service.handleIncomingPayload(
        endpointId: 'endpoint',
        rawPayload: MessageModel(
          id: id,
          senderId: 'peer',
          senderName: 'ผู้ส่ง',
          receiverId: service.myId!,
          text: sos?.toJson() ?? 'สวัสดี',
          timestamp: DateTime.now(),
          type: sos == null ? MessageType.message : MessageType.sos,
        ).toJson(),
      );

  SosAlert alert({int revision = 1, bool active = true}) => SosAlert(
    incidentId: 'incident',
    revision: revision,
    active: active,
    name: 'ผู้ขอความช่วยเหลือ',
    people: 2,
    category: EmergencyType.medical,
    details: 'ต้องการความช่วยเหลือ',
    updatedAt: DateTime.now(),
  );

  test('disabling chat alerts preserves SOS alerts', () async {
    prefs.chatAlerts = false;
    await service.setRescueMode(true);
    await receive();
    await receive(id: 'sos', sos: alert());
    expect(notices, hasLength(1));
    expect(notices.single.sos, isNotNull);
  });

  test(
    'active conversation suppresses chat notices but preserves SOS',
    () async {
      service.activeChatPeerId = 'peer';
      await receive();
      expect(notices, isEmpty);
      expect(service.totalUnread, 1);
      await service.setRescueMode(true);
      await receive(id: 'sos', sos: alert());
      expect(notices.single.sos, isNotNull);
      service.activeChatPeerId = null;
      await receive(id: 'another');
      expect(notices, hasLength(2));
    },
  );

  test(
    'inactive SOS cancels its notification without creating a notice',
    () async {
      await service.setRescueMode(true);
      await receive(id: 'sos', sos: alert());
      notices.clear();
      await receive(id: 'cancel', sos: alert(revision: 2, active: false));
      expect(notices, isEmpty);
      expect(cancelled, ['sos:incident']);
      await receive(id: 'cancel-again', sos: alert(revision: 2, active: false));
      expect(cancelled, hasLength(1));
    },
  );

  test('cancellation works when SOS alerts and rescue mode are off', () async {
    prefs.sosAlerts = false;
    await receive(id: 'cancel', sos: alert(active: false));
    expect(notices, isEmpty);
    expect(cancelled, ['sos:incident']);
  });

  test('disabling SOS alerts preserves chat alerts', () async {
    prefs.sosAlerts = false;
    await service.setRescueMode(true);
    await receive(id: 'sos', sos: alert());
    await receive();
    expect(notices.single.sos, isNull);
  });

  test('successful read cancels the conversation notification', () async {
    await receive();
    expect(service.totalUnread, 1);
    await service.markConversationRead('peer', 'message');
    expect(cancelled, ['chat:peer']);
    expect(service.totalUnread, 0);
  });

  test(
    'notification keys stay stable across messages and SOS revisions',
    () async {
      await receive();
      await receive(id: 'second');
      expect(notices.map((n) => n.notificationId), ['chat:peer', 'chat:peer']);
      notices.clear();
      await service.setRescueMode(true);
      await receive(id: 'sos', sos: alert());
      await receive(id: 'update', sos: alert(revision: 2));
      expect(notices.map((n) => n.notificationId), [
        'sos:incident',
        'sos:incident',
      ]);
    },
  );

  test(
    'legacy disabled preference migrates to chat once; SOS defaults on',
    () async {
      await db.setSetting('sosAlerts', 'false');
      await prefs.load();
      expect(prefs.chatAlerts, isFalse);
      expect(prefs.sosAlerts, isTrue);
      await prefs.set('sosAlerts', false);
      await prefs.load();
      expect(prefs.chatAlerts, isFalse);
      expect(prefs.sosAlerts, isFalse);
      await prefs.set('chatAlerts', true);
      await prefs.load();
      expect(prefs.chatAlerts, isTrue);
      expect(prefs.sosAlerts, isFalse);
    },
  );
}
