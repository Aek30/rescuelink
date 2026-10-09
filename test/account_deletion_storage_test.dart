import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rescuelink/services/account_storage.dart';

void main() {
  sqfliteFfiInit();
  test(
    'deletion isolates other owners and retained handles cannot recreate deleted database',
    () async {
      final directory = await Directory.systemTemp.createTemp('member-delete-');
      final storage = AccountStorage(
        factory: databaseFactoryFfi,
        directory: directory.path,
      );
      try {
        final a = await storage.select('A');
        await a.setSetting('private', 'A-data');
        await expectLater(storage.removeOwner('A'), throwsStateError);
        final b = await storage.select('B');
        await b.setSetting('private', 'B-data');
        await storage.select(null);
        await storage.removeOwner('A');
        await expectLater(a.database, throwsStateError);
        expect(await b.getSetting('private'), 'B-data');
        expect(
          await (await storage.catalog).query(
            'owners',
            where: 'owner = ?',
            whereArgs: ['user:A'],
          ),
          isEmpty,
        );
        final newA = await storage.select('A');
        expect(await newA.getSetting('private'), isNull);
      } finally {
        await storage.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
