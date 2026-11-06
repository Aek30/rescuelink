import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:rescuelink/services/chat_store.dart';
import 'package:rescuelink/services/chat_sync_service.dart';
import 'package:rescuelink/services/sos_sync_service.dart';
import 'package:rescuelink/services/sos_store.dart';
import 'chat_sync_test.dart' show MemoryChatCloud, message;
import 'sos_sync_test.dart' show MemoryCloud, alert;

void main() {
  sqfliteFfiInit();
  test(
    'committed local changes request sync; cloud acknowledgements do not loop',
    () async {
      final db = LocalDatabaseService(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final chat = ChatSyncService(ChatStore(db), MemoryChatCloud());
      final sos = SosSyncService(SosStore(db), MemoryCloud());
      addTearDown(() async {
        chat.dispose();
        sos.dispose();
        await db.close();
      });
      var requests = 0;
      db.syncRequested.addListener(() => requests++);
      await db.insertMessage(message());
      expect(requests, 1);
      expect(await chat.store.queue(), hasLength(1));
      await db.insertMessage(message());
      expect(requests, 1);
      await chat.store.edit('message', text: 'edited');
      expect(requests, 2);
      await chat.sync();
      expect(requests, 2);
      expect(await chat.store.queue(), isEmpty);
      await db.saveSos(jsonEncode({'alert': alert(1).toJson()}), []);
      expect(requests, 3);
      expect(await sos.store.queue(), hasLength(1));
      await sos.sync();
      expect(requests, 3);
      expect(await sos.store.queue(), isEmpty);
    },
  );
}
