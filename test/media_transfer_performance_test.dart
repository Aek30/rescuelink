import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/services/media_file_preparation.dart';
import 'package:rescuelink/services/media_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/models/media_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'media_service_test.dart' show MediaTransport;

void main() {
  sqfliteFfiInit();

  test(
    'streaming preparation preserves multi-chunk video bytes and checksum',
    () async {
      final dir = await Directory.systemTemp.createTemp('media-prepare-');
      addTearDown(() => dir.delete(recursive: true));
      final bytes = List<int>.generate(2 * 1024 * 1024 + 13, (i) => i % 251);
      final source = await File('${dir.path}/source.mp4').writeAsBytes(bytes);
      final destination = '${dir.path}/saved.mp4';
      final prepared = await prepareMediaFile(source.path, destination);
      expect(prepared.size, bytes.length);
      expect(prepared.checksum, sha256.convert(bytes).toString());
      expect(await checksumMediaFile(destination), prepared.checksum);
      await source.delete();
      expect(await File(destination).readAsBytes(), bytes);
    },
  );

  test('failed preparation removes the incomplete destination', () async {
    final dir = await Directory.systemTemp.createTemp('media-prepare-fail-');
    addTearDown(() => dir.delete(recursive: true));
    final destination = '${dir.path}/partial.mp4';
    await expectLater(
      prepareMediaFile('${dir.path}/missing.mp4', destination),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(destination).exists(), isFalse);
  });

  test(
    'next queued file starts on completion without waiting for retry timer or ACK',
    () async {
      final dir = await Directory.systemTemp.createTemp('media-queue-');
      final db = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final transport = MediaTransport();
      final service = MediaService(
        nearby: transport,
        database: db,
        directoryProvider: () async => dir,
        getEndpointForPeer: (_) => 'endpoint',
      );
      addTearDown(() async {
        service.dispose();
        transport.dispose();
        await db.close();
        await dir.delete(recursive: true);
      });
      await service.initialize('sender');
      final source = await File(
        '${dir.path}/source.jpg',
      ).writeAsBytes([1, 2, 3]);
      Future<MediaFile> send() => service.sendFile(
        sourcePath: source.path,
        fileName: 'photo.jpg',
        senderName: 'Sender',
        receiverId: 'receiver',
      );
      Future<void> waitFor(bool Function() done) async {
        for (var i = 0; i < 200; i++) {
          if (done()) return;
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        fail('Queue did not advance within one second');
      }

      final first = await send();
      final second = await send();
      final third = await send();
      await waitFor(() => transport.packets.length == 1);
      expect(transport.sends, 1);
      expect(service.getCached(second.mediaId)!.status, MediaStatus.localReady);
      transport.onFileTransferSuccess!('endpoint', 1);
      await waitFor(() => transport.packets.length == 2);
      expect(transport.sends, 2);
      expect(service.getCached(first.mediaId)!.status, MediaStatus.sending);
      expect(service.getCached(second.mediaId)!.status, MediaStatus.sending);
      expect(service.getCached(third.mediaId)!.status, MediaStatus.localReady);
      transport.onFileTransferSuccess!('endpoint', 2);
      await waitFor(() => transport.packets.length == 3);
      expect(transport.sends, 3);
      expect(service.getCached(third.mediaId)!.status, MediaStatus.sending);
    },
  );
}
