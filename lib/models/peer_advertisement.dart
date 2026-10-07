import 'peer_presence.dart';
import 'relay_packet.dart';
import 'sos_alert.dart';

/// Origin-owned sequence numbers prevent a replayed directory entry from
/// renewing presence. Age is accumulated using each receiver's local clock.
class PeerAdvertisement {
  PeerAdvertisement({
    required this.peerId,
    required this.name,
    required this.state,
    required List<String> path,
  }) : path = List.unmodifiable(path);

  static const retention = Duration(hours: 48);
  final String peerId, name;
  final PeerPresence state;
  // Origin first, this device last. The previous element is our next hop.
  final List<String> path;

  Map<String, Object?> toWire(DateTime now) => {
    'peerId': peerId,
    'name': name,
    'sequence': state.sequence,
    'rescue': state.rescue,
    'sos': state.sos?.toJson(),
    'ageMs': now.isBefore(state.receivedAt)
        ? retention.inMilliseconds
        : now.difference(state.receivedAt).inMilliseconds,
    'path': path,
  };

  factory PeerAdvertisement.fromWire(
    Map<String, dynamic> data, {
    required String advertiser,
    required String receiver,
    required DateTime now,
  }) {
    final id = data['peerId'];
    final name = data['name'];
    final sequence = data['sequence'];
    final rescue = data['rescue'];
    final age = data['ageMs'];
    final path = (data['path'] as List).cast<String>();
    if (id is! String ||
        id.isEmpty ||
        id.length > 128 ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 128 ||
        sequence is! int ||
        sequence < 1 ||
        rescue is! bool ||
        age is! int ||
        age < 0 ||
        age > retention.inMilliseconds ||
        path.isEmpty ||
        path.length > RelayPacket.maxHops ||
        path.first != id ||
        path.last != advertiser ||
        path.contains(receiver) ||
        path.any((p) => p.isEmpty || p.length > 128) ||
        path.toSet().length != path.length) {
      throw const FormatException('Invalid peer advertisement');
    }
    return PeerAdvertisement(
      peerId: id,
      name: name,
      state: PeerPresence(
        sequence: sequence,
        rescue: rescue,
        receivedAt: now.subtract(Duration(milliseconds: age)),
        sos: data['sos'] == null
            ? null
            : SosAlert.fromJson(data['sos'] as String),
      ),
      path: [...path, receiver],
    );
  }

  Map<String, Object?> toStored() => {
    'peerId': peerId,
    'name': name,
    'state': state.encode(),
    'path': path,
  };

  factory PeerAdvertisement.fromStored(Map<String, dynamic> data) =>
      PeerAdvertisement(
        peerId: data['peerId'] as String,
        name: data['name'] as String,
        state: PeerPresence.decode(data['state'] as String),
        path: (data['path'] as List).cast<String>(),
      );
}
