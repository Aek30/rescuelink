import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:uuid/uuid.dart';
import '../models/nearby_device.dart';
import 'permission_service.dart';
import 'connection_session.dart';

class NearbyService extends ChangeNotifier {
  NearbyService({
    Nearby? nearby,
    PermissionService? permissions,
    ConnectionSession? session,
    DateTime Function()? clock,
  }) : _nearby = nearby ?? Nearby(),
       _clock = clock ?? DateTime.now,
       connectionSession = session ?? ConnectionSession(),
       permissions = permissions ?? PermissionService();

  static const serviceId = 'com.rmutt.rescuelink';
  static const strategy = Strategy.P2P_CLUSTER;
  static const connectionTimeout = Duration(seconds: 12);
  static const payloadSendTimeout = Duration(seconds: 5);
  static const callerFallbackDelay = Duration(seconds: 16);
  static const discoveryRefreshInterval = Duration(seconds: 12);
  final String _callerId = const Uuid().v4();
  String? _advertisedName;
  String? _advertisedDisplayName;
  final Map<String, String> _endpointNames = {};
  final Set<String> _recovering = {};
  final Map<int, String> _fileEndpoints = {};
  final Map<String, Object> _attemptTokens = {};
  int _sendingFiles = 0;
  final Nearby _nearby;
  final DateTime Function() _clock;
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
  final Map<String, DateTime> _firstFound = {};
  bool _connectAgain = false;
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
  bool _isCheckingPermissions = false;
  bool _hasCheckedPermissions = false;
  Future<bool>? _permissionCheck;
  bool get isCheckingPermissions => _isCheckingPermissions;
  bool get hasCheckedPermissions => _hasCheckedPermissions;
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
  bool get _connectionBusy =>
      _recovering.isNotEmpty || _devices.values.any((d) => d.isConnecting);
  bool get _transferringFiles =>
      _sendingFiles > 0 ||
      _pendingFileUris.isNotEmpty ||
      _sentFilePayloads.isNotEmpty;

  // Freeze the wire identity until STOP. UUID ordering also handles identical
  // Thai display names without using either phone's local endpoint ID.
  String get _transportName => _advertisedName ??= (() {
    _advertisedDisplayName = deviceName;
    final name = StringBuffer();
    var bytes = 0;
    for (final rune in deviceName.runes) {
      final char = String.fromCharCode(rune);
      bytes += utf8.encode(char).length;
      if (bytes > 80) break;
      name.write(char);
    }
    return 'RL2:$_callerId:$name';
  })();

  static final _wireName = RegExp(
    r'^RL2:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}):(.*)$',
    dotAll: true,
  );

  String _displayName(String name) =>
      _wireName.firstMatch(name)?.group(2) ?? name;

  int _callerOrder(String wireName) {
    final peerId = _wireName.firstMatch(wireName)?.group(1);
    return peerId == null
        ? (_advertisedDisplayName ?? deviceName).compareTo(wireName)
        : _callerId.compareTo(peerId);
  }

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

  /// Discover continuously and connect to everyone nearby automatically.
  Future<void> startNearby() => _startingNearby ??= (() async {
    await _stopping;
    if (!_foreground || _disposed) return;
    continuousDiscovery = true;
    final session = _session;
    // Resume can return from Android settings while native flags are still up.
    if ((isAdvertising || isDiscovering) && !await checkPermissions()) return;
    if (!_current(session)) return;
    await startAutomatic();
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
      const Duration(seconds: 2),
      (_) => unawaited(_connectAvailable()),
    );
    await _connectAvailable();
    _update();
  }

  Future<void> _connectAvailable() {
    if (_connectingAvailable != null) {
      _connectAgain = true;
      return _connectingAvailable!;
    }
    return _connectingAvailable = _connectAvailableNow().whenComplete(() {
      _connectingAvailable = null;
      if (_connectAgain && autoConnect && !_disposed) {
        _connectAgain = false;
        unawaited(_connectAvailable());
      }
    });
  }

  Future<void> _connectAvailableNow() async {
    if (!autoConnect || _autoBusy || _disposed || _connectionBusy) return;
    _autoBusy = true;
    final session = _session;
    try {
      if (!isDiscovering) await startDiscovery();
      if (!_current(session) || !autoConnect || _connectionBusy) return;
      // Lost endpoints are not always reported again by Nearby until a new scan.
      if (!_transferringFiles &&
          _clock().difference(_lastScan ?? DateTime(1970)) >=
              discoveryRefreshInterval) {
        await _rediscover();
      }
      for (final device in discoveredDevices) {
        if (!device.isAvailable || device.isConnected || device.isConnecting) {
          continue;
        }
        // Both devices advertise and scan. Elect one caller by wire identity
        // so simultaneous outbound requests cannot cancel each other.
        // Give the elected caller a head start, then fall back for peers that
        // only advertise and therefore cannot initiate a connection themselves.
        final order = _callerOrder(
          _endpointNames[device.endpointId] ?? device.name,
        );
        if (order > 0 &&
            _clock().difference(
                  _firstFound.putIfAbsent(device.endpointId, _clock),
                ) <
                callerFallbackDelay) {
          continue;
        }
        // Legacy peers with equal names still need jitter.
        if (order == 0) {
          await Future<void>.delayed(
            Duration(milliseconds: 200 + Random().nextInt(1000)),
          );
        }
        if (!_current(session) || !autoConnect || _connectionBusy) return;
        if (device.isAvailable &&
            !_clock().isBefore(
              _retryAfter[device.endpointId] ?? DateTime(1970),
            )) {
          await requestConnection(device.endpointId);
          return; // Native request completion is not the connection result.
        }
      }
    } finally {
      _autoBusy = false;
    }
  }

  Future<void> _rediscover() => _refreshingDiscovery ??= (() async {
    final session = _session;
    if (!autoConnect ||
        !_current(session) ||
        _connectionBusy ||
        _transferringFiles) {
      return;
    }
    await stopDiscovery();
    if (!autoConnect ||
        !_current(session) ||
        _connectionBusy ||
        _transferringFiles) {
      return;
    }
    await startDiscovery();
  })().whenComplete(() => _refreshingDiscovery = null);

  Future<void> _recoverConnection(int session, String id) async {
    if (!_current(session) || !_recovering.add(id)) return;
    _timeouts.remove(id)?.cancel();
    _accepting.remove(id);
    _attemptTokens.remove(id);
    _retryAfter[id] = _clock().add(Duration(seconds: 2 + Random().nextInt(4)));
    try {
      await _nearby
          .disconnectFromEndpoint(id)
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      _log('Connection cleanup: $e');
    }
    if (!_current(session)) return;
    _recovering.remove(id);
    final device = _devices[id];
    if (device != null) {
      device.isConnecting = false;
      device.isConnected = false;
    }
    _update();
    if (connectedDevices.isEmpty) await _rediscover();
    if (autoConnect) unawaited(_connectAvailable());
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

  void _log(String text, {bool notify = true}) {
    if (_disposed) return;
    _append(
      logs,
      '${DateTime.now().toIso8601String().substring(11, 19)} $text',
    );
    debugPrint('[RescueLink] $text');
    if (notify) _update();
  }

  void reportError(String text) {
    if (_disposed) return;
    lastError = text;
    connectionStatus = text;
    _log(text);
  }

  void _reportConnectionIssue(String text) {
    // Automatic recovery is an ongoing connection state. Inserting an error
    // card on every attempt moves the entire Nearby page up and down.
    if (autoConnect) {
      _log(text);
    } else {
      reportError(text);
    }
  }

  void setName(String text) {
    if (!hasActivity && text.trim().isNotEmpty) deviceName = text.trim();
  }

  Future<bool> checkPermissions() {
    final pending = _permissionCheck;
    if (pending != null) return pending;
    _isCheckingPermissions = true;
    _update();
    return _permissionCheck = _checkPermissions();
  }

  Future<bool> _checkPermissions() async {
    try {
      final ready = await Future.sync(permissions.ensureReady);
      if (!ready) reportError(permissions.error ?? 'Permissions required.');
      return ready;
    } finally {
      _isCheckingPermissions = false;
      _hasCheckedPermissions = true;
      _permissionCheck = null;
      _update();
    }
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
        _transportName,
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
      _log('Advertising started as $_advertisedDisplayName');
    } catch (e) {
      if (_current(session)) {
        _log('Advertising start failed: $e');
        reportError(
          'เปิดรับการเชื่อมต่อไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
        );
      }
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
        _transportName,
        strategy,
        serviceId: serviceId,
        onEndpointFound: (id, name, service) {
          if (!_current(session) || service != serviceId) return;
          _endpointNames[id] = name;
          final device = _devices.putIfAbsent(
            id,
            () => NearbyDevice(endpointId: id, name: _displayName(name)),
          );
          device.name = _displayName(name);
          device.isAvailable = true;
          _firstFound.putIfAbsent(id, _clock);
          _log('Found $name ($id)');
          if (autoConnect) unawaited(_connectAvailable());
        },
        onEndpointLost: (id) {
          if (!_current(session)) return;
          final device = _devices[id];
          if (device == null) return;
          device.isAvailable = false;
          if (!device.isConnected && !device.isConnecting) {
            _devices.remove(id);
            _firstFound.remove(id);
            _endpointNames.remove(id);
          }
          _log('Endpoint lost: ${device.name}');
        },
      );
      if (!_current(session)) {
        await _nearby.stopDiscovery();
        return;
      }
      if (!ok) throw StateError('Nearby returned false');
      isDiscovering = true;
      _lastScan = _clock();
      lastError = null;
      connectionStatus = 'Discovering nearby RescueLink devices...';
      _log('Discovery started');
    } catch (e) {
      if (_current(session)) {
        _log('Discovery start failed: $e');
        reportError(
          'ค้นหาอุปกรณ์ไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
        );
      }
    }
  }

  void _startTimeout(int session, String id) {
    _timeouts.remove(id)?.cancel();
    _timeouts[id] = Timer(connectionTimeout, () {
      if (!_current(session) || _devices[id]?.isConnecting != true) return;
      _reportConnectionIssue(
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
        device.isConnecting ||
        _connectionBusy) {
      return;
    }
    final session = _session;
    if ((_foreground && !await checkPermissions()) || !_current(session)) {
      return;
    }
    if (device.isConnected || device.isConnecting || _connectionBusy) return;
    final attempt = Object();
    _attemptTokens[id] = attempt;
    device.isConnecting = true;
    _startTimeout(session, id);
    _log('Connection requested: ${device.name}');
    try {
      final ok = await _nearby
          .requestConnection(
            _transportName,
            id,
            onConnectionInitiated: (id, info) {
              if (_attemptTokens[id] == attempt) _initiated(session, id, info);
            },
            onConnectionResult: (id, status) {
              if (_attemptTokens[id] == attempt) _result(session, id, status);
            },
            onDisconnected: (id) => _disconnected(session, id),
          )
          .timeout(connectionTimeout);
      if (!ok) throw StateError('Nearby returned false');
    } catch (e) {
      if (!_current(session) ||
          _attemptTokens[id] != attempt ||
          _devices[id] != device ||
          !device.isConnecting ||
          _recovering.contains(id)) {
        return;
      }
      _timeouts.remove(id)?.cancel();
      _log('Connection failed: $e');
      _reportConnectionIssue(
        'ยังเชื่อมต่อกับ ${device.name} ไม่สำเร็จ ตรวจว่าอีกเครื่องเปิดรับการเชื่อมต่อและเปิด Bluetooth/Wi-Fi แล้ว ระบบจะลองใหม่อัตโนมัติ',
      );
      await _recoverConnection(session, id);
    }
  }

  void _initiated(int session, String id, ConnectionInfo info) {
    if (!_current(session) ||
        _recovering.contains(id) ||
        _devices[id]?.isConnected == true) {
      return;
    }
    if (_devices[id]?.isConnecting != true && _connectionBusy) {
      // Let this peer retry after the active handshake. Do not disturb links
      // which are already connected to the relay.
      unawaited(_rejectBusyConnection(session, id));
      return;
    }
    if (_devices[id]?.isConnected == true || !_accepting.add(id)) return;
    final device = _devices.putIfAbsent(
      id,
      () => NearbyDevice(endpointId: id, name: _displayName(info.endpointName)),
    );
    _endpointNames[id] = info.endpointName;
    device.name = _displayName(info.endpointName);
    device.isConnecting = true;
    if (!_timeouts.containsKey(id)) _startTimeout(session, id);
    _log(
      'Connection initiated: ${info.endpointName}; code ${info.authenticationToken} (POC auto-accept)',
    );
    // TODO: Final version should allow the user to approve/reject nearby connections.
    // Both advertiser and discoverer must accept. Only use with test phones.
    unawaited(acceptConnection(id));
  }

  Future<void> _rejectBusyConnection(int session, String id) async {
    try {
      await _nearby.rejectConnection(id).timeout(const Duration(seconds: 3));
    } catch (e) {
      if (_current(session)) _log('Busy connection rejection: $e');
    }
  }

  Future<void> acceptConnection(String id) async {
    final session = _session;
    final device = _devices[id];
    if (!_current(session)) return;
    try {
      final ok = await _nearby
          .acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              if (!_current(session)) return;

              // ─── FILE payload ─────────────────────────────────────────────────
              if (payload.type == PayloadType.FILE) {
                _pendingFileUris[payload.id] = payload.uri;
                _fileEndpoints[payload.id] = endpointId;
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
                reportError(
                  'อ่านข้อความที่ได้รับไม่ได้ กรุณาให้อีกเครื่องส่งใหม่',
                );
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
                  _log(
                    'Payload ${update.id} file transfer successful',
                    notify: false,
                  );
                  onFileTransferSuccess?.call(endpointId, update.id);
                  _pendingFileUris.remove(update.id);
                  _sentFilePayloads.remove(update.id);
                  _fileEndpoints.remove(update.id);
                } else if (update.status == PayloadStatus.FAILURE ||
                    update.status == PayloadStatus.CANCELED) {
                  _log(
                    'File payload ${update.id} failed/canceled for $endpointId.',
                    notify: false,
                  );
                  onFileTransferFailed?.call(endpointId, update.id);
                  _pendingFileUris.remove(update.id);
                  _sentFilePayloads.remove(update.id);
                  _fileEndpoints.remove(update.id);
                }
                return;
              }
              // BYTES payload status updates (ข้อความธรรมดา)
              if (update.status == PayloadStatus.FAILURE ||
                  update.status == PayloadStatus.CANCELED) {
                _log(
                  'Payload ${update.id} transfer failed/canceled for $endpointId.',
                  notify: false,
                );
              } else if (update.status == PayloadStatus.SUCCESS) {
                _log('Payload ${update.id} transfer successful', notify: false);
              }
            },
          )
          .timeout(connectionTimeout);
      if (!ok) throw StateError('Nearby returned false');
    } catch (e) {
      if (!_current(session) ||
          _devices[id] != device ||
          device?.isConnecting != true) {
        return;
      }
      _log('Accept connection failed: $e');
      _reportConnectionIssue(
        'ตอบรับการเชื่อมต่อไม่สำเร็จ ระบบกำลังค้นหาอีกครั้ง กรุณาเปิดรับการเชื่อมต่อทั้งสองเครื่อง',
      );
      await _recoverConnection(session, id);
    }
  }

  void _result(int session, String id, Status status) {
    if (!_current(session) || _recovering.contains(id)) return;
    _timeouts.remove(id)?.cancel();
    final device = _devices[id];
    if (device == null || !device.isConnecting) return;
    device.isConnecting = false;
    device.isConnected = status == Status.CONNECTED;
    if (device.isConnected) {
      _accepting.remove(id);
      _retryAfter.remove(id);
      lastError = null;
      connectionStatus = 'Connected to ${device.name}';
      _log(connectionStatus);
      if (autoConnect) unawaited(_connectAvailable());
      // Keep an explicitly started scan active so a relay can find more peers.
      // The caller can stopDiscovery once all intended links are connected.
    } else {
      _reportConnectionIssue(
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
    _firstFound.remove(id);
    _endpointNames.remove(id);
    _attemptTokens.remove(id);
    for (final payloadId in _fileEndpoints.keys.toList()) {
      if (_fileEndpoints[payloadId] != id) continue;
      _pendingFileUris.remove(payloadId);
      _sentFilePayloads.remove(payloadId);
      _fileEndpoints.remove(payloadId);
      onFileTransferFailed?.call(id, payloadId);
    }
    connectionStatus =
        'ขาดการเชื่อมต่อกับ ${device?.name ?? id} • กำลังรอเชื่อมต่อใหม่';
    _log(connectionStatus);
    if (autoConnect) unawaited(_rediscover());
    if (autoConnect) unawaited(_connectAvailable());
  }

  Future<bool> sendTextMessage(String text) async {
    if (_disposed || (!_foreground && !backgroundActive)) return false;
    final session = _session;
    text = text.trim();
    if (text.isEmpty) {
      reportError('กรุณาพิมพ์ข้อความก่อนส่ง');
      return false;
    }
    final bytes = Uint8List.fromList(utf8.encode(text));
    if (bytes.length > 32768) {
      reportError('ข้อความยาวเกินไป กรุณาแบ่งเป็นข้อความสั้นลง');
      return false;
    }
    final peers = connectedDevices;
    if (peers.isEmpty) {
      reportError('กรุณาเชื่อมต่อกับอุปกรณ์ใกล้เคียงก่อนส่ง');
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
        reportError(
          'ส่งข้อความไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
        );
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
    // Bound native enqueue time, not radio delivery time. A late native send
    // may still arrive; durable IDs and destination ACKs make retry safe.
    await _nearby
        .sendBytesPayload(endpointId, bytes)
        .timeout(payloadSendTimeout);
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
    final session = _session;
    _sendingFiles++;
    try {
      final payloadId = await _nearby.sendFilePayload(endpointId, filePath);
      if (!_current(session) ||
          !connectedDevices.any((d) => d.endpointId == endpointId)) {
        throw StateError('Peer disconnected');
      }
      _sentFilePayloads.add(payloadId);
      _fileEndpoints[payloadId] = endpointId;
      return payloadId;
    } finally {
      if (session == _session) _sendingFiles--;
    }
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
      reportError(
        'หยุดเปิดรับการเชื่อมต่อไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
      );
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
      isDiscovering = false;
      _log('Discovery stopped');
    } catch (e) {
      reportError(
        'หยุดค้นหาอุปกรณ์ไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
      );
    }
  }

  Future<void> disconnect(String id) async {
    final session = _session;
    try {
      await _nearby.disconnectFromEndpoint(id);
      _disconnected(session, id);
    } catch (e) {
      reportError(
        'ตัดการเชื่อมต่อไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
      );
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
    _firstFound.clear();
    _endpointNames.clear();
    _recovering.clear();
    _attemptTokens.clear();
    _advertisedName = null;
    _advertisedDisplayName = null;
    _sendingFiles = 0;
    _fileEndpoints.clear();
    _connectAgain = false;
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
      reportError(
        'หยุดการเชื่อมต่อไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
      );
    }
    try {
      await connectionSession.stop();
    } catch (e) {
      reportError(
        'หยุดการทำงานเบื้องหลังไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
      );
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
