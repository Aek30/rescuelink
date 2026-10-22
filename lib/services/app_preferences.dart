import 'package:flutter/material.dart';
import 'local_database_service.dart';
import '../l10n/app_strings.dart';

class AppPreferences extends ChangeNotifier {
  static final instance = AppPreferences();
  bool dark = false, english = false, chatAlerts = true, sosAlerts = true;
  bool systemTheme = false;
  String? displayName;
  ThemeMode get themeMode => systemTheme
      ? ThemeMode.system
      : dark
      ? ThemeMode.dark
      : ThemeMode.light;
  void reset() {
    dark = false;
    displayName = null;
    systemTheme = false;
    english = false;
    chatAlerts = true;
    sosAlerts = true;
    notifyListeners();
  }

  String t(String th, String en) => english ? en : th;
  String text(String key) => t(key, appEnglish[key] ?? key);
  // The old shared alerts flag was stored under sosAlerts.
  Future<void> _migrateAlerts(LocalDatabaseService db) async {
    await (await db.database).transaction((txn) async {
      final rows = await txn.query(
        'settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: [
          'notificationPreferencesVersion',
          'chatAlerts',
          'sosAlerts',
        ],
      );
      final values = {for (final row in rows) row['key']: row['value']};
      if (values['notificationPreferencesVersion'] == '1') return;
      await txn.rawInsert(
        'INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)',
        ['chatAlerts', values['sosAlerts'] ?? 'true'],
      );
      await txn.rawInsert(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        ['sosAlerts', 'true'],
      );
      await txn.rawInsert(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        ['notificationPreferencesVersion', '1'],
      );
    });
  }

  Future<void> load() async {
    final db = LocalDatabaseService.instance;
    final nextDark = await db.getSetting('darkMode') == 'true';
    final nextEnglish = await db.getSetting('language') == 'en';
    await _migrateAlerts(db);
    final nextChatAlerts = await db.getSetting('chatAlerts') != 'false';
    final nextSosAlerts = await db.getSetting('sosAlerts') != 'false';
    final nextSystem = await db.getSetting('systemTheme') == 'true';
    final nextName =
        await db.getSetting('profileNameDraft') ??
        await db.getSetting('profileDisplayName');
    if (!identical(db, LocalDatabaseService.instance)) return;
    dark = nextDark;
    english = nextEnglish;
    chatAlerts = nextChatAlerts;
    sosAlerts = nextSosAlerts;
    systemTheme = nextSystem;
    displayName = nextName;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    final db = LocalDatabaseService.instance;
    await db.setSetting('systemTheme', '${mode == ThemeMode.system}');
    await db.setSetting('darkMode', '${mode == ThemeMode.dark}');
    if (!identical(db, LocalDatabaseService.instance)) return;
    systemTheme = mode == ThemeMode.system;
    dark = mode == ThemeMode.dark;
    notifyListeners();
  }

  Future<void> saveLocalName(String value) async {
    value = value.trim();
    if (value.isEmpty || value.length > 80) {
      throw ArgumentError('กรุณาระบุชื่อ 1–80 ตัวอักษร');
    }
    final db = LocalDatabaseService.instance;
    await db.setSetting('profileNameDraft', value);
    if (!identical(db, LocalDatabaseService.instance)) return;
    displayName = value;
    notifyListeners();
  }

  Future<void> set(String key, bool value) async {
    final db = LocalDatabaseService.instance;
    if (key == 'chatAlerts' || key == 'sosAlerts') await _migrateAlerts(db);
    await db.setSetting(
      key,
      key == 'language' ? (value ? 'en' : 'th') : '$value',
    );
    if (!identical(db, LocalDatabaseService.instance)) return;
    switch (key) {
      case 'darkMode':
        dark = value;
      case 'language':
        english = value;
      case 'chatAlerts':
        chatAlerts = value;
      case 'sosAlerts':
        sosAlerts = value;
    }
    notifyListeners();
  }
}
