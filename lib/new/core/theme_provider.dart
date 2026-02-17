import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

// 🎯 The 5 Premium Dark Themes
enum AppThemeType { sapphire, obsidian, amethyst, imperial, crimson }

class ThemeNotifier extends StateNotifier<ThemeData> {
  AppThemeType _currentTheme = AppThemeType.sapphire; // Default Theme

  ThemeNotifier() : super(AppTheme.sapphireMidnight);

  void setTheme(AppThemeType type) {
    _currentTheme = type;
    switch (type) {
      case AppThemeType.sapphire:
        state = AppTheme.sapphireMidnight;
        break;
      case AppThemeType.obsidian:
        state = AppTheme.obsidianEmerald;
        break;
      case AppThemeType.amethyst:
        state = AppTheme.amethystAura;
        break;
      case AppThemeType.imperial:
        state = AppTheme.imperialGold;
        break;
      case AppThemeType.crimson:
        state = AppTheme.crimsonEclipse;
        break;
    }
  }

  void toggleTheme() {
    int nextIndex = (_currentTheme.index + 1) % AppThemeType.values.length;
    setTheme(AppThemeType.values[nextIndex]);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeData>((ref) {
  return ThemeNotifier();
});