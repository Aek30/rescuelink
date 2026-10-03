import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/media_service.dart';
import 'package:rescuelink/services/nearby_service.dart';

class NativeFake extends Fake implements Nearby {}

class MediaTransport extends NearbyService {
  MediaTransport() : super(nearby: NativeFake());
  final packets = <Map<String, dynamic>>[];
  int sends = 0;
  @override
  Future<void> sendMessage(String endpointId, String payload) async {
    packets.add(jsonDecode(payload));
  }

  @override
  Future<int> sendFile(String endpointId, String filePath) async => ++sends;
  @override
  Future<void> stopAll() async {}
}

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late LocalDatabaseService db;
  late MediaTransport transport;
  late MediaService service;
  late File source;
  late MediaFile media;
  int notices = 0;
  Future<void> settle() async {
    for (var i = 0; i < 100; i++) {
      if (service.getCached(media.mediaId)?.status == MediaStatus.received ||
          service.getCached(media.mediaId)?.status == MediaStatus.failed) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Receive did not finish');
  }

  setUp(() async {
    notices = 0;
    dir = await Directory.systemTemp.createTemp('media-test-');
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${dir.path}/db.sqlite',
    );
    transport = MediaTransport();
    source = File('${dir.path}/source.png');
    await source.writeAsBytes([1, 2, 3, 4, 5]);
    media = MediaFile(
      mediaId: '11111111-1111-4111-8111-111111111111',
      messageId: '22222222-2222-4222-8222-222222222222',
      senderId: 'sender',
      senderName: 'Sender',
      receiverId: 'receiver',
      fileName: 'photo.png',
      mimeType: 'image/png',
      fileSize: 5,
      checksum: sha256.convert([1, 2, 3, 4, 5]).toString(),
      localPath: source.path,
      createdAt: DateTime.utc(2026, 9, 30),
    );
    service = MediaService(
      nearby: transport,
      database: db,
      getEndpointForPeer: (_) => 'endpoint',
      directoryProvider: () async => dir,
      ackTimeout: const Duration(milliseconds: 20),
    );
    service.onReceived = (_) => notices++;
  });
  tearDown(() async {
    service.dispose();
    transport.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });
  test(
    'FILE start and init cannot finalize until SUCCESS; duplicate notifies once',
    () async {
      await service.initialize('receiver');
      transport.onFilePayloadStarted!('endpoint', 1, source.path);
      await service.handleMediaInit(
        'endpoint',
        jsonDecode(media.toInitJson(nearbyPayloadId: 1)),
      );
      expect(service.getCached(media.mediaId)!.status, MediaStatus.receiving);
      expect(await db.getMessages(), isEmpty);
      transport.onFileTransferSuccess!('endpoint', 1);
      await settle();
      expect(service.getCached(media.mediaId)!.status, MediaStatus.received);
      expect(notices, 1);
      await service.handleMediaInit(
        'endpoint',
        jsonDecode(media.toInitJson(nearbyPayloadId: 2)),
      );
      expect((await db.getMessages()).length, 1);
      expect(notices, 1);
      expect(transport.packets.last['success'], true);
    },
  );
  test(
    'SUCCESS before init is retained and verified after metadata arrives',
    () async {
      await service.initialize('receiver');
      transport.onFilePayloadStarted!('endpoint', 1, source.path);
      transport.onFileTransferSuccess!('endpoint', 1);
      await service.handleMediaInit(
        'endpoint',
        jsonDecode(media.toInitJson(nearbyPayloadId: 1)),
      );
      await settle();
      expect(service.getCached(media.mediaId)!.status, MediaStatus.received);
      expect(
        File(service.getCached(media.mediaId)!.localPath).existsSync(),
        true,
      );
    },
  );
  test('corrupt file does not enter chat or send success ACK', () async {
    await service.initialize('receiver');
    await source.writeAsBytes([9, 9]);
    await service.handleMediaInit(
      'endpoint',
      jsonDecode(media.toInitJson(nearbyPayloadId: 1)),
    );
    transport.onFilePayloadStarted!('endpoint', 1, source.path);
    transport.onFileTransferSuccess!('endpoint', 1);
    await settle();
    expect(service.getCached(media.mediaId)!.status, MediaStatus.failed);
    expect(await db.getMessages(), isEmpty);
    expect(transport.packets.last['success'], false);
  });
  test('completed receive survives DB close and service restart', () async {
    await service.initialize('receiver');
    await service.handleMediaInit(
      'endpoint',
      jsonDecode(media.toInitJson(nearbyPayloadId: 1)),
    );
    transport.onFilePayloadStarted!('endpoint', 1, source.path);
    transport.onFileTransferSuccess!('endpoint', 1);
    await settle();
    service.dispose();
    await db.close();
    service = MediaService(
      nearby: transport,
      database: db,
      getEndpointForPeer: (_) => 'endpoint',
      directoryProvider: () async => dir,
    );
    await service.initialize('receiver');
    expect(service.getCached(media.mediaId)!.status, MediaStatus.received);
    expect(
      await File(service.getCached(media.mediaId)!.localPath).readAsBytes(),
      [1, 2, 3, 4, 5],
    );
    expect((await db.getMessages()).single.timestamp, media.createdAt);
  });
  test(
    'lost ACK times out; wrong peer cannot acknowledge; retry keeps IDs',
    () async {
      await db.insertMediaFile(media);
      await db.insertMessage(
        MessageModel(
          id: media.messageId,
          senderId: 'sender',
          senderName: 'Sender',
          receiverId: 'receiver',
          text: media.mediaId,
          timestamp: media.createdAt,
          type: MessageType.media,
        ),
      );
      await service.initialize('sender');
      await service.retryMedia(media.mediaId);
      transport.onFileTransferSuccess!('endpoint', 1);
      final ack =
          jsonDecode(
                MediaAck(
                  mediaId: media.mediaId,
                  messageId: media.messageId,
                  receiverId: 'receiver',
                  success: true,
                ).toJson(),
              )
              as Map<String, dynamic>;
      await service.handleMediaAck(ack, peerId: 'imposter');
      expect(service.getCached(media.mediaId)!.status, MediaStatus.sending);
      for (var i = 0; i < 100 && service.getCached(media.mediaId)!.status == MediaStatus.sending; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(service.getCached(media.mediaId)!.status, MediaStatus.paused);
      await service.retryMedia(media.mediaId);
      expect(transport.sends, 2);
      await service.handleMediaAck(ack, peerId: 'receiver');
      expect(service.getCached(media.mediaId)!.status, MediaStatus.delivered);
      expect((await db.getMessages()).length, 1);
    },
  );
}
