import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/messages_screen.dart';
import 'package:rescuelink/screens/nearby_test_screen.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'package:rescuelink/screens/settings_panel.dart';
import 'package:rescuelink/widgets/outbox_queue.dart';
import 'package:rescuelink/services/app_preferences.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/responder_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'sos_screen_test.dart' show UiTransport;

class OfflineMessages extends MessageService {
  OfflineMessages(LocalDatabaseService db)
    : super(nearbyService: UiTransport(), database: db) {
    myId = 'me';
    peers = {'a': 'Alice', 'b': 'Bob', 'empty': 'No history'};
  }
  @override
  Future<void> retry() async {}
}

class TabTransport extends UiTransport {
  @override
  Future<void> startNearby() async {}
}
class TabMessages extends MessageService {
  TabMessages(LocalDatabaseService db) : super(nearbyService: TabTransport(), database: db) { myId = 'me'; }
  @override
  Future<void> initialize() async {}
}

void main() {
  sqfliteFfiInit();
  late LocalDatabaseService db;
  late OfflineMessages service;
  setUp(() {
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    LocalDatabaseService.instance = db;
    service = OfflineMessages(db);
    AppPreferences.instance.reset();
  });
  tearDown(() async {
    service.dispose();
    service.nearbyService.dispose();
    await db.close();
    AppPreferences.instance.reset();
  });
  testWidgets(
    'conversation list uses real history, sorts, searches and filters unread',
    (tester) async {
      service.messages = [
        MessageModel(
          id: '1',
          senderId: 'a',
          senderName: 'Alice',
          receiverId: 'me',
          text: 'older',
          timestamp: DateTime.utc(2026, 10, 1),
        ),
        MessageModel(
          id: '2',
          senderId: 'me',
          senderName: 'Me',
          receiverId: 'b',
          text: 'latest',
          timestamp: DateTime.utc(2026, 10, 2),
        ),
      ];
      service.unreadCounts = {'a': 1};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesScreen(service: service, onNearby: () {}),
          ),
        ),
      );
      expect(find.text('No history'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Bob')).dy,
        lessThan(tester.getTopLeft(find.text('Alice')).dy),
      );
      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pump();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('ยังไม่อ่าน'));
      await tester.pump();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
    },
  );
  test(
    'case work is durable, duplicate-safe, unconfirmed and uses original offline queue',
    () async {
      service.rescueMode = true;
      final alert = SosAlert(
        incidentId: 'case-1',
        revision: 1,
        active: true,
        name: 'Alice',
        people: 2,
        category: EmergencyType.medical,
        details: 'help',
        updatedAt: DateTime.now().toUtc(),
      );
      final store = ResponderStore(service);
      await store.update('a', alert, 'pending');
      final first = await store.read('a', alert.incidentId);
      await store.update('a', alert, 'pending');
      expect(await store.read('a', alert.incidentId), first);
      await store.notifyReporter('a', alert.incidentId);
      await store.notifyReporter('a', alert.incidentId);
      final messages = await db.getMessages();
      expect(messages, hasLength(1));
      expect(messages.single.status, MessageStatus.pending);
      expect(messages.single.text, contains('รอการยืนยัน'));
      expect(
        (await ResponderStore(service).read('a', alert.incidentId))!['stage'],
        'pending',
      );
      await store.update('a', alert, 'helping');
      await store.update('a', alert, 'completed');
      await expectLater(store.update('a', alert, 'helping'), throwsStateError);
      service.rescueMode = false;
      await expectLater(store.update('a', alert, 'pending'), throwsStateError);
      await expectLater(store.update('a', alert, 'bogus'), throwsArgumentError);
    },
  );
  test(
    'locale, three theme modes and local profile draft survive preferences reload',
    () async {
      final prefs = AppPreferences.instance;
      await prefs.set('language', true);
      await prefs.setTheme(ThemeMode.system);
      await prefs.saveLocalName('Offline name');
      prefs.reset();
      await prefs.load();
      expect(prefs.english, isTrue);
      expect(prefs.text('ข้อความ'), 'Messages');
      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.displayName, 'Offline name');
      await prefs.setTheme(ThemeMode.dark);
      prefs.reset();
      await prefs.load();
      expect(prefs.themeMode, ThemeMode.dark);
      await prefs.setTheme(ThemeMode.light);
      prefs.reset();
      await prefs.load();
      expect(prefs.themeMode, ThemeMode.light);
    },
  );

  testWidgets('all five tabs remain in one route and SOS has no back or role switch', (tester) async {
    final tabs = TabMessages(db);
    await tester.pumpWidget(MaterialApp(home: NearbyTestScreen(nearbyService: tabs.nearbyService, messageService: tabs)));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    for (final entry in [(1, 'ข้อความ'), (2, 'SOS'), (3, 'คิวส่ง'), (4, 'ฉัน'), (0, 'ใกล้ฉัน')]) {
      await tester.tap(find.text(entry.$2).last);
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, entry.$1);
      expect(navigator.canPop(), isFalse);
      if (entry.$1 == 1) expect(find.byType(MessagesScreen), findsOneWidget);
      if (entry.$1 == 2) {
        expect(find.byType(SosScreen), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
        expect(find.text('หน่วยกู้ภัย'), findsNothing);
      }
      if (entry.$1 == 3) expect(find.byType(OutboxQueue), findsOneWidget);
      if (entry.$1 == 4) expect(find.byType(SettingsPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'MessagesScreen preview shows clean human-readable text instead of [SOS + UUID] marker',
    (tester) async {
      service.messages = [
        MessageModel(
          id: '1',
          senderId: 'a',
          senderName: 'Alice',
          receiverId: 'me',
          text:
              '[SOS 302d7f97-1c66-4b20-8832-5d593f7e31f5 / pending]\n'
              'พร้อมเข้าไปช่วยเหลือ • รอการยืนยันจากคุณ\n'
              'กรุณาตอบกลับเพื่อนัดหมายและยืนยันรายละเอียด',
          timestamp: DateTime.utc(2026, 10, 5),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesScreen(service: service, onNearby: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('พร้อมเข้าไปช่วยเหลือ'), findsOneWidget);
      expect(find.textContaining('[SOS'), findsNothing);
      expect(find.textContaining('302d7f97'), findsNothing);
    },
  );
}
