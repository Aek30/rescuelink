import 'package:flutter/material.dart';
import 'local_database_service.dart';

class AppPreferences extends ChangeNotifier {
  static final instance = AppPreferences();
  bool dark = false, english = false, alerts = true;
  String t(String th, String en) => english ? en : th;
  Future<void> load() async {
    final db = LocalDatabaseService.instance;
    dark = await db.getSetting('darkMode') == 'true';
    english = await db.getSetting('language') == 'en';
    alerts = await db.getSetting('sosAlerts') != 'false';
    notifyListeners();
  }

  Future<void> set(String key, bool value) async {
    await LocalDatabaseService.instance.setSetting(
      key,
      key == 'language' ? (value ? 'en' : 'th') : '$value',
    );
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
