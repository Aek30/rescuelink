import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'theme/rescue_theme.dart';
import 'services/app_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppPreferences.instance.load().catchError((Object _) {});
  runApp(const RescueLinkApp());
}

class RescueLinkApp extends StatelessWidget {
  const RescueLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppPreferences.instance,
      builder: (context, _) => MaterialApp(
        title: 'RescueLink',
        debugShowCheckedModeBanner: false,
        theme: RescueTheme.light,
        darkTheme: RescueTheme.dark,
        themeMode: AppPreferences.instance.dark
            ? ThemeMode.dark
            : ThemeMode.light,

        home: const OnboardingScreen(),
      ),
    );
  }
}
