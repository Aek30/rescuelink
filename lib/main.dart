import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'theme/rescue_theme.dart';
import 'services/app_preferences.dart';
import 'services/auth_service.dart';
import 'services/sos_sync_service.dart';
import 'screens/nearby_test_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

        home: const _StartupScreen(),
      ),
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();
  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  late Future<void> _ready;
  bool _guest = false;
  @override
  void initState() {
    super.initState();
    _ready = AuthService.instance.initialize().then((_) async {
      await AppPreferences.instance.load().catchError((Object _) {});
      SosSyncCoordinator.instance.start();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return _guest || AuthService.instance.signedIn
            ? const NearbyTestScreen()
            : const OnboardingScreen();
      }
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!snapshot.hasError) const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  snapshot.hasError
                      ? 'เปิด session ไม่สำเร็จ กรุณาลองใหม่'
                      : 'กำลังกู้ session',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => setState(() {
                    _guest = true;
                    _ready = AuthService.instance.enterGuestFromStartup();
                  }),
                  child: const Text('ใช้ SOS / สื่อสารแบบ Guest ทันที'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
