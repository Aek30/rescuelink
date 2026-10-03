import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'local_database_service.dart';
import '../models/media_model.dart';

enum UploadState { queued, uploading, verifying, failed, ready }

class MediaUpload {
  MediaUpload({
    required this.mediaId,
    required this.owner,
    this.state = UploadState.queued,
    this.bytes = 0,
    this.attempts = 0,
    this.error,
    this.nextAttempt,
  });
  final String mediaId, owner;
  UploadState state;
  int bytes, attempts;
  String? error;
  DateTime? nextAttempt;
  String get objectPath => '$owner/$mediaId';
  Map<String, Object?> toMap() => {
    'mediaId': mediaId,
    'owner': owner,
    'state': state.name,
    'bytes': bytes,
    'attempts': attempts,
    'error': error,
    'nextAttempt': nextAttempt?.toUtc().toIso8601String(),
  };
  factory MediaUpload.fromMap(Map<String, dynamic> m) => MediaUpload(
    mediaId: m['mediaId'],
    owner: m['owner'],
    state: UploadState.values.byName(m['state']),
    bytes: m['bytes'],
    attempts: m['attempts'],
    error: m['error'],
    nextAttempt: DateTime.tryParse(m['nextAttempt'] ?? ''),
  );
}

abstract interface class MediaCloud {
  String? get owner;
  Future<void> upload(
    MediaFile media,
    String owner,
    void Function(int) progress,
  );
  Future<void> verify(MediaFile media, String owner);
  Future<String> signedUrl(String path, String owner);
}

class SupabaseMediaCloud implements MediaCloud {
  SupabaseMediaCloud(this.auth);
  final AuthService auth;
  static const bucket = 'chat-media';
  @override
  String? get owner => auth.session?.userId;
  @override
  Future<void> upload(
    MediaFile media,
    String owner,
    void Function(int) progress,
  ) async {
    final client = await auth.cloudClient(owner);
    final backend = auth.backend as SupabaseAuthBackend;
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await http.postUrl(
        Uri.parse(
          '${backend.url}/storage/v1/object/$bucket/$owner/${media.mediaId}',
        ),
      );
      request.headers.set(
        'Authorization',
        'Bearer ${client.auth.currentSession!.accessToken}',
      );
      request.headers.set('apikey', backend.key);
      request.headers.set('x-upsert', 'true');
      request.headers.set('Content-Type', media.mimeType);
      request.contentLength = media.fileSize;
      int sent = 0;
      await request
          .addStream(
            File(media.localPath).openRead().map((chunk) {
              if (auth.session?.userId != owner) {
                throw StateError('บัญชีเปลี่ยนแล้ว');
              }
              sent += chunk.length;
              progress(sent);
              return chunk;
            }),
          )
          .timeout(const Duration(minutes: 3));
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      await response.drain<void>().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Upload HTTP ${response.statusCode}');
      }
    } finally {
      http.close(force: true);
    }
  }

  @override
  Future<void> verify(MediaFile media, String owner) async {
    final client = await auth.cloudClient(owner);
    final bytes = await client.storage
        .from(bucket)
        .download('$owner/${media.mediaId}');
    if (bytes.length != media.fileSize ||
        sha256.convert(bytes).toString() != media.checksum) {
      throw StateError('ไฟล์บน Cloud ไม่ครบหรือ checksum ไม่ตรง');
    }
    await client.from('media_records').upsert({
      'owner_id': owner,
      'id': media.mediaId,
      'message_id': media.messageId,
      'file_name': media.fileName,
      'mime_type': media.mimeType,
      'file_size': media.fileSize,
      'checksum': media.checksum,
      'created_at': media.createdAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<String> signedUrl(String path, String owner) async {
    final client = await auth.cloudClient(owner);
    return client.storage.from(bucket).createSignedUrl(path, 60);
  }
}

/// Upload status is deliberately independent of the offline delivery status.
class MediaUploadService extends ChangeNotifier {
  MediaUploadService({
    required this.database,
    required this.cloud,
    required this.lookup,
  });
  final LocalDatabaseService database;
  final MediaCloud cloud;
  final MediaFile? Function(String) lookup;
  final Map<String, MediaUpload> jobs = {};
  final Set<String> _selectedThisSession = {};
  Timer? _timer;
  bool _disposed = false, busy = false;
  MediaUpload? forMedia(String id) {
    final job = jobs[id];
    return job?.owner == cloud.owner ? job : null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    final saved = await database.getSetting('mediaUploadQueue');
    if (saved != null) {
      for (final raw in jsonDecode(saved) as List) {
        final job = MediaUpload.fromMap(Map<String, dynamic>.from(raw));
        if (job.state == UploadState.uploading ||
            job.state == UploadState.verifying) {
          job.state = UploadState.queued;
          job.bytes = 0;
        }
        jobs[job.mediaId] = job;
      }
    }
    await _save();
  }

  Future<void> _save() => database.setSetting(
    'mediaUploadQueue',
    jsonEncode(jobs.values.map((j) => j.toMap()).toList()),
  );
  Future<void> enqueue(String id) async {
    final owner = cloud.owner;
    if (owner == null) throw StateError('กรุณาเข้าสู่ระบบก่อน Upload');
    final media = lookup(id);
    if (media == null ||
        media.localPath.isEmpty ||
        media.status == MediaStatus.receiving ||
        media.status == MediaStatus.failed) {
      throw StateError('ไฟล์ในเครื่องยังไม่พร้อม');
    }
    final existing = jobs[id];
    if (existing != null && existing.owner != owner) {
      throw StateError('คิวนี้เป็นของบัญชีอื่น');
    }
    if (existing?.state == UploadState.ready ||
        existing?.state == UploadState.uploading ||
        existing?.state == UploadState.verifying) {
      return;
    }
    jobs[id] = existing ?? MediaUpload(mediaId: id, owner: owner);
    jobs[id]!.state = UploadState.queued;
    jobs[id]!.attempts = 0;
    jobs[id]!.nextAttempt = null;
    _selectedThisSession.add(id);
    await _save();
    _notify();
    _timer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(retryPending()),
    );
    await retryPending();
  }

  Future<void> retryPending() async {
    if (busy || _disposed || cloud.owner == null) return;
    busy = true;
    try {
      for (final job in jobs.values.toList()) {
        if (_disposed) return;
        if (!_selectedThisSession.contains(job.mediaId) ||
            job.owner != cloud.owner ||
            job.state == UploadState.ready ||
            job.attempts >= 5 ||
            (job.nextAttempt?.isAfter(DateTime.now()) ?? false)) {
          continue;
        }
        final media = lookup(job.mediaId);
        if (media == null) continue;
        try {
          final file = File(media.localPath);
          if (await file.length() != media.fileSize ||
              (await sha256.bind(file.openRead()).first).toString() !=
                  media.checksum) {
            throw StateError('ไฟล์ในเครื่องไม่ตรงกับ metadata');
          }
          job.state = UploadState.uploading;
          job.bytes = 0;
          job.error = null;
          await _save();
          _notify();
          await cloud.upload(media, job.owner, (bytes) {
            job.bytes = bytes.clamp(0, media.fileSize);
            _notify();
          });
          job.state = UploadState.verifying;
          await _save();
          _notify();
          await cloud
              .verify(media, job.owner)
              .timeout(const Duration(minutes: 1));
          if (cloud.owner != job.owner) throw StateError('บัญชีเปลี่ยนแล้ว');
          job.state = UploadState.ready;
          job.bytes = media.fileSize;
          job.nextAttempt = null;
        } catch (e) {
          job.state = UploadState.failed;
          job.attempts++;
          job.error = '$e';
          job.nextAttempt = DateTime.now().add(
            Duration(seconds: 15 * (1 << job.attempts)),
          );
        }
        await _save();
        _notify();
      }
    } finally {
      busy = false;
    }
  }

  Future<String> accessUrl(String id) async {
    final job = forMedia(id);
    if (job == null || job.state != UploadState.ready) {
      throw StateError('Upload ยังไม่สำเร็จ');
    }
    return cloud.signedUrl(job.objectPath, job.owner);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
