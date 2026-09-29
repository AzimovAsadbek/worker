import 'package:flutter/material.dart';

/// High-contrast, large-target theme for outdoor use on construction sites.
class AppColors {
  static const primary = Color(0xFF0B5FFF);
  static const start = Color(0xFF12803B); // ISHNI BOSHLASH
  static const end = Color(0xFFC62828); // ISHNI YAKUNLASH
  static const warning = Color(0xFFB26A00);
  static const success = Color(0xFF12803B);
  static const danger = Color(0xFFC62828);
  static const muted = Color(0xFF5F6B7A);
  static const surface = Color(0xFFF5F7FA);
  static const verified = Color(0xFF0E7C66);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light).copyWith(
    primary: AppColors.primary,
    error: AppColors.danger,
    surface: Colors.white,
  );
  const radius = BorderRadius.all(Radius.circular(12));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 17),
      bodyMedium: TextStyle(fontSize: 15),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0, scrolledUnderElevation: 1, centerTitle: false),
    cardTheme: const CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: Color(0xFFE3E8EF)))),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: radius),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const RoundedRectangleBorder(borderRadius: radius), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const RoundedRectangleBorder(borderRadius: radius)),
    ),
    navigationBarTheme: const NavigationBarThemeData(height: 68, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
