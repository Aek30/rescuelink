import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/media_service.dart';
import 'package:rescuelink/models/message_model.dart';
import 'media_service_test.dart' show MediaTransport;

class _Picker extends Fake implements ImagePicker {
  XFile? photo;
  @override
  Future<XFile?> pickMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
  }) async {
    expect(requestFullMetadata, isFalse);
    expect(maxWidth, 1920);
    expect(maxHeight, 1920);
    expect(imageQuality, 85);
    return photo;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.camera);
    expect(requestFullMetadata, isFalse);
    return photo;
  }
}

void main() {
  sqfliteFfiInit();
  test(
    'cancel sends nothing; confirmed camera and gallery use durable offline media queue',
    () async {
      final folder = await Directory.systemTemp.createTemp('camera-send-');
      final source = await File(
        '${folder.path}/camera.jpg',
      ).writeAsBytes([1, 2, 3, 4]);
      final picker = _Picker()..photo = XFile(source.path);
      final db = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final transport = MediaTransport();
      final service = MediaService(
        nearby: transport,
        database: db,
        getEndpointForPeer: (_) => null,
        directoryProvider: () async => folder,
        imagePicker: picker,
      );
      await service.initialize('me');
      expect(
        await service.captureAndSend(
          senderName: 'Me',
          receiverId: 'peer',
          confirm: (_) async => false,
        ),
        isNull,
      );
      expect(await db.getMessages(), isEmpty);
      final camera = await service.captureAndSend(
        senderName: 'Me',
        receiverId: 'peer',
        confirm: (_) async => true,
      );
      final gallery = await service.pickAndSend(
        senderName: 'Me',
        receiverId: 'peer',
      );
      expect(camera!.localPath, isNot(source.path));
      expect(gallery!.messageId, isNot(camera.messageId));
      await source.delete();
      expect(await File(camera.localPath).readAsBytes(), [1, 2, 3, 4]);
      final messages = await db.getMessages();
      expect(messages, hasLength(2));
      expect(
        messages.every((message) => message.type == MessageType.media),
        isTrue,
      );
      expect(transport.sends, 0);
      service.dispose();
      transport.dispose();
      await db.close();
      await folder.delete(recursive: true);
    },
  );

  test(
    'video compressor shrinks large videos before size check and cleans up temp file',
    () async {
      final folder = await Directory.systemTemp.createTemp('video-compress-');
      final rawVideo = await File(
        '${folder.path}/clip.mov',
      ).writeAsBytes(List<int>.filled(6 * 1024 * 1024, 7));
      final db = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final transport = MediaTransport();
      final service = MediaService(
        nearby: transport,
        database: db,
        getEndpointForPeer: (_) => null,
        getRelayPathForPeer: (_) => ['me', 'hop', 'peer'],
        directoryProvider: () async => folder,
        videoCompressor: (inputPath, outputPath) async {
          expect(inputPath, rawVideo.path);
          await File(outputPath).writeAsBytes([10, 20, 30, 40]);
          return outputPath;
        },
      );
      await service.initialize('me');
      final sent = await service.sendFile(
        sourcePath: rawVideo.path,
        fileName: 'clip.mov',
        senderName: 'Me',
        receiverId: 'peer',
      );
      expect(sent.fileName, 'clip.mp4');
      expect(sent.mimeType, 'video/mp4');
      expect(sent.fileSize, 4);
      expect(await File(sent.localPath).readAsBytes(), [10, 20, 30, 40]);
      expect(
        folder
            .listSync()
            .where((entry) => entry.path.contains('tmp_compress_')),
        isEmpty,
      );
      service.dispose();
      transport.dispose();
      await db.close();
      await folder.delete(recursive: true);
    },
  );
}
