import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/nearby_device.dart';
import 'permission_service.dart';
import 'connection_session.dart';

class NearbyService extends ChangeNotifier {
  NearbyService({
    Nearby? nearby,
    PermissionService? permissions,
    ConnectionSession? session,
  }) : _nearby = nearby ?? Nearby(),
       connectionSession = session ?? ConnectionSession(),
       permissions = permissions ?? PermissionService();

  static const serviceId = 'com.rmutt.rescuelink';
  static const strategy = Strategy.P2P_CLUSTER;
  final Nearby _nearby;
  final PermissionService permissions;
  final ConnectionSession connectionSession;
  bool backgroundActive = false;
  bool autoConnect = false;
  bool continuousDiscovery = false;
  Future<void>? _startingNearby;
  Timer? _autoTimer;
  bool _autoBusy = false;
  Future<void>? _refreshingDiscovery;
  Future<void>? _connectingAvailable;
  final Set<String> _accepting = {};
  final Map<String, DateTime> _retryAfter = {};
  DateTime? _lastScan;
  Future<void>? _startingAutomatic, _startingAdvertising, _startingDiscovery;
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

  // ─── FILE payload callbacks (used by MediaService) ────────────────────────
  void Function(String endpointId, int payloadId, String? uri)?
  onFilePayloadStarted;
  void Function(
    String endpointId,
    int payloadId,
    int bytesTransferred,
    int totalBytes,
  )?
  onFileTransferProgress;
  void Function(String endpointId, int payloadId)? onFileTransferSuccess;
  void Function(String endpointId, int payloadId)? onFileTransferFailed;

  /// payloadId → file URI: ติดตาม FILE payload ที่กำลังรับอยู่
  final Map<int, String?> _pendingFileUris = {};

  /// payloadId ของไฟล์ที่เราส่งออก เพื่อแยก sent vs received progress
  final Set<int> _sentFilePayloads = {};

  List<NearbyDevice> get discoveredDevices =>
      _devices.values.where((d) => !d.isConnected).toList();
  List<NearbyDevice> get connectedDevices =>
      _devices.values.where((d) => d.isConnected).toList();
  bool get hasActivity =>
      isAdvertising ||
      isDiscovering ||
      _devices.values.any((d) => d.isConnected || d.isConnecting);
  bool _current(int session) =>
      !_disposed && (_foreground || backgroundActive) && _session == session;

  void setForeground(bool value) {
    _foreground = value;
    if (!value && !backgroundActive) unawaited(stopAll());
  }

  /// Discover continuously while leaving outbound connections to the user.
  Future<void> startNearby() => _startingNearby ??= (() async {
    await _stopping;
    if (!_foreground || _disposed) return;
    continuousDiscovery = true;
    final session = _session;
    // Resume can return from Android settings while native flags are still up.
    if ((isAdvertising || isDiscovering) && !await checkPermissions()) return;
    if (!_current(session)) return;
    await startAdvertising();
    if (!_current(session) || !continuousDiscovery || !isAdvertising) return;
    await startDiscovery();
  })().whenComplete(() => _startingNearby = null);

  Future<void> startAutomatic() => _startingAutomatic ??= _startAutomatic()
      .whenComplete(() => _startingAutomatic = null);

  Future<void> _startAutomatic() async {
    await _stopping;
    if (!_foreground || _disposed) return;
    autoConnect = true;
    await startAdvertising();
    if (!autoConnect || !isAdvertising) {
      autoConnect = false;
      return;
    }
    await startDiscovery();
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_connectAvailable()),
    );
    await _connectAvailable();
    _update();
  }

  Future<void> _connectAvailable() => _connectingAvailable ??=
      _connectAvailableNow().whenComplete(() => _connectingAvailable = null);

  Future<void> _connectAvailableNow() async {
    if (!autoConnect || _autoBusy || _disposed) return;
    _autoBusy = true;
    final session = _session;
    try {
      if (!isDiscovering) await startDiscovery();
      // Lost endpoints are not always reported again by Nearby until a new scan.
      if (discoveredDevices.isEmpty &&
          connectedDevices.isEmpty &&
          DateTime.now().difference(_lastScan ?? DateTime(1970)) >
              const Duration(seconds: 12)) {
        await _rediscover();
      }
      for (final device in discoveredDevices) {
        // Both devices advertise and scan. For distinct names, elect one caller
        // so simultaneous outbound requests cannot cancel each other.
        // Equal custom names retain randomized backoff; manual Connect is free.
        if (deviceName.compareTo(device.name) > 0) continue;
        // Random delay reduces simultaneous requests when both phones discover each other.
        await Future<void>.delayed(
          Duration(milliseconds: 200 + Random().nextInt(1000)),
        );
        if (!_current(session) || !autoConnect) return;
        if (device.isAvailable &&
            !DateTime.now().isBefore(
              _retryAfter[device.endpointId] ?? DateTime(1970),
            )) {
          await requestConnection(device.endpointId);
        }
      }
    } finally {
      _autoBusy = false;
    }
  }

  Future<void> _rediscover() => _refreshingDiscovery ??= (() async {
    final session = _session;
    if (!autoConnect || !_current(session)) return;
    await stopDiscovery();
    if (!autoConnect || !_current(session)) return;
    await startDiscovery();
  })().whenComplete(() => _refreshingDiscovery = null);

  Future<void> _recoverConnection(int session, String id) async {
    _timeouts.remove(id)?.cancel();
    _accepting.remove(id);
    _retryAfter[id] = DateTime.now().add(
      Duration(seconds: 3 + Random().nextInt(5)),
    );
    try {
      await _nearby.disconnectFromEndpoint(id);
    } catch (e) {
      _log('Connection cleanup: $e');
    }
    if (!_current(session)) return;
    final device = _devices[id];
    if (device != null) {
      device.isConnecting = false;
      device.isConnected = false;
    }
    _update();
    await _rediscover();
  }

  Future<void> _keepSession() async {
    if (!backgroundActive && _foreground) {
      final session = _session;
      backgroundActive = await connectionSession.start();
      if (_disposed || session != _session) {
        await connectionSession.stop();
        backgroundActive = false;
      }
    }
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

  Future<void> startAdvertising() => _startingAdvertising ??=
      _startAdvertising().whenComplete(() => _startingAdvertising = null);

  Future<void> _startAdvertising() async {
    await _stopping;
    if (_disposed || (!_foreground && !backgroundActive) || isAdvertising) {
      return;
    }
    final session = _session;
    if ((_foreground && !await checkPermissions()) || !_current(session)) {
      return;
    }
    try {
      await _keepSession();
      if (!_current(session)) return;
      // Clear a stale native advertiser left by an interrupted previous start.
      // This does not disconnect existing endpoints.
      await _nearby.stopAdvertising();
      if (!_current(session)) return;
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

  Future<void> startDiscovery() => _startingDiscovery ??= _startDiscovery()
      .whenComplete(() => _startingDiscovery = null);

  Future<void> _startDiscovery() async {
    await _stopping;
    if (_disposed || (!_foreground && !backgroundActive) || isDiscovering) {
      return;
    }
    final session = _session;
    if ((_foreground && !await checkPermissions()) || !_current(session)) {
      return;
    }
    try {
      await _keepSession();
      if (!_current(session)) return;
      await _nearby.stopDiscovery();
      if (!_current(session)) return;
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
          if (autoConnect) unawaited(_connectAvailable());
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
      _lastScan = DateTime.now();
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
      reportError(
        'อีกเครื่องยังไม่ตอบรับ กรุณาวางเครื่องใกล้กันและเปิดรับการเชื่อมต่อ ระบบจะลองใหม่อัตโนมัติ',
      );
      _devices.remove(id);
      unawaited(_recoverConnection(session, id));
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
    if ((_foreground && !await checkPermissions()) || !_current(session)) {
      return;
    }
    if (device.isConnected || device.isConnecting) return;
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
      _log('Connection failed: $e');
      reportError(
        'ยังเชื่อมต่อกับ ${device.name} ไม่สำเร็จ ตรวจว่าอีกเครื่องเปิดรับการเชื่อมต่อและเปิด Bluetooth/Wi-Fi แล้ว ระบบจะลองใหม่อัตโนมัติ',
      );
      await _recoverConnection(session, id);
    }
  }

  void _initiated(int session, String id, ConnectionInfo info) {
    if (!_current(session)) return;
    if (_devices[id]?.isConnected == true || !_accepting.add(id)) return;
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
          if (!_current(session)) return;

          // ─── FILE payload ─────────────────────────────────────────────────
          if (payload.type == PayloadType.FILE) {
            _pendingFileUris[payload.id] = payload.uri;
            onFilePayloadStarted?.call(endpointId, payload.id, payload.uri);
            return;
          }

          // ─── BYTES payload ────────────────────────────────────────────────
          if (payload.type != PayloadType.BYTES || payload.bytes == null) {
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
          final isFile =
              _pendingFileUris.containsKey(update.id) ||
              _sentFilePayloads.contains(update.id);
          if (isFile) {
            if (update.status == PayloadStatus.IN_PROGRESS) {
              onFileTransferProgress?.call(
                endpointId,
                update.id,
                update.bytesTransferred,
                update.totalBytes,
              );
            } else if (update.status == PayloadStatus.SUCCESS) {
              _log('Payload ${update.id} file transfer successful');
              onFileTransferSuccess?.call(endpointId, update.id);
              _pendingFileUris.remove(update.id);
              _sentFilePayloads.remove(update.id);
            } else if (update.status == PayloadStatus.FAILURE ||
                update.status == PayloadStatus.CANCELED) {
              reportError(
                'File payload ${update.id} failed/canceled for $endpointId.',
              );
              onFileTransferFailed?.call(endpointId, update.id);
              _pendingFileUris.remove(update.id);
              _sentFilePayloads.remove(update.id);
            }
            return;
          }
          // BYTES payload status updates (ข้อความธรรมดา)
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
      _log('Accept connection failed: $e');
      reportError(
        'ตอบรับการเชื่อมต่อไม่สำเร็จ ระบบกำลังค้นหาอีกครั้ง กรุณาเปิดรับการเชื่อมต่อทั้งสองเครื่อง',
      );
      await _recoverConnection(session, id);
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
      _accepting.remove(id);
      _retryAfter.remove(id);
      lastError = null;
      connectionStatus = 'Connected to ${device.name}';
      _log(connectionStatus);
      // Reduce radio contention after finding the intended peer.
      if (!autoConnect && !continuousDiscovery) unawaited(stopDiscovery());
    } else {
      reportError(
        status == Status.REJECTED
            ? '${device.name} ยังไม่รับการเชื่อมต่อ กรุณาเปิดรับการเชื่อมต่อบนเครื่องนั้น'
            : 'เชื่อมต่อกับ ${device.name} ไม่สำเร็จ ระบบจะค้นหาและลองใหม่ กรุณาวางเครื่องใกล้กัน',
      );
      unawaited(_recoverConnection(session, id));
    }
  }

  void _disconnected(int session, String id) {
    if (!_current(session)) return;
    _timeouts.remove(id)?.cancel();
    _accepting.remove(id);
    final device = _devices.remove(id);
    connectionStatus =
        'ขาดการเชื่อมต่อกับ ${device?.name ?? id} • กำลังรอเชื่อมต่อใหม่';
    _log(connectionStatus);
    if (autoConnect) unawaited(_rediscover());
  }

  Future<bool> sendTextMessage(String text) async {
    if (_disposed || (!_foreground && !backgroundActive)) return false;
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

  /// ส่ง text payload — จำกัด 32 KB ตาม nearby_connections spec
  Future<void> sendMessage(String endpointId, String payload) async {
    if (_disposed ||
        (!_foreground && !backgroundActive) ||
        !connectedDevices.any((d) => d.endpointId == endpointId)) {
      throw StateError('Peer disconnected');
    }
    final bytes = Uint8List.fromList(utf8.encode(payload));
    if (bytes.length > 32768) throw ArgumentError('Packet exceeds 32 KB');
    await _nearby.sendBytesPayload(endpointId, bytes);
  }

  /// ส่งไฟล์โดยตรง — คืน payloadId สำหรับติดตาม progress
  /// ต้องส่ง mediaInit BYTES ตามทันทีเพื่อให้ผู้รับรู้ metadata
  Future<int> sendFile(String endpointId, String filePath) async {
    if (_disposed || (!_foreground && !backgroundActive)) {
      throw StateError('NearbyService not active');
    }
    if (!connectedDevices.any((d) => d.endpointId == endpointId)) {
      throw StateError('Peer disconnected');
    }
    final payloadId = await _nearby.sendFilePayload(endpointId, filePath);
    _sentFilePayloads.add(payloadId);
    return payloadId;
  }

  Future<void> copyReceivedFile(String uri, String destination) async {
    final copied = await _nearby.copyFileAndDeleteOriginal(uri, destination);
    if (!copied) throw StateError('Cannot copy received file');
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
    autoConnect = false;
    continuousDiscovery = false;
    _autoTimer?.cancel();
    if (_stopping != null) return _stopping!;
    ++_session; // Ignore late callbacks from the previous session.
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _timeouts.clear();
    _accepting.clear();
    _retryAfter.clear();
    _pendingFileUris.clear();
    _sentFilePayloads.clear();
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
    try {
      await connectionSession.stop();
    } catch (e) {
      reportError('Stop background service failed: $e');
    }
    backgroundActive = false;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stopAll()); // Each native cleanup operation catches its errors.
    super.dispose();
  }
}
