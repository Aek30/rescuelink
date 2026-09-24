import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/nearby_device.dart';
import 'permission_service.dart';

class NearbyService extends ChangeNotifier {
  NearbyService({Nearby? nearby, PermissionService? permissions})
    : _nearby = nearby ?? Nearby(),
      permissions = permissions ?? PermissionService();

  static const serviceId = 'com.rmutt.rescuelink';
  static const strategy = Strategy.P2P_CLUSTER;
  final Nearby _nearby;
  final PermissionService permissions;
  final Map<String, NearbyDevice> _devices = {};
  final Map<String, Timer> _timeouts = {};
  final List<String> messages = [];
  final List<String> receivedMessages = [];
  final List<String> logs = [];
  String deviceName =
      'Rescue-${Random.secure().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  String connectionStatus = 'Idle';
  String? lastError;
  bool isAdvertising = false;
  bool isDiscovering = false;
  bool _disposed = false;
  bool _foreground = true;
  int _session = 0;
  Future<void>? _stopping;
  void Function(String endpointId, String payload)? onTextPayloadReceived;

  List<NearbyDevice> get discoveredDevices =>
      _devices.values.where((d) => !d.isConnected).toList();
  List<NearbyDevice> get connectedDevices =>
      _devices.values.where((d) => d.isConnected).toList();
  bool get hasActivity =>
      isAdvertising ||
      isDiscovering ||
      _devices.values.any((d) => d.isConnected || d.isConnecting);
  bool _current(int session) =>
      !_disposed && _foreground && _session == session;

  void setForeground(bool value) {
    _foreground = value;
    if (!value) unawaited(stopAll());
  }

  void _update() {
    if (!_disposed) notifyListeners();
  }

  void _append(List<String> list, String value) {
    list.add(value);
    if (list.length > 200) list.removeAt(0);
  }

  void _log(String text) {
    if (_disposed) return;
    _append(
      logs,
      '${DateTime.now().toIso8601String().substring(11, 19)} $text',
    );
    debugPrint('[RescueLink] $text');
    _update();
  }

  void reportError(String text) {
    if (_disposed) return;
    lastError = text;
    connectionStatus = text;
    _log(text);
  }

  void setName(String text) {
    if (!hasActivity && text.trim().isNotEmpty) deviceName = text.trim();
  }

  Future<bool> checkPermissions() async {
    final ready = await permissions.ensureReady();
    if (!ready) reportError(permissions.error ?? 'Permissions required.');
    _update();
    return ready;
  }

  Future<void> startAdvertising() async {
    await _stopping;
    if (_disposed || !_foreground || isAdvertising) return;
    final session = _session;
    if (!await checkPermissions() || !_current(session)) return;
    try {
      final ok = await _nearby.startAdvertising(
        deviceName,
        strategy,
        serviceId: serviceId,
        onConnectionInitiated: (id, info) => _initiated(session, id, info),
        onConnectionResult: (id, status) => _result(session, id, status),
        onDisconnected: (id) => _disconnected(session, id),
      );
      if (!_current(session)) {
        await _nearby.stopAdvertising();
        return;
      }
      if (!ok) throw StateError('Nearby returned false');
      isAdvertising = true;
      lastError = null;
      connectionStatus = 'Advertising... Waiting for nearby devices';
      _log('Advertising started as $deviceName');
    } catch (e) {
      if (_current(session)) reportError('Advertising start failed: $e');
    }
  }

  Future<void> startDiscovery() async {
    await _stopping;
    if (_disposed || !_foreground || isDiscovering) return;
    final session = _session;
    if (!await checkPermissions() || !_current(session)) return;
    try {
      final ok = await _nearby.startDiscovery(
        deviceName,
        strategy,
        serviceId: serviceId,
        onEndpointFound: (id, name, service) {
          if (!_current(session) || service != serviceId) return;
          final device = _devices.putIfAbsent(
            id,
            () => NearbyDevice(endpointId: id, name: name),
          );
          device.name = name;
          device.isAvailable = true;
          _log('Found $name ($id)');
        },
        onEndpointLost: (id) {
          if (!_current(session)) return;
          final device = _devices[id];
          if (device == null) return;
          device.isAvailable = false;
          if (!device.isConnected && !device.isConnecting) _devices.remove(id);
          _log('Endpoint lost: ${device.name}');
        },
      );
      if (!_current(session)) {
        await _nearby.stopDiscovery();
        return;
      }
      if (!ok) throw StateError('Nearby returned false');
      isDiscovering = true;
      lastError = null;
      connectionStatus = 'Discovering nearby RescueLink devices...';
      _log('Discovery started');
    } catch (e) {
      if (_current(session)) reportError('Discovery start failed: $e');
    }
  }

  void _startTimeout(int session, String id) {
    _timeouts.remove(id)?.cancel();
    _timeouts[id] = Timer(const Duration(seconds: 30), () {
      if (!_current(session) || _devices[id]?.isConnecting != true) return;
      unawaited(disconnect(id));
      reportError('Connection timed out. Move closer and discover again.');
    });
  }

  Future<void> requestConnection(String id) async {
    final device = _devices[id];
    if (_disposed ||
        device == null ||
        device.isConnected ||
        device.isConnecting) {
      return;
    }
    final session = _session;
    if (!await checkPermissions() || !_current(session)) return;
    device.isConnecting = true;
    _startTimeout(session, id);
    _log('Connection requested: ${device.name}');
    try {
      final ok = await _nearby.requestConnection(
        deviceName,
        id,
        onConnectionInitiated: (id, info) => _initiated(session, id, info),
        onConnectionResult: (id, status) => _result(session, id, status),
        onDisconnected: (id) => _disconnected(session, id),
      );
      if (!ok) throw StateError('Nearby returned false');
    } catch (e) {
      if (!_current(session)) return;
      _timeouts.remove(id)?.cancel();
      device.isConnecting = false;
      reportError('Connection failed: $e');
    }
  }

  void _initiated(int session, String id, ConnectionInfo info) {
    if (!_current(session)) return;
    final device = _devices.putIfAbsent(
      id,
      () => NearbyDevice(endpointId: id, name: info.endpointName),
    );
    device.name = info.endpointName;
    device.isConnecting = true;
    _startTimeout(session, id);
    _log(
      'Connection initiated: ${info.endpointName}; code ${info.authenticationToken} (POC auto-accept)',
    );
    // TODO: Final version should allow the user to approve/reject nearby connections.
    // Both advertiser and discoverer must accept. Only use with test phones.
    unawaited(acceptConnection(id));
  }

  Future<void> acceptConnection(String id) async {
    final session = _session;
    if (!_current(session)) return;
    try {
      final ok = await _nearby.acceptConnection(
        id,
        onPayLoadRecieved: (endpointId, payload) {
          if (!_current(session) ||
              payload.type != PayloadType.BYTES ||
              payload.bytes == null) {
            return;
          }
          try {
            final text = utf8.decode(payload.bytes!);
            if (onTextPayloadReceived != null) {
              onTextPayloadReceived!(endpointId, text);
              return;
            }
            final message =
                '${_devices[endpointId]?.name ?? endpointId}: $text';
            _append(receivedMessages, message);
            _append(messages, message);
            _log(
              'Message received from ${_devices[endpointId]?.name ?? endpointId}',
            );
          } on FormatException {
            reportError('Received invalid UTF-8 text; message ignored.');
          }
        },
        onPayloadTransferUpdate: (endpointId, update) {
          if (!_current(session)) return;
          if (update.status == PayloadStatus.FAILURE ||
              update.status == PayloadStatus.CANCELED) {
            reportError(
              'Payload ${update.id} transfer failed/canceled for $endpointId.',
            );
          } else if (update.status == PayloadStatus.SUCCESS) {
            _log('Payload ${update.id} transfer successful');
          }
        },
      );
      if (!ok) throw StateError('Nearby returned false');
    } catch (e) {
      if (!_current(session)) return;
      await disconnect(id);
      reportError('Accept connection failed: $e');
    }
  }

  void _result(int session, String id, Status status) {
    if (!_current(session)) return;
    _timeouts.remove(id)?.cancel();
    final device = _devices[id];
    if (device == null) return;
    device.isConnecting = false;
    device.isConnected = status == Status.CONNECTED;
    if (device.isConnected) {
      lastError = null;
      connectionStatus = 'Connected to ${device.name}';
      _log(connectionStatus);
      // Reduce radio contention after finding the intended peer.
      unawaited(stopDiscovery());
    } else {
      reportError(
        status == Status.REJECTED
            ? 'Connection rejected by ${device.name}'
            : 'Connection failed with ${device.name}: $status',
      );
    }
  }

  void _disconnected(int session, String id) {
    if (!_current(session)) return;
    _timeouts.remove(id)?.cancel();
    final device = _devices.remove(id);
    connectionStatus =
        'Disconnected from ${device?.name ?? id}. Discover again to reconnect.';
    _log(connectionStatus);
  }

  Future<bool> sendTextMessage(String text) async {
    if (_disposed || !_foreground) return false;
    final session = _session;
    text = text.trim();
    if (text.isEmpty) {
      reportError('Enter a message before sending.');
      return false;
    }
    final bytes = Uint8List.fromList(utf8.encode(text));
    if (bytes.length > 32768) {
      reportError('Message exceeds the 32 KB byte payload limit.');
      return false;
    }
    final peers = connectedDevices;
    if (peers.isEmpty) {
      reportError('Connect to a nearby device before sending.');
      return false;
    }
    var allSent = true;
    for (final peer in peers) {
      try {
        await _nearby.sendBytesPayload(peer.endpointId, bytes);
        if (!_current(session)) return false;
        // API success means queued, not a read receipt. Transfer result is logged.
        _append(messages, 'Me → ${peer.name} (queued): $text');
        _log('Message queued for ${peer.name}');
      } catch (e) {
        allSent = false;
        reportError('Send to ${peer.name} failed: $e');
      }
    }
    _update();
    return allSent;
  }

  Future<void> sendMessage(String endpointId, String payload) async {
    if (_disposed ||
        !_foreground ||
        !connectedDevices.any((d) => d.endpointId == endpointId)) {
      throw StateError('Peer disconnected');
    }
    final bytes = Uint8List.fromList(utf8.encode(payload));
    if (bytes.length > 32768) throw ArgumentError('Packet exceeds 32 KB');
    await _nearby.sendBytesPayload(endpointId, bytes);
  }

  Future<void> stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
      isAdvertising = false;
      _log('Advertising stopped');
    } catch (e) {
      reportError('Stop advertising failed: $e');
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
      isDiscovering = false;
      _log('Discovery stopped');
    } catch (e) {
      reportError('Stop discovery failed: $e');
    }
  }

  Future<void> disconnect(String id) async {
    final session = _session;
    try {
      await _nearby.disconnectFromEndpoint(id);
      _disconnected(session, id);
    } catch (e) {
      reportError('Disconnect failed: $e');
    }
  }

  Future<void> stopAll() {
    if (_stopping != null) return _stopping!;
    ++_session; // Ignore late callbacks from the previous session.
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _timeouts.clear();
    // Invalidate local routes immediately, even if native cleanup fails.
    _devices.clear();
    // Lifecycle and STOP can arrive together; share one cleanup operation.
    _stopping = _cleanup().whenComplete(() => _stopping = null);
    return _stopping!;
  }

  Future<void> _cleanup() async {
    _update();
    await stopAdvertising();
    await stopDiscovery();
    try {
      await _nearby.stopAllEndpoints();
      _devices.clear();
      connectionStatus = 'Stopped';
      _log('All endpoints stopped');
    } catch (e) {
      reportError('Stop endpoints failed: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stopAll()); // Each native cleanup operation catches its errors.
    super.dispose();
  }
}
