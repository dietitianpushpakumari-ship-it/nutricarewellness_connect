import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

enum AppThemeType {
  appleHealth, facebook, stripe, mint, monoLight, // ☀️ Light
  appleOled, spotify, amethyst, gold, monoDark     // 🌙 Dark
}

class ThemeNotifier extends StateNotifier<ThemeData> {
  AppThemeType currentType = AppThemeType.appleHealth; // Default
  static const String _prefKey = 'selected_theme';

  ThemeNotifier() : super(AppTheme.appleHealthLight) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefKey);
    if (name != null) {
      final saved = AppThemeType.values.firstWhere((e) => e.name == name, orElse: () => AppThemeType.appleHealth);
      setTheme(saved, save: false);
    }
  }

  void setTheme(AppThemeType type, {bool save = true}) async {
    currentType = type;
    switch (type) {
      case AppThemeType.appleHealth: state = AppTheme.appleHealthLight; break;
      case AppThemeType.facebook: state = AppTheme.socialBlue; break;
      case AppThemeType.stripe: state = AppTheme.fintechBlurple; break;
      case AppThemeType.mint: state = AppTheme.clinicalMint; break;
      case AppThemeType.monoLight: state = AppTheme.editorialMonoLight; break;
      case AppThemeType.appleOled: state = AppTheme.appleOled; break;
      case AppThemeType.spotify: state = AppTheme.spotifyGreen; break;
      case AppThemeType.amethyst: state = AppTheme.amethystDark; break;
      case AppThemeType.gold: state = AppTheme.imperialDark; break;
      case AppThemeType.monoDark: state = AppTheme.editorialMonoDark; break;
    }
    if (save) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, type.name);
    }
  }

  void toggleMode() {
    int idx = currentType.index;
    if (idx < 5) setTheme(AppThemeType.values[idx + 5]); // Switch to Dark
    else setTheme(AppThemeType.values[idx - 5]);        // Switch to Light
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeData>((ref) => ThemeNotifier());