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
        fontFamily: 'Roboto',
        scaffoldBackgroundColor:
            const Color(0xFFF5F7FB),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF174C8F),
          brightness: Brightness.light,
        ),

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),

        filledButtonTheme:
            FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
        ),

        outlinedButtonTheme:
            OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
        ),
      ),

      home: const NearbyTestScreen(),
    );
  }
}