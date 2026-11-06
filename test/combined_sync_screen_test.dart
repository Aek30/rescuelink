import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/screens/sync_screen.dart';
import 'package:rescuelink/services/chat_store.dart';
import 'package:rescuelink/services/chat_sync_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'package:rescuelink/services/sos_sync_service.dart';

class _SosCloud extends Fake implements SosCloud {}

class _ChatCloud extends Fake implements ChatCloud {}

class _SosStore extends SosStore {
  _SosStore() : super(LocalDatabaseService(factory: databaseFactoryFfi));
  @override
  Future<List<SosRecord>> list({bool includeDeleted = false}) async => [];
  @override
  Future<List<Map<String, Object?>>> queue() async => [];
}

class _ChatStore extends ChatStore {
  _ChatStore() : super(LocalDatabaseService(factory: databaseFactoryFfi));
  @override
  Future<List<Map<String, Object?>>> list() async => [];
  @override
  Future<List<Map<String, Object?>>> queue() async => [];
}

class _SosSync extends SosSyncService {
  _SosSync() : super(_SosStore(), _SosCloud());
  final done = Completer<void>();
  int calls = 0;
  @override
  Future<void> sync() async {
    calls++;
    busy = true;
    notifyListeners();
    await done.future;
    lastSuccess = DateTime.now();
    busy = false;
    notifyListeners();
  }
}

class _ChatSync extends ChatSyncService {
  _ChatSync() : super(_ChatStore(), _ChatCloud());
  final done = Completer<void>();
  int calls = 0;
  bool fail = false;
  @override
  Future<void> sync() async {
    calls++;
    busy = true;
    notifyListeners();
    await done.future;
    if (fail) {
      error = 'ข้อความยังซิงก์ไม่สำเร็จ';
    } else {
      lastSuccess = DateTime.now();
    }
    busy = false;
    notifyListeners();
  }
}

void main() {
  testWidgets('sync summary shows explicit Bangkok time on a narrow phone', (
    tester,
  ) async {
    final sos = _SosSync()..lastSuccess = DateTime.utc(2026, 11, 4, 2, 34);
    final chat = _ChatSync()..lastSuccess = DateTime.utc(2026, 11, 4, 4, 21);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SyncScreen(service: sos, chatService: chat),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('04/11/2026 09:34:00 (เวลาไทย)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    sos.dispose();
    chat.dispose();
  });

  for (final fail in [false, true]) {
    testWidgets('one button syncs SOS and messages; chat failure=$fail', (
      tester,
    ) async {
      final sos = _SosSync();
      final chat = _ChatSync()..fail = fail;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: SyncScreen(service: sos, chatService: chat),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('การซิงก์'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('ข้อความ'), findsOneWidget);
      await tester.tap(find.text('ซิงก์ตอนนี้'));
      await tester.pump();
      expect(sos.calls, 1);
      expect(chat.calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      sos.done.complete();
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      chat.done.complete();
      await tester.pumpAndSettle();
      expect(sos.lastSuccess, isNotNull);
      expect(chat.error != null, fail);
      expect(
        find.text('ทุกอย่างซิงก์แล้ว'),
        fail ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      sos.dispose();
      chat.dispose();
    });
  }
}
