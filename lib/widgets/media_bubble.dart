import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_model.dart';
import '../services/video_preview_cache.dart';
import '../theme/rescue_theme.dart';

/// Media content only; the shared message shell owns delivery indicators.
class MediaBubble extends StatelessWidget {
  const MediaBubble({super.key, required this.media, required this.isMine});
  final MediaFile? media;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final item = media;
    final label = item?.isVideo == true
        ? 'ส่งวิดีโอ'
        : item?.isImage == true
        ? 'ส่งรูป'
        : 'ส่งไฟล์';
    final ink = isMine ? Colors.white : RescueTheme.mutedFor(context);
    final width = MediaQuery.sizeOf(context).width * .65;
    final available =
        item != null &&
        item.localPath.isNotEmpty &&
        item.status != MediaStatus.receiving;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: !available
                  ? _placeholder(context)
                  : item.isVideo
                  ? _video(context, item)
                  : item.isImage
                  ? Semantics(
                      button: true,
                      label: 'เปิดรูปเต็มจอ',
                      child: InkWell(
                        onTap: () => _open(context, item),
                        child: Image.file(
                          File(item.localPath),
                          width: width,
                          fit: BoxFit.cover,
                          cacheWidth: 640,
                          errorBuilder: (context, error, stack) {
                            debugPrint('Chat image: $error');
                            return _placeholder(context);
                          },
                        ),
                      ),
                    )
                  : _placeholder(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: ink)),
          if (item?.status == MediaStatus.sending ||
              item?.status == MediaStatus.receiving)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                label: item?.status == MediaStatus.receiving
                    ? 'กำลังรับสื่อ'
                    : 'กำลังส่งสื่อ',
                child: LinearProgressIndicator(
                  value: item!.progress > 0 ? item.progress : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).brightness == Brightness.dark
        ? RescueTheme.darkSurfaceElevated
        : RescueTheme.border,
    child: Align(
      alignment: media?.isVideo == true ? Alignment.topLeft : Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          media?.isVideo == true
              ? Icons.videocam_outlined
              : Icons.image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 32,
        ),
      ),
    ),
  );

  Widget _video(
    BuildContext context,
    MediaFile item,
  ) => FutureBuilder<VideoPreview>(
    future: VideoPreviewCache.instance.prepare(item),
    builder: (context, snapshot) {
      final preview = snapshot.data;
      final duration = preview?.duration;
      final durationLabel = duration == null
          ? null
          : '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      return Semantics(
        button: true,
        label: 'เล่นวิดีโอเต็มจอ',
        child: InkWell(
          onTap: () => _open(context, item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview?.path != null)
                Image.file(
                  File(preview!.path!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) {
                    debugPrint('Video thumbnail: $error');
                    return _placeholder(context);
                  },
                )
              else
                _placeholder(context),
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              if (durationLabel != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      durationLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  void _open(BuildContext context, MediaFile item) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => item.isVideo
          ? _FullScreenVideo(file: File(item.localPath), fileName: 'วิดีโอ')
          : _FullScreenImage(file: File(item.localPath), fileName: 'รูปภาพ'),
    ),
  );
}

// ─── Full-screen image viewer ──────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.file, required this.fileName});

  final File file;
  final String fileName;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(
        fileName,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Image.file(
          file,
          errorBuilder: (context, error, stack) {
            debugPrint('Full-screen image: $error');
            return const Text(
              'เปิดรูปไม่สำเร็จ กรุณาลองใหม่',
              style: TextStyle(color: Colors.white),
            );
          },
        ),
      ),
    ),
  );
}

// ─── Full-screen video player ──────────────────────────────────────────────

class _FullScreenVideo extends StatefulWidget {
  const _FullScreenVideo({required this.file, required this.fileName});

  final File file;
  final String fileName;

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class CloudMediaViewer extends StatefulWidget {
  const CloudMediaViewer({super.key, required this.url, required this.media});
  final String url;
  final MediaFile media;
  @override
  State<CloudMediaViewer> createState() => _CloudMediaViewerState();
}

class _CloudMediaViewerState extends State<CloudMediaViewer> {
  VideoPlayerController? _video;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.media.isVideo) {
      _video = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _video!
          .initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object e) {
            debugPrint('Media player: $e');
            if (mounted) {
              setState(() => _error = 'เปิดวิดีโอไม่สำเร็จ กรุณาลองใหม่');
            }
          });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.media.isVideo ? 'วิดีโอ' : 'รูปภาพ')),
    body: Center(
      child: _error != null
          ? Text(_error!)
          : widget.media.isImage
          ? InteractiveViewer(
              child: Image.network(
                widget.url,
                errorBuilder: (context, error, stack) =>
                    const Text('เปิด Cloud ไม่สำเร็จ กรุณาลองใหม่'),
              ),
            )
          : _video?.value.isInitialized == true
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _video!.value.aspectRatio,
                  child: VideoPlayer(_video!),
                ),
                VideoProgressIndicator(_video!, allowScrubbing: true),
                IconButton(
                  onPressed: () => setState(() {
                    _video!.value.isPlaying ? _video!.pause() : _video!.play();
                  }),
                  icon: Icon(
                    _video!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
              ],
            )
          : const CircularProgressIndicator(),
    ),
  );
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller.play();
            }
          })
          .catchError((Object e) {
            debugPrint('Media player: $e');
            if (mounted) {
              setState(() => _error = 'เปิดวิดีโอไม่สำเร็จ กรุณาลองใหม่');
            }
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(
        widget.fileName,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    ),
    body: _error != null
        ? Center(
            child: Text(_error!, style: const TextStyle(color: Colors.white70)),
          )
        : _initialized
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                colors: const VideoProgressColors(
                  playedColor: RescueTheme.orange,
                  backgroundColor: Colors.white24,
                ),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator()),
    floatingActionButton: _initialized
        ? FloatingActionButton(
            backgroundColor: RescueTheme.orange,
            foregroundColor: RescueTheme.navy,
            onPressed: () => setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            }),
            child: Icon(
              _controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          )
        : null,
  );
}
