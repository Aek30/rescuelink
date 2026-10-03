import 'dart:convert';

/// สถานะของสื่อแต่ละชิ้น — แยกสถานะฝั่งผู้ส่ง ผู้รับ และ Cloud ออกจากกัน
enum MediaStatus {
  // ฝั่งผู้ส่ง
  localReady, // ไฟล์ถูกคัดลอกลงพื้นที่ถาวร รอส่ง
  sending, // กำลังส่ง (transfer layer ทำงานอยู่)
  paused, // ถูกหยุดชั่วคราว (การเชื่อมต่อหลุด)
  failed, // ล้มเหลว
  delivered, // ผู้รับยืนยันแล้ว (checksum ผ่าน + บันทึกสำเร็จ)
  // ฝั่งผู้รับ
  receiving, // กำลังรับไฟล์
  received, // รับครบ + ตรวจ checksum ผ่าน + บันทึกสำเร็จ
  // Cloud (Phase 4 ช่วงที่ 2)
  uploadPending,
  uploading,
  cloudReady,
}

/// ข้อมูลหลักของไฟล์สื่อแต่ละชิ้น — เก็บใน media_files table ใน SQLite
class MediaFile {
  const MediaFile({
    required this.mediaId,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.checksum,
    required this.localPath,
    required this.createdAt,
    this.bytesTransferred = 0,
    this.status = MediaStatus.localReady,
    this.retryCount = 0,
    this.errorMessage,
  });

  final String mediaId;
  final String messageId; // ชี้ไปยัง messages table (chat entry)
  final String senderId;
  final String senderName;
  final String receiverId;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String checksum; // SHA-256 hex สำหรับตรวจความครบถ้วน
  final String localPath; // absolute path ของไฟล์จริงในเครื่อง
  final DateTime createdAt;
  final int bytesTransferred;
  final MediaStatus status;
  final int retryCount;
  final String? errorMessage;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  double get progress =>
      fileSize > 0 ? (bytesTransferred / fileSize).clamp(0.0, 1.0) : 0.0;

  MediaFile copyWith({
    int? bytesTransferred,
    MediaStatus? status,
    int? retryCount,
    String? errorMessage,
    String? localPath,
  }) => MediaFile(
    mediaId: mediaId,
    messageId: messageId,
    senderId: senderId,
    senderName: senderName,
    receiverId: receiverId,
    fileName: fileName,
    mimeType: mimeType,
    fileSize: fileSize,
    checksum: checksum,
    localPath: localPath ?? this.localPath,
    createdAt: createdAt,
    bytesTransferred: bytesTransferred ?? this.bytesTransferred,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    errorMessage: errorMessage,
  );

  Map<String, Object?> toMap() => {
    'mediaId': mediaId,
    'messageId': messageId,
    'senderId': senderId,
    'senderName': senderName,
    'receiverId': receiverId,
    'fileName': fileName,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'checksum': checksum,
    'localPath': localPath,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'bytesTransferred': bytesTransferred,
    'status': status.name,
    'retryCount': retryCount,
    'errorMessage': errorMessage,
  };

  factory MediaFile.fromMap(Map<String, dynamic> map) => MediaFile(
    mediaId: map['mediaId'] as String,
    messageId: map['messageId'] as String,
    senderId: map['senderId'] as String,
    senderName: (map['senderName'] as String?) ?? '',
    receiverId: map['receiverId'] as String,
    fileName: map['fileName'] as String,
    mimeType: map['mimeType'] as String,
    fileSize: map['fileSize'] as int,
    checksum: map['checksum'] as String,
    localPath: map['localPath'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    bytesTransferred: (map['bytesTransferred'] as int?) ?? 0,
    status: MediaStatus.values.byName(map['status'] as String),
    retryCount: (map['retryCount'] as int?) ?? 0,
    errorMessage: map['errorMessage'] as String?,
  );

  /// JSON header ส่งเป็น BYTES packet ก่อน FILE payload
  /// เพื่อให้ผู้รับรู้ metadata และ nearbyPayloadId ก่อนไฟล์มาถึง
  String toInitJson({required int nearbyPayloadId}) => jsonEncode({
    'packetType': 'mediaInit',
    'mediaId': mediaId,
    'messageId': messageId,
    'senderId': senderId,
    'senderName': senderName,
    'receiverId': receiverId,
    'fileName': fileName,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'checksum': checksum,
    'nearbyPayloadId': nearbyPayloadId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  });

  /// สร้าง MediaFile จาก mediaInit packet (ฝั่งผู้รับ)
  factory MediaFile.fromInitMap(Map<String, dynamic> m) => MediaFile(
    mediaId: m['mediaId'] as String,
    messageId: m['messageId'] as String,
    senderId: m['senderId'] as String,
    senderName: (m['senderName'] as String?) ?? '',
    receiverId: m['receiverId'] as String,
    fileName: m['fileName'] as String,
    mimeType: m['mimeType'] as String,
    fileSize: m['fileSize'] as int,
    checksum: m['checksum'] as String,
    localPath: '', // จะกำหนดเมื่อไฟล์มาถึงและตรวจสอบผ่าน
    createdAt:
        DateTime.tryParse(m['createdAt'] as String? ?? '') ??
        DateTime.now().toUtc(),
    status: MediaStatus.receiving,
  );
}

/// ACK ที่ผู้รับส่งกลับหลังตรวจสอบ checksum และบันทึกไฟล์สำเร็จ
/// ผู้ส่งจะแสดง "ส่งสำเร็จ" ได้ก็ต่อเมื่อได้รับ ACK นี้เท่านั้น
class MediaAck {
  const MediaAck({
    required this.mediaId,
    required this.messageId,
    required this.receiverId,
    required this.success,
    this.errorReason,
  });

  final String mediaId;
  final String messageId;
  final String receiverId;
  final bool success;
  final String? errorReason;

  String toJson() => jsonEncode({
    'packetType': 'mediaAck',
    'mediaId': mediaId,
    'messageId': messageId,
    'receiverId': receiverId,
    'success': success,
    'errorReason': errorReason,
  });

  factory MediaAck.fromMap(Map<String, dynamic> m) => MediaAck(
    mediaId: m['mediaId'] as String,
    messageId: m['messageId'] as String,
    receiverId: m['receiverId'] as String,
    success: m['success'] as bool,
    errorReason: m['errorReason'] as String?,
  );
}
