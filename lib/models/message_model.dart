import 'dart:convert';

enum MessageStatus { pending, sent, delivered, synced }

enum MessageType { message, ack, sos, deviceInfo, presence, media }

class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.message,
    this.status = MessageStatus.pending,
    this.ackFor,
    this.recordedAt,
  });

  final String id, senderId, senderName, receiverId, text;
  final DateTime timestamp;
  // Local receipt/creation time; never trust or transmit it as sender time.
  final DateTime? recordedAt;
  DateTime get displayTime => recordedAt ?? timestamp;
  String get statusLabel => switch (status) {
    MessageStatus.pending => 'รอเชื่อมต่อ',
    MessageStatus.sent => 'รอเครื่องรับยืนยัน',
    MessageStatus.delivered => 'ถึงเครื่องรับแล้ว',
    MessageStatus.synced => 'ซิงก์แล้ว',
  };
  final MessageType type;
  final MessageStatus status;
  final String? ackFor;

  MessageModel copyWith({MessageStatus? status}) => MessageModel(
    id: id,
    senderId: senderId,
    senderName: senderName,
    receiverId: receiverId,
    text: text,
    timestamp: timestamp,
    type: type,
    status: status ?? this.status,
    ackFor: ackFor,
    recordedAt: recordedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'receiverId': receiverId,
    'text': text,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'type': type.name,
    'status': status.name,
    'ackFor': ackFor,
  };
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final message = MessageModel(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      receiverId: map['receiverId'] as String,
      text: map['text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      type: MessageType.values.byName(map['type'] as String),
      status: MessageStatus.values.byName(map['status'] as String),
      ackFor: map['ackFor'] as String?,
      recordedAt: DateTime.tryParse(map['recordedAt'] as String? ?? ''),
    );
    if (message.id.isEmpty ||
        message.senderId.isEmpty ||
        (message.type != MessageType.deviceInfo &&
            message.receiverId.isEmpty) ||
        (message.type == MessageType.ack &&
            (message.ackFor?.isNotEmpty != true))) {
      throw const FormatException('Invalid message envelope');
    }
    return message;
  }
  String toJson() => jsonEncode(toMap());
  factory MessageModel.fromJson(String source) =>
      MessageModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
