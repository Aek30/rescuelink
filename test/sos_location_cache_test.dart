import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/sos_location_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late LocalDatabaseService database;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sos-location-test');
    database = LocalDatabaseService(
      factory: databaseFactoryFfi,
      path: '${directory.path}/test.db',
    );
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(SosLocationService.channel, null);
    await (await database.database).close();
    await directory.delete(recursive: true);
  });
  SosLocationService service({bool allowed = true}) => SosLocationService(
    database: database,
    requestPermission: () async => allowed,
  );

  test(
    'fresh fix survives database reopen and GPS failure without changing time',
    () async {
      final capturedAt = DateTime.now().toUtc();
      messenger.setMockMethodCallHandler(
        SosLocationService.channel,
        (_) async => {
          'latitude': 14.0,
          'longitude': 100.0,
          'accuracy': 12.0,
          'capturedAt': capturedAt.toIso8601String(),
        },
      );
      final fresh = await service().captureWithFallback();
      expect(fresh.cached, isFalse);
      await (await database.database).close();
      database = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: '${directory.path}/test.db',
      );
      messenger.setMockMethodCallHandler(
        SosLocationService.channel,
        (_) async => throw PlatformException(code: 'timeout'),
      );
      final fallback = await service().captureWithFallback();
      expect(fallback.cached, isTrue);
      expect(fallback.location.capturedAt, capturedAt);
      expect(fallback.location.latitude, 14);
      expect(fallback.location.accuracy, 12);
      expect(
        (await service(allowed: false).captureWithFallback()).cached,
        isTrue,
      );
    },
  );

  test('missing or corrupt cache does not manufacture a location', () async {
    expect(await service().lastKnown(), isNull);
    await database.setSetting('sos.lastKnownLocation.v1', 'broken');
    expect(await service().lastKnown(), isNull);
    await expectLater(
      service(allowed: false).captureWithFallback(),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'old cache keeps its original age and future coordinates are rejected',
    () async {
      final old = DateTime.now().toUtc().subtract(const Duration(days: 3));
      Map<String, Object> fix(DateTime time) => {
        'latitude': 14.0,
        'longitude': 100.0,
        'accuracy': 25.0,
        'capturedAt': time.toIso8601String(),
      };
      await database.setSetting(
        'sos.lastKnownLocation.v1',
        jsonEncode(fix(old)),
      );
      expect(
        (await service(
          allowed: false,
        ).captureWithFallback()).location.capturedAt,
        old,
      );
      await database.setSetting(
        'sos.lastKnownLocation.v1',
        jsonEncode(fix(DateTime.now().toUtc().add(const Duration(days: 1)))),
      );
      expect(await service().lastKnown(), isNull);
    },
  );
}
