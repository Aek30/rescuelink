import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'nearby_service_test.dart' show TestNearby, TestPermissions, TestSession;

void main() {
  late TestNearby native;
  late NearbyService service;
  late DateTime now;

  setUp(() {
    now = DateTime(2026);
    native = TestNearby();
    service = NearbyService(
      nearby: native,
      permissions: TestPermissions(),
      session: TestSession(),
      clock: () => now,
    )..setName('Rescue-0');
  });

  tearDown(() async {
    await service.stopAll();
    service.dispose();
  });

  test('four nearby peers connect one handshake at a time', () async {
    await service.startNearby();
    for (final id in ['A', 'B', 'C', 'D']) {
      native.found(id, 'Rescue-$id', NearbyService.serviceId);
    }
    await Future<void>.delayed(Duration.zero);
    expect(native.requested, ['A']);
    for (final id in ['A', 'B', 'C', 'D']) {
      native.initiated(id, ConnectionInfo('Rescue-$id', '1234', false));
      await Future<void>.delayed(Duration.zero);
      native.result(id, Status.CONNECTED);
      await Future<void>.delayed(Duration.zero);
      expect(service.connectedDevices.last.endpointId, id);
      expect(
        service.discoveredDevices.where((d) => d.isConnecting).length,
        lessThanOrEqualTo(1),
      );
    }
    expect(native.requested, ['A', 'B', 'C', 'D']);
    expect(service.connectedDevices, hasLength(4));
  });

  test(
    'identical Thai names elect exactly one initial caller and stay readable',
    () async {
      service.setName('ผู้ช่วยเหลือ');
      final otherNative = TestNearby();
      final other = NearbyService(
        nearby: otherNative,
        permissions: TestPermissions(),
        session: TestSession(),
        clock: () => now,
      )..setName('ผู้ช่วยเหลือ');
      try {
        await service.startNearby();
        await other.startNearby();
        native.found(
          'other',
          otherNative.advertisedName!,
          NearbyService.serviceId,
        );
        otherNative.found(
          'local',
          native.advertisedName!,
          NearbyService.serviceId,
        );
        await Future<void>.delayed(Duration.zero);
        expect(native.requested.length + otherNative.requested.length, 1);
        expect(service.discoveredDevices.single.name, 'ผู้ช่วยเหลือ');
        expect(other.discoveredDevices.single.name, 'ผู้ช่วยเหลือ');
        expect(native.discoveryName, native.advertisedName);
        expect(otherNative.discoveryName, otherNative.advertisedName);
      } finally {
        await other.stopAll();
        other.dispose();
      }
    },
  );

  test(
    'profile updates do not change election or outgoing wire identity',
    () async {
      await service.startNearby();
      final advertised = native.advertisedName;
      service.deviceName = 'Rescue-Z';
      native.found('A', 'Rescue-A', NearbyService.serviceId);
      await Future<void>.delayed(Duration.zero);
      expect(native.requested, ['A']);
      expect(native.requestNames.single, advertised);
      await service.stopAll();
      await service.startNearby();
      expect(native.advertisedName, endsWith(':Rescue-Z'));
    },
  );

  test('incoming peer waits while another handshake is active', () async {
    await service.startNearby();
    final incoming = native.initiated;
    final incomingResult = native.result;
    native.found('A', 'Rescue-A', NearbyService.serviceId);
    await Future<void>.delayed(Duration.zero);
    incoming('B', ConnectionInfo('Rescue-B', '1234', true));
    await Future<void>.delayed(Duration.zero);
    expect(native.rejected, ['B']);
    expect(native.accepted, 0);
    native.result('A', Status.CONNECTED);
    incoming('B', ConnectionInfo('Rescue-B', '1234', true));
    await Future<void>.delayed(Duration.zero);
    incomingResult('B', Status.CONNECTED);
    expect(service.connectedDevices, hasLength(2));
    await service.stopAll();
  });

  testWidgets('idle refresh keeps existing links and discovers a third node', (
    tester,
  ) async {
    await service.startNearby();
    native.found('A', 'Rescue-A', NearbyService.serviceId);
    await tester.pump();
    native.result('A', Status.CONNECTED);
    await tester.pump();
    final scans = native.discoveryCalls;
    now = now.add(NearbyService.discoveryRefreshInterval);
    await tester.pump(NearbyService.discoveryRefreshInterval);
    expect(native.discoveryCalls, greaterThan(scans));
    expect(service.connectedDevices.single.endpointId, 'A');
    native.found('C', 'Rescue-C', NearbyService.serviceId);
    await tester.pump();
    native.result('C', Status.CONNECTED);
    expect(service.connectedDevices, hasLength(2));
    await service.stopAll();
  });

  testWidgets('refresh waits for file transfer completion', (tester) async {
    await service.startNearby();
    native.found('A', 'Rescue-A', NearbyService.serviceId);
    await tester.pump();
    native.initiated('A', ConnectionInfo('Rescue-A', '1234', false));
    await tester.pump();
    native.result('A', Status.CONNECTED);
    await tester.pump();
    final scans = native.discoveryCalls;
    final payloadId = await service.sendFile('A', 'photo.jpg');
    now = now.add(NearbyService.discoveryRefreshInterval);
    await tester.pump(NearbyService.discoveryRefreshInterval);
    expect(native.discoveryCalls, scans);
    native.transfer!(
      'A',
      PayloadTransferUpdate(
        id: payloadId,
        bytesTransferred: 100,
        totalBytes: 100,
        status: PayloadStatus.SUCCESS,
      ),
    );
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(native.discoveryCalls, greaterThan(scans));
    expect(service.connectedDevices, hasLength(1));
    await service.stopAll();
  });

  testWidgets('stuck native request times out and releases the next peer', (
    tester,
  ) async {
    await service.startNearby();
    final stuck = Completer<bool>();
    native.pendingRequest = stuck;
    native.found('A', 'Rescue-A', NearbyService.serviceId);
    await tester.pump();
    final lateResult = native.result;
    final lateInitiated = native.initiated;
    native.found('B', 'Rescue-B', NearbyService.serviceId);
    native.pendingRequest = null;
    now = now.add(NearbyService.connectionTimeout);
    await tester.pump(NearbyService.connectionTimeout);
    expect(native.requested, ['A', 'B']);
    lateInitiated('A', ConnectionInfo('Rescue-A', '1234', false));
    lateResult('A', Status.CONNECTED);
    stuck.complete(true);
    await tester.pump();
    expect(service.connectedDevices, isEmpty);
    native.result('B', Status.CONNECTED);
    expect(service.connectedDevices.single.endpointId, 'B');
    await service.stopAll();
  });
}
