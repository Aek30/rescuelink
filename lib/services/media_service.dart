import 'dart:async';

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/media_model.dart';
import '../models/message_model.dart';
import 'local_database_service.dart';
import 'nearby_service.dart';
import 'auth_service.dart';
import 'media_upload_service.dart';

/// จัดการวงจรชีวิตของสื่อทั้งหมด:
/// เลือกไฟล์ → คัดลอกถาวร → คำนวณ checksum → ส่ง/รับผ่าน NearbyService → ตรวจสอบ → ACK
class MediaService extends ChangeNotifier {
  MediaService({
    required this.nearby,
    required this.database,
    required this.getEndpointForPeer,
    this.directoryProvider,
    this.ackTimeout = const Duration(seconds: 30),
  });

  final NearbyService nearby;
  final LocalDatabaseService database;
  final Future<Directory> Function()? directoryProvider;
  final Duration ackTimeout;
  late final uploads = MediaUploadService(
    database: database,
    cloud: SupabaseMediaCloud(AuthService.instance),
    lookup: getCached,
  );

  /// คืน endpointId ปัจจุบันของ peer หรือ null ถ้าออฟไลน์
  final String? Function(String peerId) getEndpointForPeer;

  final _uuid = const Uuid();
  String? _myId;
  bool _disposed = false;
  String? error;
  Future<void> Function()? onMessagesChanged;
  void Function(MediaFile)? onReceived;
  final Set<int> _completedPayloads = {};
  final Map<int, String> _payloadEndpoints = {};
  final Set<String> _starting = {};
  final Set<String> _verifying = {};
  final Map<String, Timer> _ackTimers = {};

  // In-memory cache: mediaId → MediaFile (โหลดจาก DB ตอนเริ่มต้น)
  final Map<String, MediaFile> _cache = {};

  // ─── Receiver side mappings ─────────────────────────────────────────────
  /// nearbyPayloadId → mediaId (เชื่อม FILE payload กับ mediaInit ที่รับมา)
  final Map<int, String> _payloadToMedia = {};

  /// nearbyPayloadId → file URI (เก็บ URI ของ FILE payload ที่กำลังรับ)
  final Map<int, String?> _payloadUris = {};

  // ─── Sender side mappings ────────────────────────────────────────────────
  /// mediaId → nearbyPayloadId (ติดตาม transfer ที่กำลังส่งออก)
  final Map<String, int> _activeSending = {};

  // ─── Public queries ──────────────────────────────────────────────────────

  bool get isReady => _myId != null;

  List<MediaFile> get allMedia => List.unmodifiable(
    _cache.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  /// ดึง MediaFile จาก cache ทันที (ไม่ต้อง await)
  MediaFile? getCached(String mediaId) => _cache[mediaId];

  /// ค้นหา MediaFile ที่เชื่อมกับ messageId
  Future<MediaFile?> getMediaForMessage(String messageId) async {
    final cached = _cache.values
        .where((m) => m.messageId == messageId)
        .firstOrNull;
    if (cached != null) return cached;
    return database.getMediaForMessage(messageId);
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  Future<void> initialize(String myId) async {
    _myId = myId;
    try {
      // โหลด cache จาก DB
      final all = await database.getAllMedia();
      for (final m in all) {
        _cache[m.mediaId] = m;
      }

      // Reset stuck states จาก app crash
      await _resetStuckStates(myId);
      uploads.addListener(_notify);
      await uploads.initialize();

      // ลงทะเบียน callbacks กับ NearbyService
      nearby.onFilePayloadStarted = _onFilePayloadStarted;
      nearby.onFileTransferProgress = _onFileTransferProgress;
      nearby.onFileTransferSuccess = _onFileTransferSuccess;
      nearby.onFileTransferFailed = _onFileTransferFailed;

      _notify();
    } catch (e) {
      _myId = null;
      error = 'Cannot initialize media service: $e';
      _notify();
      rethrow;
    }
  }

  Future<void> _resetStuckStates(String myId) async {
    // ไฟล์ที่ค้างในสถานะ sending ถูก app ปิดระหว่างส่ง → ตั้งเป็น paused เพื่อ retry
    for (final m
        in _cache.values
            .where((m) => m.status == MediaStatus.sending && m.senderId == myId)
            .toList()) {
      final updated = m.copyWith(status: MediaStatus.paused);
      _cache[m.mediaId] = updated;
      await database.updateMediaFile(updated);
    }
    // ไฟล์ที่ค้างในสถานะ receiving ถูก app ปิดระหว่างรับ → ถือว่าล้มเหลว
    for (final m
        in _cache.values
            .where((m) => m.status == MediaStatus.receiving)
            .toList()) {
      final updated = m.copyWith(
        status: MediaStatus.failed,
        errorMessage: 'รับไฟล์ไม่สำเร็จ เนื่องจากแอปปิดระหว่างการรับ',
      );
      _cache[m.mediaId] = updated;
      await database.updateMediaFile(updated);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    uploads.removeListener(_notify);
    uploads.dispose();
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    nearby.onFilePayloadStarted = null;
    nearby.onFileTransferProgress = null;
    nearby.onFileTransferSuccess = null;
    nearby.onFileTransferFailed = null;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _updateCache(MediaFile m) {
    _cache[m.mediaId] = m;
    _notify();
  }

  // ─── Sender: เลือกไฟล์และส่ง ─────────────────────────────────────────────

  /// เปิด file picker → คัดลอกไฟล์ถาวร → บันทึก DB → ส่งทันทีถ้าออนไลน์
  Future<MediaFile?> pickAndSend({
    required String senderName,
    required String receiverId,
  }) async {
    final myId = _myId;
    if (myId == null || _disposed) throw StateError('MediaService not ready');

    // 1. เลือกไฟล์
    final pickedFile = await FilePicker.pickFile(type: FileType.media);
    if (pickedFile == null) {
      return null;
    }
    final sourcePath = pickedFile.path;
    if (sourcePath == null) throw StateError('Cannot access file path');

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw StateError('File not found: $sourcePath');
    }

    // 2. ตรวจสอบขนาด (จำกัด 50 MB)
    final fileSize = await sourceFile.length();
    if (fileSize <= 0 || fileSize > 50 * 1024 * 1024) {
      throw ArgumentError('ไฟล์ต้องไม่เกิน 50 MB');
    }

    // 3. ตรวจ MIME type จาก extension
    final ext = p
        .extension(pickedFile.name)
        .replaceFirst('.', '')
        .toLowerCase();
    final mimeType = _mimeFromExtension(ext);
    if (!mimeType.startsWith('image/') && !mimeType.startsWith('video/')) {
      throw ArgumentError('ไม่รองรับไฟล์ชนิดนี้');
    }

    // 4. คำนวณ checksum SHA-256 สำหรับตรวจความครบถ้วนฝั่งผู้รับ
    final checksum = (await sha256.bind(sourceFile.openRead()).first)
        .toString();

    // 5. คัดลอกไฟล์ไปยังพื้นที่ถาวรของแอป (ไม่อาศัย temp/URI ชั่วคราว)
    final dir = await _mediaDir;
    final mediaId = _uuid.v4();
    final messageId = _uuid.v4();
    final safeName = pickedFile.name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final destPath = p.join(dir.path, '${mediaId}_$safeName');
    await sourceFile.copy(destPath);

    // 6. สร้าง MediaFile และ MessageModel (เก็บใน DB พร้อมกัน)
    final media = MediaFile(
      mediaId: mediaId,
      messageId: messageId,
      senderId: myId,
      senderName: senderName,
      receiverId: receiverId,
      fileName: pickedFile.name,
      mimeType: mimeType,
      fileSize: fileSize,
      checksum: checksum,
      localPath: destPath,
      createdAt: DateTime.now().toUtc(),
    );

    final message = MessageModel(
      id: messageId,
      senderId: myId,
      senderName: senderName,
      receiverId: receiverId,
      text: mediaId, // ข้อความเก็บ mediaId สำหรับ lookup
      timestamp: media.createdAt,
      type: MessageType.media,
    );

    await database.saveMediaMessage(media, message);
    await onMessagesChanged?.call();
    _cache[mediaId] = media;
    _notify();

    // 7. ส่งทันทีถ้า peer ออนไลน์
    final endpointId = getEndpointForPeer(receiverId);
    if (endpointId != null) {
      unawaited(_sendMedia(media, endpointId));
    }

    return media;
  }

  /// เรียกโดย MessageService.retry() สำหรับแต่ละ peer ที่เชื่อมต่ออยู่
  Future<void> sendPendingForPeer({
    required String peerId,
    required String endpointId,
  }) async {
    final myId = _myId;
    if (myId == null || _disposed) return;

    final pending = _cache.values
        .where(
          (m) =>
              m.senderId == myId &&
              m.receiverId == peerId &&
              m.retryCount < 5 &&
              (m.status == MediaStatus.localReady ||
                  m.status == MediaStatus.paused ||
                  // ลอง retry ถ้า failed แต่ไม่เกิน 5 ครั้ง
                  (m.status == MediaStatus.failed && m.retryCount < 5)),
        )
        .toList();

    for (final media in pending) {
      if (_disposed) return;
      // ไม่ส่งซ้ำถ้ากำลัง active อยู่
      if (_activeSending.containsKey(media.mediaId)) continue;
      await _sendMedia(media, endpointId);
    }
  }

  Future<void> _sendMedia(MediaFile media, String endpointId) async {
    if (_disposed || !_starting.add(media.mediaId)) return;

    // ตรวจว่าไฟล์ยังอยู่ในเครื่อง
    final sourceFile = File(media.localPath);
    if (!await sourceFile.exists()) {
      _updateCache(
        media.copyWith(
          status: MediaStatus.failed,
          errorMessage: 'ไม่พบไฟล์ในเครื่อง',
        ),
      );
      await database.updateMediaFile(_cache[media.mediaId]!);
      _starting.remove(media.mediaId);
      return;
    }

    try {
      // ตั้งสถานะ sending
      final sending = media.copyWith(
        status: MediaStatus.sending,
        bytesTransferred: 0,
        retryCount: media.retryCount + 1,
      );
      _updateCache(sending);
      await database.updateMediaFile(_cache[media.mediaId]!);

      // ส่ง FILE payload → ได้ payloadId กลับมา
      final payloadId = await nearby.sendFile(endpointId, media.localPath);
      _activeSending[media.mediaId] = payloadId;

      // ส่ง BYTES metadata ทันทีหลัง FILE payload เริ่ม
      // (ผู้รับต้องรู้ payloadId เพื่อ map ได้ถูกต้อง)
      final initJson = media.toInitJson(nearbyPayloadId: payloadId);
      await nearby.sendMessage(endpointId, initJson);
      _ackTimers.remove(media.mediaId)?.cancel();
      _ackTimers[media.mediaId] = Timer(const Duration(minutes: 5), () {
        unawaited(_pauseExpired(media.mediaId));
      });

      debugPrint('[Media] Sent init: ${media.mediaId} payloadId=$payloadId');
    } catch (e) {
      _activeSending.remove(media.mediaId);
      final current = _cache[media.mediaId];
      if (current != null) {
        _updateCache(
          current.copyWith(
            status: MediaStatus.paused,
            retryCount: current.retryCount + 1,
            errorMessage: '$e',
          ),
        );
        await database.updateMediaFile(_cache[media.mediaId]!);
      }
      error = 'Media send failed: $e';
      _notify();
    } finally {
      _starting.remove(media.mediaId);
    }
  }

  Future<void> _pauseExpired(String id) async {
    if (_disposed) return;
    _activeSending.remove(id);
    _ackTimers.remove(id)?.cancel();
    final current = _cache[id];
    if (current == null || current.status != MediaStatus.sending) return;
    final paused = current.copyWith(
      status: MediaStatus.paused,
      retryCount: current.retryCount + 1,
      errorMessage: 'ยังไม่ได้รับการยืนยันจากผู้รับ',
    );
    await database.updateMediaFile(paused);
    _updateCache(paused);
  }

  Future<void> retryMedia(String id) async {
    final media = _cache[id];
    if (media == null ||
        media.senderId != _myId ||
        media.status == MediaStatus.delivered ||
        _activeSending.containsKey(id)) {
      return;
    }
    final endpoint = getEndpointForPeer(media.receiverId);
    if (endpoint == null) throw StateError('ต้องเชื่อมต่อผู้รับโดยตรงก่อน');
    await _sendMedia(media, endpoint);
  }

  Future<void> pauseDisconnected() async {
    for (final media in _cache.values.toList()) {
      if (media.senderId == _myId &&
          media.status == MediaStatus.sending &&
          getEndpointForPeer(media.receiverId) == null) {
        await _pauseExpired(media.mediaId);
      }
    }
  }

  // ─── NearbyService FILE callbacks ────────────────────────────────────────

  void _onFilePayloadStarted(String endpointId, int payloadId, String? uri) {
    _payloadUris[payloadId] = uri;
    // ถ้า mediaInit มาก่อนแล้ว → อัพเดต UI ว่ากำลังรับ
    final mediaId = _payloadToMedia[payloadId];
    if (mediaId != null) {
      final m = _cache[mediaId];
      if (m != null && m.status != MediaStatus.receiving) {
        _updateCache(m.copyWith(status: MediaStatus.receiving));
        unawaited(database.updateMediaFile(_cache[mediaId]!));
      }
    }
  }

  void _onFileTransferProgress(
    String endpointId,
    int payloadId,
    int bytesTransferred,
    int totalBytes,
  ) {
    // ฝั่งผู้ส่ง
    final senderEntry = _activeSending.entries
        .where((e) => e.value == payloadId)
        .firstOrNull;
    if (senderEntry != null) {
      final m = _cache[senderEntry.key];
      if (m != null) {
        // อัพเดต cache โดยไม่เขียน DB ทุก chunk (ลด I/O)
        _cache[m.mediaId] = m.copyWith(bytesTransferred: bytesTransferred);
        _notify();
      }
      return;
    }

    // ฝั่งผู้รับ
    final mediaId = _payloadToMedia[payloadId];
    if (mediaId != null) {
      final m = _cache[mediaId];
      if (m != null) {
        _cache[mediaId] = m.copyWith(bytesTransferred: bytesTransferred);
        _notify();
      }
    }
  }

  Future<void> _onFileTransferSuccess(String endpointId, int payloadId) async {
    // ฝั่งผู้ส่ง: FILE layer ส่งครบแล้ว แต่ยัง "delivered" ไม่ได้จนกว่า ACK จะมา
    final senderEntry = _activeSending.entries
        .where((e) => e.value == payloadId)
        .firstOrNull;
    if (senderEntry != null) {
      _activeSending.remove(senderEntry.key);
      _ackTimers.remove(senderEntry.key)?.cancel();
      _ackTimers[senderEntry.key] = Timer(ackTimeout, () {
        unawaited(_pauseExpired(senderEntry.key));
      });
      debugPrint('[Media] File sent (waiting for ACK): ${senderEntry.key}');
      return;
    }

    // ฝั่งผู้รับ: ไฟล์มาครบ → ตรวจสอบ checksum และบันทึก
    _completedPayloads.add(payloadId);
    await _finishReceived(endpointId, payloadId);
  }

  Future<void> _finishReceived(String endpointId, int payloadId) async {
    if (!_completedPayloads.contains(payloadId)) return;
    if (_payloadEndpoints[payloadId] != endpointId) return;
    final mediaId = _payloadToMedia[payloadId];
    if (mediaId == null) {
      debugPrint('[Media] Unknown payloadId $payloadId on success');
      return;
    }

    final media = _cache[mediaId];
    if (media == null) return;

    final uri = _payloadUris[payloadId];
    _payloadToMedia.remove(payloadId);
    _payloadUris.remove(payloadId);
    _completedPayloads.remove(payloadId);

    if (!_verifying.add(mediaId)) return;
    try {
      await _verifyAndSaveReceived(endpointId, media, uri);
    } finally {
      _verifying.remove(mediaId);
    }
  }

  /// ตรวจสอบ checksum + ขนาด + บันทึกถาวร + สร้าง chat row + ส่ง ACK
  Future<void> _verifyAndSaveReceived(
    String endpointId,
    MediaFile media,
    String? receivedUri,
  ) async {
    try {
      if (receivedUri == null || receivedUri.isEmpty) {
        throw StateError('Received file URI is null or empty');
      }

      // คัดลอกจาก temp location ของ nearby → พื้นที่ถาวรของแอป
      final dir = await _mediaDir;
      final safeName = media.fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final destPath = p.join(dir.path, '${media.mediaId}_$safeName');
      if (receivedUri.startsWith('content://')) {
        await nearby.copyReceivedFile(receivedUri, destPath);
      } else {
        final source = receivedUri.startsWith('file:')
            ? File.fromUri(Uri.parse(receivedUri))
            : File(receivedUri);
        await source.copy(destPath);
      }

      // ตรวจ checksum SHA-256
      final savedFile = File(destPath);
      final actualChecksum = (await sha256.bind(savedFile.openRead()).first)
          .toString();

      if (actualChecksum != media.checksum) {
        await File(destPath).delete();
        throw StateError(
          'Checksum mismatch: expected=${media.checksum}, got=$actualChecksum',
        );
      }

      // ตรวจขนาด
      if (await savedFile.length() != media.fileSize) {
        await File(destPath).delete();
        throw StateError('Size mismatch: expected=${media.fileSize}');
      }

      // บันทึก chat message row (ปรากฏในแชตหลังรับครบและตรวจผ่านแล้วเท่านั้น)
      final myId = _myId!;
      final message = MessageModel(
        id: media.messageId,
        senderId: media.senderId,
        senderName: media.senderName,
        receiverId: myId,
        text: media.mediaId,
        timestamp: media.createdAt,
        type: MessageType.media,
        status: MessageStatus.delivered,
      );
      // อัพเดต MediaFile เป็น received
      final received = media.copyWith(
        status: MediaStatus.received,
        localPath: destPath,
        bytesTransferred: media.fileSize,
        errorMessage: null,
      );
      final inserted = await database.saveMediaMessage(received, message);
      _updateCache(received);
      await onMessagesChanged?.call();
      if (inserted) onReceived?.call(received);

      // ส่ง ACK กลับไปหาผู้ส่งเพื่อยืนยัน
      final senderEndpoint = getEndpointForPeer(media.senderId);
      if (senderEndpoint != null) {
        final ack = MediaAck(
          mediaId: media.mediaId,
          messageId: media.messageId,
          receiverId: myId,
          success: true,
        );
        try {
          await nearby.sendMessage(senderEndpoint, ack.toJson());
        } catch (_) {
          /* Preserve received state; duplicate init will replay ACK. */
        }
      }

      debugPrint('[Media] Received & verified: ${media.mediaId}');
    } catch (e) {
      // checksum/size ไม่ผ่าน → ตั้ง failed และส่ง NACK
      final failed = media.copyWith(
        status: MediaStatus.failed,
        errorMessage: '$e',
      );
      _updateCache(failed);
      await database.updateMediaFile(failed);

      final senderEndpoint = getEndpointForPeer(media.senderId);
      final myId = _myId;
      if (senderEndpoint != null && myId != null) {
        final nack = MediaAck(
          mediaId: media.mediaId,
          messageId: media.messageId,
          receiverId: myId,
          success: false,
          errorReason: '$e',
        );
        await nearby.sendMessage(senderEndpoint, nack.toJson());
      }

      error = 'Media verification failed: $e';
      _notify();
      debugPrint('[Media] Verification failed (${media.mediaId}): $e');
    }
  }

  Future<void> _onFileTransferFailed(String endpointId, int payloadId) async {
    // ฝั่งผู้ส่ง
    final senderEntry = _activeSending.entries
        .where((e) => e.value == payloadId)
        .firstOrNull;
    if (senderEntry != null) {
      _activeSending.remove(senderEntry.key);
      final m = _cache[senderEntry.key];
      _ackTimers.remove(senderEntry.key)?.cancel();
      if (m != null) {
        _updateCache(
          m.copyWith(
            status: MediaStatus.paused,
            errorMessage: 'การส่งถูกยกเลิก จะลองใหม่เมื่อเชื่อมต่ออีกครั้ง',
          ),
        );
        await database.updateMediaFile(_cache[senderEntry.key]!);
      }
      return;
    }

    // ฝั่งผู้รับ
    final mediaId = _payloadToMedia[payloadId];
    if (mediaId != null) {
      _payloadToMedia.remove(payloadId);
      _payloadUris.remove(payloadId);
      final m = _cache[mediaId];
      if (m != null) {
        _updateCache(
          m.copyWith(
            status: MediaStatus.failed,
            errorMessage: 'การรับไฟล์ล้มเหลว จะลองใหม่เมื่อผู้ส่งส่งอีกครั้ง',
          ),
        );
        await database.updateMediaFile(_cache[mediaId]!);
      }
    }
    _notify();
  }

  // ─── Incoming packet handlers (เรียกจาก MessageService) ─────────────────

  /// รับ mediaInit packet (BYTES) → บันทึก metadata → รอ FILE payload ตาม
  Future<void> handleMediaInit(
    String endpointId,
    Map<String, dynamic> data,
  ) async {
    try {
      final media = MediaFile.fromInitMap(data);
      final nearbyPayloadId = data['nearbyPayloadId'] as int;
      final myId = _myId;
      if (myId == null || media.receiverId != myId) return;
      if (media.fileSize <= 0 ||
          media.fileSize > 50 * 1024 * 1024 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(media.checksum) ||
          (!media.isImage && !media.isVideo) ||
          !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(media.mediaId) ||
          !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(media.messageId) ||
          media.fileName.isEmpty ||
          media.fileName.length > 255) {
        throw FormatException('Invalid media metadata');
      }

      // ป้องกัน duplicate: ถ้ารับแล้วให้ส่ง ACK ซ้ำเพื่อกรณี ACK ก่อนหน้าหาย
      final existing = _cache[media.mediaId];
      if (_verifying.contains(media.mediaId)) return;
      if (existing != null &&
          (existing.messageId != media.messageId ||
              existing.senderId != media.senderId ||
              existing.receiverId != media.receiverId ||
              existing.checksum != media.checksum ||
              existing.fileSize != media.fileSize ||
              existing.fileName != media.fileName ||
              existing.mimeType != media.mimeType)) {
        throw FormatException('Conflicting media metadata');
      }
      _payloadEndpoints[nearbyPayloadId] = endpointId;
      if (existing != null &&
          (existing.status == MediaStatus.received ||
              existing.status == MediaStatus.delivered)) {
        final ack = MediaAck(
          mediaId: media.mediaId,
          messageId: media.messageId,
          receiverId: myId,
          success: true,
        );
        await nearby.sendMessage(endpointId, ack.toJson());
        return;
      }
      // กำลังรับอยู่แล้ว → แค่อัพเดต payloadId mapping
      if (existing != null && existing.status == MediaStatus.receiving) {
        _payloadToMedia[nearbyPayloadId] = media.mediaId;
        await _finishReceived(endpointId, nearbyPayloadId);
        return;
      }

      // บันทึก DB และ cache
      await database.insertMediaFile(media);
      _cache[media.mediaId] = media;
      _payloadToMedia[nearbyPayloadId] = media.mediaId;

      // กรณี FILE payload มาก่อน mediaInit (ไม่น่าเป็นไปได้ แต่ handle ไว้)
      await _finishReceived(endpointId, nearbyPayloadId);

      _notify();
      debugPrint('[Media] mediaInit: ${media.mediaId}');
    } catch (e) {
      error = 'handleMediaInit failed: $e';
      _notify();
      debugPrint('[Media] handleMediaInit error: $e');
    }
  }

  /// รับ mediaAck packet → อัพเดตสถานะฝั่งผู้ส่ง
  Future<void> handleMediaAck(
    Map<String, dynamic> data, {
    required String peerId,
  }) async {
    try {
      final ack = MediaAck.fromMap(data);
      final media = _cache[ack.mediaId];
      if (media == null) return;
      if (media.senderId != _myId ||
          media.receiverId != peerId ||
          ack.receiverId != peerId ||
          ack.messageId != media.messageId) {
        return;
      }
      _ackTimers.remove(ack.mediaId)?.cancel();
      _activeSending.remove(ack.mediaId);

      if (ack.success) {
        // ผู้รับยืนยัน checksum ผ่าน → ถือว่าส่งสำเร็จ 100%
        _updateCache(
          media.copyWith(
            status: MediaStatus.delivered,
            bytesTransferred: media.fileSize,
            errorMessage: null,
          ),
        );
        await database.updateMediaFile(_cache[ack.mediaId]!);
        await database.updateMessageStatus(
          media.messageId,
          MessageStatus.delivered,
        );
        await onMessagesChanged?.call();
      } else {
        // ผู้รับแจ้งว่า checksum ไม่ผ่าน → ต้องส่งใหม่
        _updateCache(
          media.copyWith(
            status: MediaStatus.paused,
            retryCount: media.retryCount + 1,
            errorMessage: ack.errorReason ?? 'ผู้รับรายงานข้อผิดพลาด',
          ),
        );
        await database.updateMediaFile(_cache[ack.mediaId]!);
      }

      debugPrint('[Media] ACK for ${ack.mediaId}: success=${ack.success}');
    } catch (e) {
      debugPrint('[Media] handleMediaAck error: $e');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// พื้นที่จัดเก็บไฟล์ถาวรของแอป — สร้างอัตโนมัติถ้าไม่มี
  Future<Directory> get _mediaDir async {
    if (directoryProvider != null) return directoryProvider!();
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'rescuelink_media', _myId!));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _mimeFromExtension(String ext) => switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'avi' => 'video/x-msvideo',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    _ => 'application/octet-stream',
  };
}
