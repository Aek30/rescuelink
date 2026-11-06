import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/messages_screen.dart';
import 'package:rescuelink/services/chat_store.dart';
import 'package:rescuelink/services/chat_sync_service.dart';
import 'chat_sync_test.dart' show MemoryChatCloud;
import 'sos_screen_test.dart' show UiMessages;

class RetrySync extends ChatSyncService {
  RetrySync(super.store, super.cloud);
  int retries = 0;
  @override
  Future<void> sync() async {
    retries++;
  }
}

void main() {
  testWidgets('retry keeps warning and layout stable without a loading strip', (
    tester,
  ) async {
    final messages = UiMessages();
    final previous = ChatSyncCoordinator.instance.current;
    final sync = RetrySync(ChatStore(messages.database), MemoryChatCloud())
      ..error = 'เชื่อมต่อ Cloud ไม่สำเร็จ';
    ChatSyncCoordinator.instance.current = sync;
    addTearDown(() {
      ChatSyncCoordinator.instance.current = previous;
      sync.dispose();
      messages.dispose();
      messages.nearbyService.dispose();
    });
    Future<void> render() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesScreen(service: messages, onNearby: () {}),
        ),
      ),
    );
    await render();
    expect(find.text('เชื่อมต่อ Cloud ไม่สำเร็จ'), findsNothing);
    sync.busy = true;
    await render();
    expect(find.text('เชื่อมต่อ Cloud ไม่สำเร็จ'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('กำลังกู้คืนประวัติแชทของบัญชีนี้…'), findsNothing);
    sync.busy = false;
    sync.error = null;
    sync.lastSuccess = DateTime.now();
    await render();
    expect(find.text('เชื่อมต่อ Cloud ไม่สำเร็จ'), findsNothing);
    sync.busy = true;
    await render();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('ยังไม่มีข้อความ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final loading in [true, false]) {
    testWidgets(
      'empty history shows cloud ${loading ? 'loading' : 'empty'} state without inline sync error',
      (tester) async {
        final messages = UiMessages();
        final previous = ChatSyncCoordinator.instance.current;
        final sync = RetrySync(ChatStore(messages.database), MemoryChatCloud());
        sync.busy = loading;
        sync.error = loading ? null : 'เชื่อมต่อ Cloud ไม่สำเร็จ';
        ChatSyncCoordinator.instance.current = sync;
        addTearDown(() {
          ChatSyncCoordinator.instance.current = previous;
          sync.dispose();
          messages.dispose();
          messages.nearbyService.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessagesScreen(service: messages, onNearby: () {}),
            ),
          ),
        );
        if (loading) {
          expect(find.text('ยังไม่มีข้อความ'), findsNothing);
          expect(
            find.text('กำลังกู้คืนประวัติแชทของบัญชีนี้…'),
            findsOneWidget,
          );
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
        } else {
          expect(find.text('เชื่อมต่อ Cloud ไม่สำเร็จ'), findsNothing);
          expect(find.text('ยังไม่มีข้อความ'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
