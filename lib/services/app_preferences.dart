import 'package:flutter/material.dart';
import 'local_database_service.dart';
import '../l10n/app_strings.dart';

class AppPreferences extends ChangeNotifier {
  static final instance = AppPreferences();
  bool dark = false, english = false, alerts = true;
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
    alerts = true;
    notifyListeners();
  }

  String t(String th, String en) => english ? en : th;
  String text(String key) => t(key, appEnglish[key] ?? key);
  Future<void> load() async {
    final db = LocalDatabaseService.instance;
    final nextDark = await db.getSetting('darkMode') == 'true';
    final nextEnglish = await db.getSetting('language') == 'en';
    final nextAlerts = await db.getSetting('sosAlerts') != 'false';
    final nextSystem = await db.getSetting('systemTheme') == 'true';
    final nextName =
        await db.getSetting('profileNameDraft') ??
        await db.getSetting('profileDisplayName');
    if (!identical(db, LocalDatabaseService.instance)) return;
    dark = nextDark;
    english = nextEnglish;
    alerts = nextAlerts;
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
      case 'sosAlerts':
        alerts = value;
    }
    notifyListeners();
  }
}
