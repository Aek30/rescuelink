import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/services/media_upload_service.dart';
import 'package:rescuelink/widgets/outbox_queue.dart';

void main() {
  testWidgets('media queue shows image label without filename in details', (
    tester,
  ) async {
    final media = MediaFile(
      mediaId: 'image',
      messageId: 'message',
      senderId: 'me',
      senderName: 'Me',
      receiverId: 'peer',
      fileName: 'photo.png',
      mimeType: 'image/png',
      fileSize: 3,
      checksum: '',
      localPath: '/photo.png',
      createdAt: DateTime(2026),
    );
    final message = MessageModel(
      id: 'message',
      senderId: 'me',
      senderName: 'Me',
      receiverId: 'peer',
      text: 'image',
      timestamp: DateTime(2026),
      type: MessageType.media,
    );
    final upload = MediaUpload(mediaId: 'image', owner: 'owner');
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutboxQueue(
            messages: [message],
            mediaFiles: {'image': media},
            mediaUploads: {'image': upload},
            peers: const {'peer': 'Peer'},
            ready: true,
            busy: false,
            onRetry: () {},
          ),
        ),
      ),
    );
    await show();
    expect(find.text('ส่งรูปภาพ'), findsOneWidget);
    expect(find.text('รอการยืนยัน (1)'), findsOneWidget);
    await tester.tap(find.text('ส่งรูปภาพ'));
    await tester.pumpAndSettle();
    expect(find.text('ส่งรูปภาพ'), findsNWidgets(2));
    expect(find.textContaining(media.fileName), findsNothing);
    expect(
      find.text('รอสำรองข้อมูลเมื่อมีอินเทอร์เน็ตและเข้าสู่ระบบ'),
      findsOneWidget,
    );
    upload.state = UploadState.ready;
    await show();
    expect(find.text('สำรองแล้ว (1)'), findsOneWidget);
    expect(find.textContaining('ยังไม่ยืนยันการรับที่ปลายทาง'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
            cloudSyncedMessageIds: const {'sent'},
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
    expect(find.text('สำรองแล้ว (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('สำรองแล้ว (1)'));
    await tester.pumpAndSettle();
    expect(find.text('message-sent'), findsOneWidget);
    expect(find.text('message-synced'), findsNothing);
    expect(find.text('สำรองแล้ว • 1 ข้อความ'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'Supabase|Cloud', caseSensitive: false)),
      findsNothing,
    );
    await tester.tap(find.text('message-sent'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังไม่ยืนยันการรับที่ปลายทาง'), findsOneWidget);
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
