// 🎯 PRIMARY WELLNESS PALETTE: Emerald Green / Sapphire Blue

//bento grid theme
import 'package:flutter/material.dart';

const Color _wellnessPrimary = Color(0xFF00BFA5); // Emerald Green (Vibrancy)
const Color _wellnessSecondary = Color(0xFF3F51B5); // Sapphire Blue (Depth/Trust)
const Color _wellnessSurface = Color(0xFFF7F9FC); // Off-White, Clean Surface

class AppTheme {
  static const String fontFamily = 'Roboto';

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    brightness: Brightness.light,

    // 1. ColorScheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: _wellnessPrimary,
      primary: _wellnessPrimary,
      secondary: _wellnessSecondary,
      surface: _wellnessSurface,
      error: Colors.red.shade700,
    ),

    // 2. Component Customization
    cardTheme:  CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16.0)), // Soft rounded corners
      ),
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
    ),

    // App Bar
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: _wellnessSurface,
      foregroundColor: _wellnessSecondary,
    ),

    // Bottom Navigation Bar: Primary focus color
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: _wellnessPrimary,
      unselectedItemColor: Colors.grey.shade600,
      backgroundColor: Colors.white,
      elevation: 8,
    ),

    // Button Style
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _wellnessPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    // Input Fields
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
        borderSide: BorderSide(color: Color(0xFFD1D9E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
        borderSide: BorderSide(color: _wellnessPrimary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      fillColor: Colors.white,
      filled: true,
    ),
  );

// You would typically define a darkTheme here as well.
}