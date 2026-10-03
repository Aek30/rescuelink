import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/media_upload_service.dart';

class CloudFake implements MediaCloud {
  @override
  String? owner = 'owner';
  bool fail = false;
  int uploads = 0;
  Completer<void>? verification;
  @override
  Future<void> upload(
    MediaFile media,
    String owner,
    void Function(int) progress,
  ) async {
    uploads++;
    progress(media.fileSize);
    if (fail) throw const SocketException('offline');
  }

  @override
  Future<void> verify(MediaFile media, String owner) async {
    await verification?.future;
  }

  @override
  Future<String> signedUrl(String path, String owner) async =>
      'https://example.invalid/private';
}

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late LocalDatabaseService db;
  late MediaFile media;
  late CloudFake cloud;
  late MediaUploadService uploads;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('upload-test-');
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${dir.path}/db.sqlite',
    );
    final file = File('${dir.path}/image.png');
    await file.writeAsBytes([1, 2, 3]);
    media = MediaFile(
      mediaId: 'media',
      messageId: 'message',
      senderId: 'me',
      senderName: 'Me',
      receiverId: 'peer',
      fileName: 'image.png',
      mimeType: 'image/png',
      fileSize: 3,
      checksum: sha256.convert([1, 2, 3]).toString(),
      localPath: file.path,
      createdAt: DateTime.now(),
      status: MediaStatus.delivered,
    );
    cloud = CloudFake();
    uploads = MediaUploadService(
      database: db,
      cloud: cloud,
      lookup: (_) => media,
    );
    await uploads.initialize();
  });
  tearDown(() async {
    uploads.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });
  test(
    '100 percent uploaded is not ready until cloud verification passes',
    () async {
      cloud.verification = Completer<void>();
      final sending = uploads.enqueue(media.mediaId);
      for (
        var i = 0;
        i < 100 &&
            uploads.forMedia(media.mediaId)?.state != UploadState.verifying;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(uploads.forMedia(media.mediaId)!.bytes, 3);
      expect(uploads.forMedia(media.mediaId)!.state, UploadState.verifying);
      await expectLater(uploads.accessUrl(media.mediaId), throwsStateError);
      cloud.verification!.complete();
      await sending;
      expect(uploads.forMedia(media.mediaId)!.state, UploadState.ready);
      expect(media.status, MediaStatus.delivered);
    },
  );
  test(
    'failure is durable; restart does not upload until selected; retry uses same ID',
    () async {
      cloud.fail = true;
      await uploads.enqueue(media.mediaId);
      expect(uploads.forMedia(media.mediaId)!.state, UploadState.failed);
      uploads.dispose();
      await db.close();
      uploads = MediaUploadService(
        database: db,
        cloud: cloud,
        lookup: (_) => media,
      );
      await uploads.initialize();
      await uploads.retryPending();
      expect(cloud.uploads, 1);
      expect(uploads.forMedia(media.mediaId)!.state, UploadState.failed);
      cloud.fail = false;
      await uploads.enqueue(media.mediaId);
      expect(cloud.uploads, 2);
      expect(uploads.jobs.length, 1);
      expect(uploads.forMedia(media.mediaId)!.state, UploadState.ready);
    },
  );
  test(
    'account switch cannot expose the previous account upload or reuse its queue',
    () async {
      await uploads.enqueue(media.mediaId);
      cloud.owner = 'other';
      expect(uploads.forMedia(media.mediaId), isNull);
      await expectLater(uploads.accessUrl(media.mediaId), throwsStateError);
      await expectLater(uploads.enqueue(media.mediaId), throwsStateError);
      expect(cloud.uploads, 1);
    },
  );
  test('local file corruption prevents upload', () async {
    await File(media.localPath).writeAsBytes([7, 7, 7]);
    await uploads.enqueue(media.mediaId);
    expect(cloud.uploads, 0);
    expect(uploads.forMedia(media.mediaId)!.state, UploadState.failed);
  });
}
