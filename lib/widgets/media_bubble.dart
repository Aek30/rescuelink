import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_model.dart';
import '../theme/rescue_theme.dart';

/// แสดงสื่อในฟอง chat — รองรับรูปภาพ, วิดีโอ, และสถานะต่าง ๆ ของ transfer
class MediaBubble extends StatelessWidget {
  const MediaBubble({super.key, required this.media, required this.isMine});

  final MediaFile? media;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (media == null) {
      return _placeholder(
        context,
        'กำลังโหลด...',
        Icons.hourglass_empty_rounded,
      );
    }

    return switch (media!.status) {
      MediaStatus.sending ||
      MediaStatus.receiving => _progress(context, isDark),
      MediaStatus.failed => _error(context, isDark),
      MediaStatus.localReady || MediaStatus.paused => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMine && media!.localPath.isNotEmpty) _mediaContent(context),
          _pending(context, isDark),
        ],
      ),
      MediaStatus.received ||
      MediaStatus.delivered ||
      MediaStatus.cloudReady => _mediaContent(context),
      _ => _pending(context, isDark),
    };
  }

  // ─── States ──────────────────────────────────────────────────────────────

  Widget _progress(BuildContext context, bool isDark) {
    final isSending = media!.status == MediaStatus.sending;
    final pct = (media!.progress * 100).toStringAsFixed(0);
    return _card(
      isDark: isDark,
      borderColor: RescueTheme.orange.withValues(alpha: .4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _fileHeader(context),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: media!.progress > 0 ? media!.progress : null,
              minHeight: 5,
              backgroundColor: isDark
                  ? const Color(0xFF283442)
                  : RescueTheme.border,
              valueColor: const AlwaysStoppedAnimation(RescueTheme.orange),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isSending ? Icons.upload_rounded : Icons.download_rounded,
                size: 13,
                color: RescueTheme.orange,
              ),
              const SizedBox(width: 4),
              Text(
                isSending ? 'กำลังส่ง $pct%' : 'กำลังรับ $pct%',
                style: TextStyle(
                  fontSize: 11,
                  color: RescueTheme.mutedFor(context),
                ),
              ),
              const Spacer(),
              Text(
                _formatSize(media!.bytesTransferred),
                style: TextStyle(
                  fontSize: 10,
                  color: RescueTheme.mutedFor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pending(BuildContext context, bool isDark) => _card(
    isDark: isDark,
    child: Row(
      children: [
        Icon(
          media!.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
          size: 22,
          color: RescueTheme.mutedFor(context),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                media!.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                media!.status == MediaStatus.paused
                    ? 'หยุดชั่วคราว — จะส่งใหม่เมื่อเชื่อมต่อ'
                    : 'รอส่ง • ${_formatSize(media!.fileSize)}',
                style: TextStyle(
                  fontSize: 11,
                  color: RescueTheme.mutedFor(context),
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.schedule_rounded,
          size: 16,
          color: RescueTheme.mutedFor(context),
        ),
      ],
    ),
  );

  Widget _error(BuildContext context, bool isDark) => _card(
    isDark: isDark,
    bgColor: isDark ? const Color(0xFF231718) : const Color(0xFFFFF0F0),
    borderColor: RescueTheme.danger.withValues(alpha: .3),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 22,
          color: RescueTheme.danger,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                media!.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'ส่งไม่สำเร็จ (ลอง ${media!.retryCount} ครั้ง)',
                style: const TextStyle(fontSize: 11, color: RescueTheme.danger),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ─── Media content (file available) ────────────────────────────────────

  Widget _mediaContent(BuildContext context) {
    final file = File(media!.localPath);
    if (!file.existsSync()) {
      return _placeholder(
        context,
        'ไม่พบไฟล์ในเครื่อง',
        Icons.broken_image_outlined,
      );
    }
    if (media!.isImage) return _imageView(context, file);
    if (media!.isVideo) return _videoThumb(context, file);
    return _fileCard(context, file);
  }

  Widget _imageView(BuildContext context, File file) => GestureDetector(
    onTap: () => _openImage(context, file),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Image.file(
            file,
            fit: BoxFit.cover,
            width: 220,
            height: 220,
            cacheWidth: 440,
            errorBuilder: (context, error, stack) => _placeholder(
              context,
              'แสดงรูปไม่ได้',
              Icons.broken_image_outlined,
            ),
          ),
          // ไอคอนขยาย
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _videoThumb(BuildContext context, File file) => GestureDetector(
    onTap: () => _openVideo(context, file),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 220,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black87),
            const Center(
              child: Icon(
                Icons.videocam_rounded,
                color: Colors.white30,
                size: 48,
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 10,
              right: 10,
              child: Text(
                media!.fileName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  shadows: [Shadow(blurRadius: 4)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _fileCard(BuildContext context, File file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _card(
      isDark: isDark,
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media!.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  _formatSize(media!.fileSize),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ─────────────────────────────────────────────────────────

  void _openImage(BuildContext context, File file) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          _FullScreenImage(file: file, fileName: media?.fileName ?? ''),
    ),
  );

  void _openVideo(BuildContext context, File file) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          _FullScreenVideo(file: file, fileName: media?.fileName ?? ''),
    ),
  );

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _fileHeader(BuildContext context) => Row(
    children: [
      Icon(
        media!.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        size: 18,
        color: RescueTheme.orange,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          media!.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      Text(
        _formatSize(media!.fileSize),
        style: TextStyle(fontSize: 10, color: RescueTheme.mutedFor(context)),
      ),
    ],
  );

  Widget _card({
    required bool isDark,
    required Widget child,
    Color? bgColor,
    Color? borderColor,
  }) => Container(
    width: 240,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bgColor ?? (isDark ? const Color(0xFF161C24) : Colors.white),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color:
            borderColor ??
            (isDark ? const Color(0xFF283442) : RescueTheme.border),
      ),
    ),
    child: child,
  );

  Widget _placeholder(BuildContext context, String text, IconData icon) =>
      Container(
        width: 240,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: RescueTheme.mutedFor(context),
                ),
              ),
            ),
          ],
        ),
      );

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
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
        child: Image.file(file),
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
            if (mounted) setState(() => _error = '$e');
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
    appBar: AppBar(title: Text(widget.media.fileName)),
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
            if (mounted) setState(() => _error = '$e');
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
