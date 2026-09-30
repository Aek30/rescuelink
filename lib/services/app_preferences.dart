import 'package:flutter/material.dart';
import 'local_database_service.dart';

class AppPreferences extends ChangeNotifier {
  static final instance = AppPreferences();
  bool dark = false, english = false, alerts = true;
  void reset() {
    dark = false;
    english = false;
    alerts = true;
    notifyListeners();
  }

  String t(String th, String en) => english ? en : th;
  Future<void> load() async {
    final db = LocalDatabaseService.instance;
    final nextDark = await db.getSetting('darkMode') == 'true';
    final nextEnglish = await db.getSetting('language') == 'en';
    final nextAlerts = await db.getSetting('sosAlerts') != 'false';
    if (!identical(db, LocalDatabaseService.instance)) return;
    dark = nextDark;
    english = nextEnglish;
    alerts = nextAlerts;
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
