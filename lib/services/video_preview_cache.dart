import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/media_model.dart';

class VideoPreview {
  const VideoPreview({this.path, this.duration});
  final String? path;
  final Duration? duration;
}

/// Sidecars live beside the account's media, so account cleanup removes them.
/// Concurrent requests share a future; rebuilding never decodes another frame.
class VideoPreviewCache {
  static final instance = VideoPreviewCache();
  final _pending = <String, Future<VideoPreview>>{};
  Future<void> _tail = Future.value();
  Future<VideoPreview> prepare(MediaFile media) {
    if (!media.isVideo ||
        media.localPath.isEmpty ||
        media.status == MediaStatus.receiving ||
        media.status == MediaStatus.relayQueued) {
      return Future.value(const VideoPreview());
    }
    final key = '${media.localPath}:${media.checksum}:${media.fileSize}';
    return _pending.putIfAbsent(key, () {
      // Decode one video at a time when restoring a long conversation.
      final work = _tail.then((_) => _generate(media));
      _tail = work.then<void>((_) {});
      return work;
    });
  }

  Future<VideoPreview> _generate(MediaFile media) async {
    final thumbnail = File('${media.localPath}.preview.jpg');
    final metadata = File('${media.localPath}.preview.json');
    String? path;
    Duration? duration;
    VideoPlayerController? controller;
    try {
      if (!await File(media.localPath).exists()) return const VideoPreview();
      if (await thumbnail.exists()) path = thumbnail.path;
      if (await metadata.exists()) {
        final data = jsonDecode(await metadata.readAsString());
        duration = Duration(milliseconds: data['durationMs'] as int);
      }
      if (path != null && duration != null) {
        return VideoPreview(path: path, duration: duration);
      }
      if (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) {
        return VideoPreview(path: path, duration: duration);
      }
      if (path == null) {
        final bytes = await VideoThumbnail.thumbnailData(
          video: media.localPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 640,
          timeMs: 0,
          quality: 80,
        ).timeout(const Duration(seconds: 15));
        if (bytes != null) {
          await thumbnail.writeAsBytes(bytes, flush: true);
          path = thumbnail.path;
        }
      }
      if (duration == null) {
        controller = VideoPlayerController.file(File(media.localPath));
        await controller.initialize().timeout(const Duration(seconds: 15));
        duration = controller.value.duration;
        await metadata.writeAsString(
          jsonEncode({'durationMs': duration.inMilliseconds}),
        );
      }
    } catch (error, stack) {
      debugPrint('Video preview (${media.mediaId}): $error\n$stack');
    } finally {
      try {
        await controller?.dispose().timeout(const Duration(seconds: 2));
      } catch (error) {
        debugPrint('Video preview cleanup: $error');
      }
    }
    return VideoPreview(path: path, duration: duration);
  }
}
