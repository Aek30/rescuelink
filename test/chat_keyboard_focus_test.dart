import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'sos_screen_test.dart' show UiTransport;

class MockChatMessages extends MessageService {
  MockChatMessages(LocalDatabaseService db)
    : super(nearbyService: UiTransport(), database: db) {
    myId = 'me';
    peers = {'peer': 'Peer'};
  }
  final List<String> sentTexts = [];

  @override
  Future<void> sendTextMessage({
    required String receiverId,
    required String text,
  }) async {
    sentTexts.add(text);
  }

  @override
  Future<void> retry() async {}
}

void main() {
  sqfliteFfiInit();
  late LocalDatabaseService db;
  late MockChatMessages service;

  setUp(() {
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    LocalDatabaseService.instance = db;
    service = MockChatMessages(db);
  });

  tearDown(() async {
    service.dispose();
    service.nearbyService.dispose();
    await db.close();
  });

  testWidgets(
    'sending message while focused keeps focus and clears input field',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ChatScreen(service: service, peerId: 'peer')),
      );
      await tester.pumpAndSettle();

      final inputField = find.widgetWithText(TextField, 'พิมพ์ข้อความ');
      expect(inputField, findsOneWidget);

      // Focus the text field and enter text
      await tester.tap(inputField);
      await tester.pump();
      await tester.enterText(inputField, 'ข้อความแรก');
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.descendant(of: inputField, matching: find.byType(EditableText)),
      );
      expect(editableText.focusNode.hasFocus, isTrue);

      // Tap send button
      final sendButton = find.byTooltip('ส่งข้อความ');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Verify message was sent
      expect(service.sentTexts, ['ข้อความแรก']);

      // Verify input field was cleared
      expect(find.text('ข้อความแรก'), findsNothing);

      // Verify focus is RETAINED so keyboard stays open
      expect(editableText.focusNode.hasFocus, isTrue);

      // Enter and send second message immediately
      await tester.enterText(inputField, 'ข้อความสอง');
      await tester.pump();
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(service.sentTexts, ['ข้อความแรก', 'ข้อความสอง']);
      expect(editableText.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'sending message when not focused does NOT force focus',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ChatScreen(service: service, peerId: 'peer')),
      );
      await tester.pumpAndSettle();

      final inputField = find.widgetWithText(TextField, 'พิมพ์ข้อความ');
      await tester.enterText(inputField, 'ข้อความจากภายนอก');
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.descendant(of: inputField, matching: find.byType(EditableText)),
      );

      // Ensure focus is explicitly removed
      editableText.focusNode.unfocus();
      await tester.pump();
      expect(editableText.focusNode.hasFocus, isFalse);

      // Tap send button
      final sendButton = find.byTooltip('ส่งข้อความ');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(service.sentTexts, ['ข้อความจากภายนอก']);
      // Should NOT force request focus when user was not focused
      expect(editableText.focusNode.hasFocus, isFalse);
    },
  );
}
