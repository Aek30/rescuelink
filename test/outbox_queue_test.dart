import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/widgets/outbox_queue.dart';

void main() {
  testWidgets('filters delivery states and opens details on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messages = MessageStatus.values
        .map(
          (status) => MessageModel(
            id: status.name,
            senderId: 'me',
            senderName: 'Me',
            receiverId: 'peer',
            text: 'message-${status.name}',
            timestamp: DateTime(2026, 9, 28),
            status: status,
          ),
        )
        .toList();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutboxQueue(
            messages: messages,
            peers: const {'peer': 'Rescue B'},
            ready: true,
            busy: false,
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.text('รอการยืนยัน (2)'), findsOneWidget);
    expect(find.text('ถึงเครื่องรับแล้ว (1)'), findsOneWidget);
    expect(find.text('ซิงก์แล้ว (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('ถึงเครื่องรับแล้ว (1)'));
    await tester.pumpAndSettle();
    expect(find.text('message-pending'), findsNothing);
    expect(find.text('message-sent'), findsNothing);
    expect(find.text('message-delivered'), findsOneWidget);
    await tester.tap(find.text('message-delivered'));
    await tester.pumpAndSettle();
    expect(find.text('รายละเอียดข้อความ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
