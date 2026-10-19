import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/services/media_service.dart';
import 'package:rescuelink/services/media_upload_service.dart';
import 'package:rescuelink/services/video_preview_cache.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/widgets/chat_message_bubble.dart';
import 'package:rescuelink/widgets/media_bubble.dart';
import 'sos_screen_test.dart' show UiMessages;
import 'media_upload_test.dart' show CloudFake;

class ChatMedia extends MediaService {
  ChatMedia(UiMessages service)
    : super(
        nearby: service.nearbyService,
        database: service.database,
        getEndpointForPeer: (_) => null,
      );
  final items = <String, MediaFile>{};
  int retries = 0;
  void refresh() => notifyListeners();
  late final _testUploads = MediaUploadService(
    database: database,
    cloud: CloudFake(),
    lookup: getCached,
  );
  @override
  MediaUploadService get uploads => _testUploads;
  @override
  MediaFile? getCached(String id) => items[id];
  @override
  Future<void> retryMedia(String id) async {
    retries++;
  }
}

MediaFile video({
  String path = '',
  MediaStatus status = MediaStatus.delivered,
  int retries = 0,
}) => MediaFile(
  mediaId: 'video',
  messageId: 'm',
  senderId: 'me',
  senderName: 'ฉัน',
  receiverId: 'peer',
  fileName: 'secret-internal-hash-999.mp4',
  mimeType: 'video/mp4',
  fileSize: 1,
  checksum: 'checksum',
  localPath: path,
  createdAt: DateTime(2026),
  status: status,
  retryCount: retries,
);

void main() {
  testWidgets(
    'video fallback stays light and chat fits a phone in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = UiMessages();
      final media = ChatMedia(messages);
      addTearDown(() {
        media.dispose();
        messages.dispose();
        messages.nearbyService.dispose();
      });
      media.items['video'] = video(path: 'missing-video.mp4');
      messages.peers['relay'] = 'อาสาสมัครชื่อยาวมาก';
      messages.receivedRoutes['reply'] = ['peer', 'relay', 'me'];
      messages.messages = [
        MessageModel(
          id: 'reply',
          senderId: 'peer',
          senderName: 'ผู้ติดต่อ',
          receiverId: 'me',
          text: 'ขอบคุณค่ะ ได้รับของแล้ว',
          timestamp: DateTime(2026, 10, 18, 12),
        ),
        MessageModel(
          id: 'm',
          senderId: 'me',
          senderName: 'ฉัน',
          receiverId: 'peer',
          text: 'video',
          timestamp: DateTime(2026, 10, 18, 12, 1),
          type: MessageType.media,
          status: MessageStatus.delivered,
        ),
        MessageModel(
          id: 'short',
          senderId: 'me',
          senderName: 'ฉัน',
          receiverId: 'peer',
          text: 'ยินดีค่ะ',
          timestamp: DateTime(2026, 10, 18, 12, 2),
          status: MessageStatus.delivered,
        ),
      ];
      if (const bool.fromEnvironment('CHAT_CAPTURE')) {
        await (FontLoader(
          'NotoSansThai',
        )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      }
      final capture = GlobalKey();
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? RescueTheme.dark : RescueTheme.light,
            home: RepaintBoundary(
              key: capture,
              child: ChatScreen(
                service: messages,
                peerId: 'peer',
                mediaService: media,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
        expect(find.textContaining('secret-internal'), findsNothing);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CHAT_CAPTURE')) {
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('output/chat-ui').create(recursive: true);
            await File(
              'output/chat-ui/${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    },
  );
  testWidgets('short bubbles hug content and maintain AA text contrast', (
    tester,
  ) async {
    for (final theme in [RescueTheme.light, RescueTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: ChatMessageBubble(
              isMine: true,
              time: '12:00',
              status: ChatDeliveryState.delivered,
              child: Text('สวัสดี'),
            ),
          ),
        ),
      );
      final container = find
          .descendant(
            of: find.byType(ChatMessageBubble),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(container).width, lessThan(240));
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      final badge = Color.alphaBlend(
        Colors.white.withValues(alpha: .2),
        ChatMessageBubble.outgoing,
      );
      expect(
        (1.05) / (badge.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('long relay names and retry targets fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
        home: Scaffold(
          body: ChatMessageBubble(
            isMine: true,
            time: '12:00',
            status: ChatDeliveryState.failed,
            onRetry: () {},
            route: const ['me', 'relay', 'peer'],
            peers: const {'relay': 'ผู้ช่วยเหลือชื่อยาวมากที่สุด'},
            child: const Text('ข้อความ'),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byTooltip('ส่งใหม่')), const Size(48, 48));
    expect(find.textContaining('ส่งผ่าน'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cloud retries replace delivery checks without exposing raw errors',
    (tester) async {
      final messages = UiMessages();
      final media = ChatMedia(messages);
      addTearDown(() {
        media.dispose();
        messages.dispose();
        messages.nearbyService.dispose();
      });
      media.items['video'] = video();
      media.uploads.jobs['video'] = MediaUpload(
        mediaId: 'video',
        owner: 'owner',
        state: UploadState.failed,
        error: 'AuthRetryableFetchException',
        nextAttempt: DateTime.now().add(const Duration(minutes: 1)),
      );
      messages.error = 'raw exception';
      messages.messages = [
        MessageModel(
          id: 'm',
          senderId: 'me',
          senderName: 'ฉัน',
          receiverId: 'peer',
          text: 'video',
          timestamp: DateTime(2026),
          type: MessageType.media,
          status: MessageStatus.delivered,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          home: ChatScreen(
            service: messages,
            peerId: 'peer',
            mediaService: media,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('raw exception'), findsNothing);
      expect(find.textContaining('secret-internal'), findsNothing);
      expect(find.text('ส่งวิดีโอ'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNothing);
      media.items['video'] = video(status: MediaStatus.failed, retries: 5);
      media.refresh();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      await tester.tap(find.byTooltip('ส่งใหม่'));
      await tester.pumpAndSettle();
      expect(media.retries, 1);
      await tester.longPress(find.byType(MediaBubble));
      await tester.pumpAndSettle();
      expect(find.text('ซิงก์สื่อไป Cloud'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('video covers share work and persist across cache instances', () async {
    final dir = await Directory.systemTemp.createTemp('chat-preview-');
    addTearDown(() => dir.delete(recursive: true));
    final source = File('${dir.path}/video.mp4');
    await source.writeAsBytes([1]);
    await File(
      '${source.path}.preview.json',
    ).writeAsString(jsonEncode({'durationMs': 12000}));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('plugins.justsoft.xyz/video_thumbnail');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    int calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return Uint8List.fromList([1, 2, 3]);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final cache = VideoPreviewCache();
    final first = cache.prepare(video(path: source.path));
    expect(identical(first, cache.prepare(video(path: source.path))), isTrue);
    final result = await first;
    expect(result.duration, const Duration(seconds: 12));
    expect(await File(result.path!).exists(), isTrue);
    expect(calls, 1);
    final restored = await VideoPreviewCache().prepare(
      video(path: source.path),
    );
    expect(restored.path, result.path);
    expect(calls, 1);
  });
}
