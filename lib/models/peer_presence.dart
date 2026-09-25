import 'dart:convert';
import 'sos_alert.dart';

class PeerPresence {
  PeerPresence({
    required this.sequence,
    required this.rescue,
    required this.receivedAt,
    this.sos,
  });
  final int sequence;
  final bool rescue;
  final DateTime receivedAt;
  final SosAlert? sos;
  bool isFresh(DateTime now) =>
      now.difference(receivedAt).inSeconds < 30 && !now.isBefore(receivedAt);
  String encode() => jsonEncode({
    'version': 1,
    'sequence': sequence,
    'rescue': rescue,
    'sos': sos?.toJson(),
    'receivedAt': receivedAt.toUtc().toIso8601String(),
  });
  factory PeerPresence.decode(String text, {DateTime? receivedAt}) {
    final m = jsonDecode(text) as Map<String, dynamic>;
    if (m['version'] != 1 ||
        m['sequence'] is! int ||
        (m['sequence'] as int) < 1 ||
        m['rescue'] is! bool) {
      throw const FormatException('Invalid presence');
    }
    return PeerPresence(
      sequence: m['sequence'] as int,
      rescue: m['rescue'] as bool,
      sos: m['sos'] == null ? null : SosAlert.fromJson(m['sos'] as String),
      receivedAt: receivedAt ?? DateTime.parse(m['receivedAt'] as String),
    );
  }
}
