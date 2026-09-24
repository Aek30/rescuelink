import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:rescuelink/services/permission_service.dart';

class TestPermissions extends PermissionService {
  bool allowed = true;
  Completer<bool>? pending;
  @override
  Future<bool> ensureReady() async {
    error = allowed ? null : 'Nearby Devices permission denied';
    return pending == null ? allowed : await pending!.future;
  }
}

class TestNearby extends Fake implements Nearby {
  late OnEndpointFound found;
  late OnEndpointLost lost;
  late OnConnectionInitiated initiated;
  late OnConnectionResult result;
  late OnDisconnected disconnected;
  late OnPayloadReceived received;
  OnPayloadTransferUpdate? transfer;
  bool advertiseOk = true;
  bool discoveryOk = true;
  bool requestOk = true;
  bool acceptOk = true;
  bool sendFails = false;
  bool stopFails = false;
  int advertiseCalls = 0;
  int accepted = 0;
  int stopped = 0;
  Uint8List? sent;

  @override
  Future<bool> startAdvertising(
    String name,
    Strategy strategy, {
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
    String serviceId = '',
  }) async {
    advertiseCalls++;
    expect(strategy, Strategy.P2P_CLUSTER);
    expect(serviceId, 'com.rmutt.rescuelink');
    initiated = onConnectionInitiated;
    result = onConnectionResult;
    disconnected = onDisconnected;
    return advertiseOk;
  }

  @override
  Future<bool> startDiscovery(
    String name,
    Strategy strategy, {
    required OnEndpointFound onEndpointFound,
    required OnEndpointLost onEndpointLost,
    String serviceId = '',
  }) async {
    expect(strategy, Strategy.P2P_CLUSTER);
    expect(serviceId, 'com.rmutt.rescuelink');
    found = onEndpointFound;
    lost = onEndpointLost;
    return discoveryOk;
  }

  @override
  Future<bool> requestConnection(
    String name,
    String id, {
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) async {
    initiated = onConnectionInitiated;
    result = onConnectionResult;
    disconnected = onDisconnected;
    return requestOk;
  }

  @override
  Future<bool> acceptConnection(
    String id, {
    required OnPayloadReceived onPayLoadRecieved,
    OnPayloadTransferUpdate? onPayloadTransferUpdate,
  }) async {
    accepted++;
    received = onPayLoadRecieved;
    transfer = onPayloadTransferUpdate;
    return acceptOk;
  }

  @override
  Future<void> sendBytesPayload(String id, Uint8List bytes) async {
    if (sendFails) throw StateError('Radio lost');
    sent = bytes;
  }

  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> stopAllEndpoints() async {
    stopped++;
    if (stopFails) throw StateError('Native cleanup failed');
  }

  @override
  Future<void> disconnectFromEndpoint(String id) async {}
}

void main() {
  late TestNearby native;
  late TestPermissions permissions;
  late NearbyService service;
  setUp(() {
    native = TestNearby();
    permissions = TestPermissions();
    service = NearbyService(nearby: native, permissions: permissions);
  });
  tearDown(() async {
    await service.stopAll();
    service.dispose();
  });

  Future<void> connect() async {
    await service.startDiscovery();
    native.found('A', 'Rescue-A', NearbyService.serviceId);
    await service.requestConnection('A');
    native.initiated('A', ConnectionInfo('Rescue-A', '1234', false));
    await Future<void>.delayed(Duration.zero);
    native.result('A', Status.CONNECTED);
  }

  test('permission matrix covers Android 11, 12, 12L and 13+', () {
    expect(PermissionService.requiredPermissions(30), [
      Permission.locationWhenInUse,
    ]);
    for (final sdk in [31, 32]) {
      final required = PermissionService.requiredPermissions(sdk);
      expect(required, contains(Permission.locationWhenInUse));
      expect(required, contains(Permission.bluetoothScan));
      expect(required, isNot(contains(Permission.nearbyWifiDevices)));
    }
    for (final sdk in [33, 34, 35, 36]) {
      final required = PermissionService.requiredPermissions(sdk);
      expect(required, contains(Permission.nearbyWifiDevices));
      expect(required, isNot(contains(Permission.locationWhenInUse)));
    }
  });

  test('permission display accepts exemptions but rejects disabled radio', () {
    expect(
      PermissionService.statusIsReady(
        'Not required for permission on Android 13+',
      ),
      isTrue,
    );
    expect(
      PermissionService.statusIsReady('Uses Location on this Android version'),
      isTrue,
    );
    expect(
      PermissionService.statusIsReady('Permission granted; radio off'),
      isFalse,
    );
    expect(PermissionService.statusIsReady('Denied'), isFalse);
    expect(PermissionService.statusIsReady('Not checked'), isFalse);
  });
  test('failed native STOP still invalidates local endpoints', () async {
    await connect();
    native.stopFails = true;
    await service.stopAll();
    expect(service.connectedDevices, isEmpty);
    await expectLater(service.sendMessage('A', '{}'), throwsStateError);
  });
  test('permission denial prevents native advertising', () async {
    permissions.allowed = false;
    await service.startAdvertising();
    expect(native.advertiseCalls, 0);
    expect(service.lastError, contains('permission denied'));
  });

  test('false advertising and discovery results become errors', () async {
    native.advertiseOk = false;
    native.discoveryOk = false;
    await service.startAdvertising();
    expect(service.isAdvertising, isFalse);
    expect(service.lastError, contains('Advertising start failed'));
    await service.startDiscovery();
    expect(service.isDiscovering, isFalse);
    expect(service.lastError, contains('Discovery start failed'));
  });

  test(
    'discovery deduplicates, filters service and removes lost endpoint',
    () async {
      await service.startDiscovery();
      native.found('A', 'Rescue-A', NearbyService.serviceId);
      native.found('A', 'Rescue-A', NearbyService.serviceId);
      native.found('X', 'Other app', 'other.service');
      expect(service.discoveredDevices, hasLength(1));
      native.lost('A');
      expect(service.discoveredDevices, isEmpty);
    },
  );

  test(
    'outgoing connection auto-accepts and supports UTF-8 in both directions',
    () async {
      await connect();
      expect(native.accepted, 1);
      expect(service.connectedDevices.single.name, 'Rescue-A');
      expect(await service.sendTextMessage('Hello A สวัสดี'), isTrue);
      expect(utf8.decode(native.sent!), 'Hello A สวัสดี');
      native.received(
        'A',
        Payload(
          id: 1,
          type: PayloadType.BYTES,
          bytes: Uint8List.fromList(utf8.encode('Hello B สวัสดี')),
        ),
      );
      expect(service.receivedMessages.single, 'Rescue-A: Hello B สวัสดี');
      native.disconnected('A');
      expect(service.connectedDevices, isEmpty);
    },
  );

  test('advertiser handles incoming peer not in discovery list', () async {
    await service.startAdvertising();
    native.initiated('B', ConnectionInfo('Rescue-B', '1234', true));
    await Future<void>.delayed(Duration.zero);
    native.result('B', Status.CONNECTED);
    expect(native.accepted, 1);
    expect(service.connectedDevices.single.name, 'Rescue-B');
  });

  test('reject and connection failure reset connecting state', () async {
    await service.startDiscovery();
    native.found('A', 'Rescue-A', NearbyService.serviceId);
    await service.requestConnection('A');
    native.result('A', Status.REJECTED);
    expect(service.lastError, contains('rejected'));
    expect(service.discoveredDevices.single.isConnecting, isFalse);
    native.requestOk = false;
    await service.requestConnection('A');
    expect(service.lastError, contains('Connection failed'));
    expect(service.discoveredDevices.single.isConnecting, isFalse);
  });

  test(
    'empty, disconnected, oversized and native send failures are handled',
    () async {
      expect(await service.sendTextMessage('  '), isFalse);
      expect(await service.sendTextMessage('hello'), isFalse);
      await connect();
      expect(await service.sendTextMessage('ก' * 11000), isFalse);
      native.sendFails = true;
      expect(await service.sendTextMessage('hello'), isFalse);
      expect(service.messages, isEmpty);
      expect(service.lastError, contains('Send to Rescue-A failed'));
    },
  );

  test('malformed UTF-8 and failed transfer produce errors', () async {
    await connect();
    native.received(
      'A',
      Payload(
        id: 2,
        type: PayloadType.BYTES,
        bytes: Uint8List.fromList([0xFF]),
      ),
    );
    expect(service.receivedMessages, isEmpty);
    expect(service.lastError, contains('invalid UTF-8'));
    native.transfer!(
      'A',
      PayloadTransferUpdate(
        id: 2,
        bytesTransferred: 0,
        totalBytes: 1,
        status: PayloadStatus.FAILURE,
      ),
    );
    expect(service.lastError, contains('failed/canceled'));
  });

  test('STOP clears peers and ignores late callbacks', () async {
    await connect();
    await service.stopAll();
    native.found('LATE', 'Old endpoint', NearbyService.serviceId);
    native.result('A', Status.CONNECTED);
    expect(service.discoveredDevices, isEmpty);
    expect(service.connectedDevices, isEmpty);
    expect(native.stopped, greaterThan(0));
  });

  test('STOP during permission prompt cancels the pending start', () async {
    permissions.pending = Completer<bool>();
    final start = service.startAdvertising();
    await Future<void>.delayed(Duration.zero);
    await service.stopAll();
    permissions.pending!.complete(true);
    await start;
    expect(native.advertiseCalls, 0);
  });

  test(
    'background cleanup blocks new sessions until foreground resumes',
    () async {
      service.setForeground(false);
      await service.startAdvertising();
      expect(native.advertiseCalls, 0);
      service.setForeground(true);
      await service.startAdvertising();
      expect(native.advertiseCalls, 1);
    },
  );

  testWidgets('unanswered connection times out and removes pending peer', (
    tester,
  ) async {
    await service.startDiscovery();
    native.found('A', 'Rescue-A', NearbyService.serviceId);
    await service.requestConnection('A');
    await tester.pump(const Duration(seconds: 31));
    expect(service.discoveredDevices, isEmpty);
    expect(service.lastError, contains('timed out'));
  });
}
