import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/services/media_service.dart';
import 'package:rescuelink/widgets/media_bubble.dart';
import 'sos_screen_test.dart' show UiMessages;

class SearchMedia extends MediaService {
  SearchMedia(UiMessages messages) : super(nearby: messages.nearbyService,
    database: messages.database, getEndpointForPeer: (_) => null);
  final items = <String, MediaFile>{};
  @override
  MediaFile? getCached(String mediaId) => items[mediaId];
}

void main() {
  testWidgets('searches text and media filenames; filters image, video and pending', (tester) async {
    final messages = UiMessages();
    final media = SearchMedia(messages);
    final dir = Directory.systemTemp.createTempSync('search-test-');
    final file = File('${dir.path}/image.png');
    file.writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII='));
    addTearDown(() async {
      messages.dispose(); media.dispose(); messages.nearbyService.dispose();
      dir.deleteSync(recursive: true);
    });
    final now = DateTime.now();
    messages.messages = [
      MessageModel(id: 'text', senderId: 'peer', senderName: 'Peer', receiverId: 'me',
        text: 'ช่วยส่งน้ำ', timestamp: now),
      MessageModel(id: 'image-message', senderId: 'peer', senderName: 'Peer', receiverId: 'me',
        text: 'image', timestamp: now, type: MessageType.media),
      MessageModel(id: 'video-message', senderId: 'me', senderName: 'Me', receiverId: 'peer',
        text: 'video', timestamp: now, type: MessageType.media),
    ];
    media.items['image'] = MediaFile(mediaId: 'image', messageId: 'image-message',
      senderId: 'peer', senderName: 'Peer', receiverId: 'me', fileName: 'FloodPhoto.png',
      mimeType: 'image/png', fileSize: 1, checksum: '', localPath: file.path,
      createdAt: now, status: MediaStatus.received);
    media.items['video'] = MediaFile(mediaId: 'video', messageId: 'video-message',
      senderId: 'me', senderName: 'Me', receiverId: 'peer', fileName: 'Road.mp4',
      mimeType: 'video/mp4', fileSize: 1, checksum: '', localPath: '',
      createdAt: now, status: MediaStatus.paused);
    await tester.pumpWidget(MaterialApp(home: ChatScreen(service: messages, peerId: 'peer', mediaService: media)));
    await tester.pumpAndSettle();
    expect(find.text('เชื่อมต่อแล้ว • ถึงปลายทาง = บันทึกบนเครื่องรับแล้ว'), findsNothing);
    expect(find.textContaining('ยังไม่ทราบบทบาท'), findsOneWidget);
    final search = find.widgetWithText(TextField, 'ค้นหาข้อความหรือชื่อไฟล์');
    await tester.enterText(search, 'floodphoto');
    await tester.pumpAndSettle();
    expect(find.byType(MediaBubble), findsOneWidget);
    expect(find.text('ช่วยส่งน้ำ'), findsNothing);
    await tester.enterText(search, 'ช่วย');
    await tester.pumpAndSettle();
    expect(find.text('ช่วยส่งน้ำ'), findsOneWidget);
    expect(find.byType(MediaBubble), findsNothing);
    await tester.enterText(search, '');
    Future<void> filter(String label) async {
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }
    await filter('รูปภาพ');
    expect(tester.widget<MediaBubble>(find.byType(MediaBubble)).media!.isImage, true);
    await filter('วิดีโอ');
    expect(tester.widget<MediaBubble>(find.byType(MediaBubble)).media!.isVideo, true);
    await filter('ค้างส่ง');
    expect(find.byType(MediaBubble), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
