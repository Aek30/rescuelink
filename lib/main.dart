import 'package:flutter/material.dart';

// import หน้าเดิมของคุณ
import 'screens/nearby_test_screen.dart';

void main() {
  runApp(const RescueLinkApp());
}

class RescueLinkApp extends StatelessWidget {
  const RescueLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RescueLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSansThai',
        scaffoldBackgroundColor: const Color(0xFFFFF8F2),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF873B10),
          primary: const Color(0xFF873B10),
          primaryContainer: const Color(0xFFFFE8D6),
          surface: const Color(0xFFFFF8F2),
          brightness: Brightness.light,
        ),

        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF9F5A),
            foregroundColor: const Color(0xFF2B2B2B),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),

      home: const NearbyTestScreen(),
    );
  }
}
