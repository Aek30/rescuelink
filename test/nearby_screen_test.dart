import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/screens/nearby_test_screen.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InitializingMessages extends MessageService {
  _InitializingMessages({required super.nearbyService});
  final initialized = Completer<void>();
  @override
  Future<void> initialize() async {
    try {
      await super.initialize();
    } finally {
      initialized.complete();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  testWidgets('nearby page renders and scrolls on a phone', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const events = MethodChannel('nearby_connections/events');
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(events, null));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nearby = NearbyService();
    final messages = _InitializingMessages(nearbyService: nearby);
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
        home: NearbyTestScreen(nearbyService: nearby, messageService: messages),
      ),
    );
    // Startup now waits for SQLite and the relay handlers before scanning.
    // Let real database I/O finish outside the widget test's virtual clock.
    for (var i = 0; i < 200 && !messages.initialized.isCompleted; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(messages.initialized.isCompleted, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const ValueKey('nearby-home-scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
