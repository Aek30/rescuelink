import 'dart:convert';
import 'message_model.dart';

/// Each path entry represents a sender of one radio hop. ACKs also carry
/// a fixed return route, including their destination (up to maxHops + 1).
class RelayPacket {
  RelayPacket(this.message, List<String> path, {List<String>? ackRoute})
    : path = List.unmodifiable(path),
      ackRoute = ackRoute == null ? null : List.unmodifiable(ackRoute);
  static const maxHops = 8;
  final MessageModel message;
  final List<String> path;
  final List<String>? ackRoute;

  String toJson() => jsonEncode({
    ...message.toMap(),
    'relayVersion': 1,
    'relayPath': path,
    if (ackRoute != null) 'relayAckRoute': ackRoute,
  });

  factory RelayPacket.fromMap(Map<String, dynamic> data) {
    final message = MessageModel.fromMap(data);
    final path = (data['relayPath'] as List).cast<String>();
    if (data['relayVersion'] != 1 ||
        (message.type != MessageType.message &&
            message.type != MessageType.sos &&
            message.type != MessageType.ack &&
            message.type != MessageType.media) ||
        path.isEmpty ||
        path.length > maxHops ||
        path.any((id) => id.isEmpty || id.length > 128) ||
        path.toSet().length != path.length ||
        path.first != message.senderId) {
      throw const FormatException('Invalid relay envelope');
    }
    final route = (data['relayAckRoute'] as List?)?.cast<String>();
    if (message.type == MessageType.ack) {
      if (route == null ||
          route.length < 2 ||
          route.length > maxHops + 1 ||
          route.any((id) => id.isEmpty || id.length > 128) ||
          route.toSet().length != route.length ||
          route.first != message.senderId ||
          route.last != message.receiverId ||
          path.length >= route.length ||
          List.generate(
            path.length,
            (i) => path[i] != route[i],
          ).contains(true)) {
        throw const FormatException('Invalid relay ACK route');
      }
    } else if (route != null) {
      throw const FormatException('Unexpected ACK route');
    }
    return RelayPacket(message, path, ackRoute: route);
  }
}
