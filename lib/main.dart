import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'theme/rescue_theme.dart';
import 'services/app_preferences.dart';
import 'services/platform_database.dart';
import 'services/auth_service.dart';
import 'services/sos_sync_service.dart';
import 'services/chat_sync_service.dart';
import 'screens/nearby_test_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configurePlatformDatabase();
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

  @override
  void initState() {
    super.initState();
    _ready = AuthService.instance.initialize().then((_) async {
      await AppPreferences.instance.load().catchError((Object _) {});
      SosSyncCoordinator.instance.start();
      ChatSyncCoordinator.instance.start();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        // Session restored → go to main screen. Otherwise → onboarding/login.
        return AuthService.instance.signedIn
            ? const NearbyTestScreen()
            : const OnboardingScreen();
      }
      // Loading / error state — no Guest option.
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!snapshot.hasError)
                  const CircularProgressIndicator()
                else
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                const SizedBox(height: 20),
                Text(
                  snapshot.hasError
                      ? 'กู้ session ไม่สำเร็จ'
                      : 'กำลังกู้ session…',
                  style: const TextStyle(fontSize: 15),
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'กรุณาตรวจสอบอินเทอร์เน็ตหรือเปิดแอปใหม่อีกครั้ง\n'
                      'หากเคยเข้าสู่ระบบแล้ว ฟีเจอร์ Nearby และ SOS '
                      'สามารถใช้งานได้โดยไม่ต้องออนไลน์',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _ready = AuthService.instance
                            .initialize()
                            .then((_) async {
                          await AppPreferences.instance
                              .load()
                              .catchError((Object _) {});
                          SosSyncCoordinator.instance.start();
                          ChatSyncCoordinator.instance.start();
                        });
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('ลองใหม่'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('ไปหน้าเข้าสู่ระบบ'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
