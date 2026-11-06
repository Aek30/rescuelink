import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/chat_location_message.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/models/offline_map_data.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/models/responder_update.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/services/media_service.dart';
import 'package:rescuelink/services/sos_location_service.dart';
import 'package:rescuelink/widgets/chat_location_bubble.dart';
import 'sos_screen_test.dart' show UiMessages;

class _Messages extends UiMessages {
  final sentTexts = <String>[];
  @override
  Future<void> sendTextMessage({
    required String receiverId,
    required String text,
  }) async {
    sentTexts.add(text);
    messages.add(
      MessageModel(
        id: 'location-${sentTexts.length}',
        senderId: 'me',
        senderName: 'Me',
        receiverId: receiverId,
        text: text,
        timestamp: DateTime.now().toUtc(),
      ),
    );
    notifyListeners();
  }
}

class _Media extends MediaService {
  _Media(_Messages messages, this.photoPath)
    : super(
        nearby: messages.nearbyService,
        database: messages.database,
        getEndpointForPeer: (_) => null,
      );
  final String photoPath;
  int galleries = 0, cameras = 0, sentPhotos = 0;
  @override
  Future<MediaFile?> pickAndSend({
    required String senderName,
    required String receiverId,
  }) async {
    galleries++;
    return null;
  }

  @override
  Future<MediaFile?> captureAndSend({
    required String senderName,
    required String receiverId,
    required Future<bool> Function(String path) confirm,
  }) async {
    cameras++;
    if (await confirm(photoPath)) sentPhotos++;
    return null;
  }
}

class _Gps extends SosLocationService {
  final location = SosLocation(
    latitude: 14.036,
    longitude: 100.728,
    accuracy: 8,
    capturedAt: DateTime.now().toUtc(),
  );
  @override
  Future<SosLocation?> lastKnown() async => location;
  @override
  Future<SosLocation> capture() async => location;
}

void main() {
  test('shared location retains timestamps and is readable in chat previews', () {
    final fix = SosLocation(
      latitude: 14,
      longitude: 100,
      accuracy: 0,
      manuallySelected: true,
      capturedAt: DateTime.utc(2026),
    );
    final text = ChatLocationMessage.encode(fix);
    expect(text, startsWith('📍 แชร์ตำแหน่ง\nพิกัด: 14.0, 100.0'));
    expect(text, contains('https://www.google.com/maps?q=14.0,100.0'));
    expect(text, isNot(contains('rescuelink.location')));
    expect(ChatLocationMessage.parse(text)!.toMap(), fix.toMap());
    expect(ResponderUpdate.cleanDisplay(text), 'แชร์ตำแหน่ง');
    expect(ResponderUpdate.readableText(text), 'แชร์ตำแหน่ง');
    expect(
      ChatLocationMessage.parse(
        '{"type":"rescuelink.location","version":1,"location":{"latitude":999}}',
      ),
      isNull,
    );
    expect(ChatLocationMessage.parse('สวัสดี'), isNull);
  });
  testWidgets('received legacy and readable locations both render map cards', (
    tester,
  ) async {
    await tester.runAsync(OfflineMapData.load);
    const legacy =
        '{"type":"rescuelink.location","version":1,"location":'
        '{"latitude":14.0428697,"longitude":100.7336029,'
        '"accuracy":52.400001525878906,"capturedAt":"2026-11-01T14:43:30.447Z"}}';
    final location = ChatLocationMessage.parse(legacy)!;
    final readable = ChatLocationMessage.encode(location);
    expect(ChatLocationMessage.parse(readable)!.toMap(), location.toMap());
    final messages = _Messages();
    for (final text in [legacy, readable]) {
      messages.messages.add(
        MessageModel(
          id: 'received-${messages.messages.length}',
          senderId: 'peer',
          senderName: 'Phone B',
          receiverId: 'me',
          text: text,
          timestamp: DateTime.now().toUtc(),
        ),
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(service: messages, peerId: 'peer'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChatLocationBubble), findsNWidgets(2));
    expect(find.text(legacy), findsNothing);
    expect(find.text(readable), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    messages.dispose();
    messages.nearbyService.dispose();
  });
  for (final camera in [false, true]) {
    testWidgets('attachment menu and camera preserve draft; camera=$camera', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final folder = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('chat-camera-ui-'),
      ))!;
      final file = (await tester.runAsync(
        () => File('${folder.path}/photo.jpg').writeAsBytes([1, 2, 3]),
      ))!;
      final messages = _Messages();
      final media = _Media(messages, file.path);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            service: messages,
            peerId: 'peer',
            mediaService: media,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextField, 'พิมพ์ข้อความ');
      await tester.enterText(input, 'ข้อความที่ยังไม่ส่ง');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(find.byTooltip('ถ่ายรูป'), findsOneWidget);
      if (camera) {
        await tester.tap(find.byTooltip('ถ่ายรูป'));
        await tester.pumpAndSettle();
        expect(find.text('ตรวจรูปก่อนส่ง'), findsOneWidget);
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();
        expect(media.sentPhotos, 0);
        await tester.tap(find.byTooltip('ถ่ายรูป'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ส่งรูปนี้'));
        await tester.pumpAndSettle();
        expect(media.cameras, 2);
        expect(media.sentPhotos, 1);
      } else {
        await tester.tap(find.byTooltip('แนบไฟล์'));
        await tester.pumpAndSettle();
        expect(find.text('แกลเลอรี'), findsOneWidget);
        expect(find.text('ตำแหน่ง'), findsOneWidget);
        await tester.tap(find.text('แกลเลอรี'));
        await tester.pumpAndSettle();
        expect(media.galleries, 1);
      }
      expect(
        tester.widget<TextField>(input).controller!.text,
        'ข้อความที่ยังไม่ส่ง',
      );
      expect(messages.sentTexts, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      media.dispose();
      messages.dispose();
      messages.nearbyService.dispose();
      await tester.runAsync(() => folder.delete(recursive: true));
    });
  }

  testWidgets(
    'location is sent only after confirmation and renders a map card',
    (tester) async {
      await tester.runAsync(OfflineMapData.load);
      final messages = _Messages();
      final gps = _Gps();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            service: messages,
            peerId: 'peer',
            locationService: gps,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> open() async {
        await tester.tap(find.byTooltip('แนบไฟล์'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ตำแหน่ง'));
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.text('ส่งตำแหน่งนี้'), findsOneWidget);
      expect(messages.sentTexts, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(messages.sentTexts, isEmpty);
      await open();
      await tester.tap(find.text('ส่งตำแหน่งนี้'));
      await tester.pumpAndSettle();
      expect(messages.sentTexts, hasLength(1));
      expect(
        ChatLocationMessage.parse(messages.sentTexts.single)!.toMap(),
        gps.location.toMap(),
      );
      expect(find.byType(ChatLocationBubble), findsOneWidget);
      expect(find.text(messages.sentTexts.single), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      messages.dispose();
      messages.nearbyService.dispose();
    },
  );
}
