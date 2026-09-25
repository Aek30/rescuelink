import 'dart:convert';
import 'message_model.dart';

/// Text-only flooding envelope. Each entry represents a sender of one radio hop.
class RelayPacket {
  RelayPacket(this.message, List<String> path) : path = List.unmodifiable(path);
  static const maxHops = 8;
  final MessageModel message;
  final List<String> path;

  String toJson() =>
      jsonEncode({...message.toMap(), 'relayVersion': 1, 'relayPath': path});

  factory RelayPacket.fromMap(Map<String, dynamic> data) {
    final message = MessageModel.fromMap(data);
    final path = (data['relayPath'] as List).cast<String>();
    if (data['relayVersion'] != 1 ||
        message.type != MessageType.message ||
        path.isEmpty ||
        path.length > maxHops ||
        path.any((id) => id.isEmpty || id.length > 128) ||
        path.toSet().length != path.length ||
        path.first != message.senderId) {
      throw const FormatException('Invalid relay envelope');
    }
    return RelayPacket(message, path);
  }
}
