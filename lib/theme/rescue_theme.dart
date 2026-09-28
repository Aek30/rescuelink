import 'package:flutter/material.dart';

/// Shared visual language for onboarding, everyday messaging and rescue flows.
abstract final class RescueTheme {
  static const cream = Color(0xFFFCF8F1);
  static const navy = Color(0xFF102D43);
  static const orange = Color(0xFFFF6826);
  static const orangeInk = Color(0xFFB94612);
  static const peach = Color(0xFFFFEADB);
  static const muted = Color(0xFF687782);
  static const border = Color(0xFFEAE2D8);
  static const success = Color(0xFF23765B);
  static const danger = Color(0xFFC83F49);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: orange,
      primary: orange,
      onPrimary: navy,
      primaryContainer: peach,
      onPrimaryContainer: navy,
      secondary: navy,
      onSecondary: Colors.white,
      surface: cream,
      onSurface: navy,
      error: danger,
      brightness: Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansThai',
      colorScheme: scheme,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    );
    final input = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: border),
    );
    return base.copyWith(
      scaffoldBackgroundColor: cream,
      textTheme: base.textTheme.apply(bodyColor: navy, displayColor: navy),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          color: navy,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: shape.copyWith(side: const BorderSide(color: border)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: navy,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          backgroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: const BorderSide(color: border),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: orangeInk,
          textStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: navy),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: input,
        enabledBorder: input,
        focusedBorder: input.copyWith(
          borderSide: const BorderSide(color: orange, width: 1.5),
        ),
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
        indicatorColor: peach,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'NotoSansThai',
            color: states.contains(WidgetState.selected) ? navy : muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? orangeInk : muted,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: peach,
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          color: navy,
          fontSize: 12,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: orangeInk,
        textColor: navy,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cream,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cream,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: orange,
        linearTrackColor: peach,
      ),
    );
  }

  static const darkBackground = Color(0xFF0C1017);
  static const darkSurface = Color(0xFF161C24);
  static const darkSurfaceElevated = Color(0xFF1E2632);
  static const darkBorder = Color(0xFF283442);
  static const darkText = Color(0xFFF1F5F9);
  static const darkTextMuted = Color(0xFF94A3B8);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: orange,
      primary: orange,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF3D2314),
      onPrimaryContainer: const Color(0xFFFFCCAA),
      secondary: const Color(0xFF38BDF8),
      onSecondary: const Color(0xFF0C1017),
      surface: darkSurface,
      onSurface: darkText,
      error: const Color(0xFFF87171),
      brightness: Brightness.dark,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'NotoSansThai',
      colorScheme: scheme,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    );
    final input = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: darkBorder),
    );
    return base.copyWith(
      scaffoldBackgroundColor: darkBackground,
      textTheme: base.textTheme.apply(bodyColor: darkText, displayColor: darkText),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: shape.copyWith(side: const BorderSide(color: darkBorder)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          backgroundColor: darkSurface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: const BorderSide(color: darkBorder),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFF9565),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: darkText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: input,
        enabledBorder: input,
        focusedBorder: input.copyWith(
          borderSide: const BorderSide(color: orange, width: 1.5),
        ),
        labelStyle: const TextStyle(color: darkTextMuted),
        hintStyle: const TextStyle(color: darkTextMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF10141C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
        indicatorColor: const Color(0xFF382314),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'NotoSansThai',
            color: states.contains(WidgetState.selected) ? Colors.white : darkTextMuted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? const Color(0xFFFF9565) : darkTextMuted,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: darkSurface,
        selectedColor: const Color(0xFF382314),
        side: const BorderSide(color: darkBorder),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          color: darkText,
          fontSize: 12,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFFF9565),
        textColor: darkText,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceElevated,
        contentTextStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          color: darkText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: orange,
        linearTrackColor: Color(0xFF382314),
      ),
    );
  }
}
