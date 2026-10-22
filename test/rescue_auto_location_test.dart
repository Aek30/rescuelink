import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'message_service_test.dart' show Transport;

void main() {
  sqfliteFfiInit();
  late LocalDatabaseService db;
  late Transport transport;
  late MessageService service;
  late Completer<SosLocation> capture;
  late int captures;
  final fix = SosLocation(
    latitude: 14.036,
    longitude: 100.728,
    accuracy: 8,
    capturedAt: DateTime.now().toUtc(),
  );

  Future<void> settled() async {
    if (!service.rescueLocationLoading) return;
    final done = Completer<void>();
    void listener() {
      if (!service.rescueLocationLoading && !done.isCompleted) done.complete();
    }

    service.addListener(listener);
    try {
      await done.future;
    } finally {
      service.removeListener(listener);
    }
  }

  setUp(() async {
    db = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    transport = Transport();
    capture = Completer<SosLocation>();
    captures = 0;
    service = MessageService(
      nearbyService: transport,
      database: db,
      captureRescueLocation: () {
        captures++;
        return capture.future;
      },
    );
    await service.initialize();
  });
  tearDown(() async {
    service.dispose();
    transport.dispose();
    if (!capture.isCompleted) capture.complete(fix);
    await db.close();
  });

  test(
    'enabling rescue automatically captures; disabling removes location',
    () async {
      await service.setRescueMode(true);
      expect(captures, 1);
      expect(service.rescueLocationLoading, isTrue);
      capture.complete(fix);
      await settled();
      expect(service.rescueLocation, same(fix));
      expect(service.rescueLocationError, isNull);
      await service.setRescueMode(false);
      expect(service.rescueLocation, isNull);
      expect(service.rescueLocationLoading, isFalse);
    },
  );

  test(
    'GPS completing after rescue is disabled cannot share location',
    () async {
      await service.setRescueMode(true);
      await service.setRescueMode(false);
      capture.complete(fix);
      await Future<void>.delayed(Duration.zero);
      expect(service.rescueLocation, isNull);
      expect(service.rescueLocationError, isNull);
    },
  );

  test('GPS failure keeps rescue enabled and update retries capture', () async {
    await service.setRescueMode(true);
    capture.completeError(StateError('GPS disabled'));
    await settled();
    expect(service.rescueMode, isTrue);
    expect(service.rescueLocation, isNull);
    expect(service.rescueLocationError, contains('ยังแชร์ตำแหน่งไม่ได้'));
    capture = Completer<SosLocation>();
    final update = service.updateRescueLocation();
    capture.complete(fix);
    expect(await update, same(fix));
    expect(captures, 2);
    expect(service.rescueLocationError, isNull);
  });

  test(
    'switching to SOS cancels an unfinished rescue location capture',
    () async {
      await service.setRescueMode(true);
      await service.publishSos(
        name: 'ฉัน',
        people: 1,
        category: EmergencyType.other,
        details: 'ขอความช่วยเหลือ',
        recipients: {},
      );
      capture.complete(fix);
      await Future<void>.delayed(Duration.zero);
      expect(service.rescueMode, isFalse);
      expect(service.rescueLocation, isNull);
      expect(service.rescueLocationLoading, isFalse);
    },
  );

  test(
    'switching off and on during capture shares only for current mode',
    () async {
      await service.setRescueMode(true);
      await service.setRescueMode(false);
      await service.setRescueMode(true);
      expect(captures, 1);
      capture.complete(fix);
      await settled();
      expect(service.rescueMode, isTrue);
      expect(service.rescueLocation, same(fix));
    },
  );

  test(
    'restored rescue mode automatically captures a fresh location',
    () async {
      await db.setSetting('rescueMode', 'true');
      service.dispose();
      service = MessageService(
        nearbyService: transport,
        database: db,
        captureRescueLocation: () {
          captures++;
          return capture.future;
        },
      );
      await service.initialize();
      expect(service.rescueMode, isTrue);
      expect(captures, 1);
      capture.complete(fix);
      await settled();
      expect(service.rescueLocation, same(fix));
    },
  );
}
