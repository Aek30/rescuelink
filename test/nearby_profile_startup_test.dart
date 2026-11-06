import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/nearby_test_screen.dart';
import 'package:rescuelink/services/app_preferences.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:rescuelink/services/sos_location_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Native extends Fake implements Nearby {}

class _Nearby extends NearbyService {
  _Nearby() : super(nearby: _Native());
  final startedNames = <String>[];
  @override
  Future<void> startNearby() async => startedNames.add(deviceName);
  @override
  Future<void> stopAll() async {}
}

class _Messages extends MessageService {
  _Messages({required super.nearbyService, required super.database});
  final initialized = Completer<void>();
  @override
  Future<void> initialize() => initialized.future;
}

class _ProfileDatabase extends LocalDatabaseService {
  _ProfileDatabase()
    : super(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  final readingName = Completer<void>();
  final allowName = Completer<void>();
  @override
  Future<String?> getSetting(String key) async {
    if (key == 'profileNameDraft') {
      readingName.complete();
      await allowName.future;
    }
    return super.getSetting(key);
  }
}

class _NoLocation extends SosLocationService {
  @override
  Future<SosLocation?> lastKnown() async => null;
  @override
  Future<SosLocation> capture() async => throw StateError('No GPS in test');
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  testWidgets('startup waits for saved Thai profile and relay initialization', (
    tester,
  ) async {
    final previousDatabase = LocalDatabaseService.instance;
    final database = _ProfileDatabase();
    LocalDatabaseService.instance = database;
    AppPreferences.instance.reset();
    final nearby = _Nearby();
    final messages = _Messages(nearbyService: nearby, database: database);
    final loaded = Completer<void>();
    void profileLoaded() {
      if (AppPreferences.instance.displayName == 'เครื่องกลาง' &&
          !loaded.isCompleted) {
        loaded.complete();
      }
    }

    AppPreferences.instance.addListener(profileLoaded);
    try {
      await tester.runAsync(
        () => database.setSetting('profileNameDraft', 'เครื่องกลาง'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NearbyTestScreen(
            nearbyService: nearby,
            messageService: messages,
            locationService: _NoLocation(),
          ),
        ),
      );
      for (var i = 0; i < 200 && !database.readingName.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(database.readingName.isCompleted, isTrue);
      expect(nearby.startedNames, isEmpty);
      database.allowName.complete();
      for (var i = 0; i < 200 && !loaded.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(loaded.isCompleted, isTrue);
      await tester.pump();
      expect(nearby.startedNames, isEmpty);
      messages.initialized.complete();
      await tester.pumpAndSettle();
      expect(nearby.startedNames, ['เครื่องกลาง']);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      AppPreferences.instance.removeListener(profileLoaded);
      LocalDatabaseService.instance = previousDatabase;
      AppPreferences.instance.reset();
      await tester.runAsync(database.close);
    }
  });
}
