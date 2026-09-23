import 'package:flutter/material.dart';
import 'screens/nearby_test_screen.dart';

void main() => runApp(const RescueLinkApp());

class RescueLinkApp extends StatelessWidget {
  const RescueLinkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RescueLink',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF163A63)),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const NearbyTestScreen(),
  );
}
