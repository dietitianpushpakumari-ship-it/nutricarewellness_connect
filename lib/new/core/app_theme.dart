import 'package:flutter/material.dart';

class AppTheme {
  static const String primaryFontFamily = 'Inter';
  static const String headingFontFamily = 'Playfair Display';

  // ===========================================================================
  // 1. SAPPHIRE MIDNIGHT (Tech Luxury - Deep Blue & Cyan)
  // ===========================================================================
  static ThemeData get sapphireMidnight {
    const Color primary = Color(0xFF00E5FF); // Electric Cyan
    const Color secondary = Color(0xFF3D5AFE); // Deep Royal Blue
    const Color background = Color(0xFF0B0F19); // Abyss Blue

    return _buildDarkGlassTheme(primary, secondary, background);
  }

  // ===========================================================================
  // 2. OBSIDIAN EMERALD (Executive Wellness - True Black & Neon Green)
  // ===========================================================================
  static ThemeData get obsidianEmerald {
    const Color primary = Color(0xFF00E676); // Neon Emerald
    const Color secondary = Color(0xFF00BFA5); // Teal
    const Color background = Color(0xFF050505); // True Black

    return _buildDarkGlassTheme(primary, secondary, background);
  }

  // ===========================================================================
  // 3. AMETHYST AURA (Calming Mystical - Deep Plum & Soft Pink)
  // ===========================================================================
  static ThemeData get amethystAura {
    const Color primary = Color(0xFFFF4081); // Pink/Magenta
    const Color secondary = Color(0xFF7C4DFF); // Deep Purple
    const Color background = Color(0xFF120B1A); // Dark Plum

    return _buildDarkGlassTheme(primary, secondary, background);
  }

  // ===========================================================================
  // 4. IMPERIAL GOLD (Quiet Luxury - Onyx & Liquid Gold)
  // ===========================================================================
  static ThemeData get imperialGold {
    const Color primary = Color(0xFFFFD54F); // Soft Gold
    const Color secondary = Color(0xFFFF8F00); // Amber
    const Color background = Color(0xFF141414); // Rich Charcoal

    return _buildDarkGlassTheme(primary, secondary, background);
  }

  // ===========================================================================
  // 5. CRIMSON ECLIPSE (Energetic / Fitness - Dark Maroon & Ruby)
  // ===========================================================================
  static ThemeData get crimsonEclipse {
    const Color primary = Color(0xFFFF5252); // Bright Coral/Ruby
    const Color secondary = Color(0xFFD50000); // Deep Crimson
    const Color background = Color(0xFF1A0909); // Darkest Maroon

    return _buildDarkGlassTheme(primary, secondary, background);
  }

  // ===========================================================================
  // CORE DARK GLASS BUILDER (The Secret Sauce)
  // ===========================================================================
  static ThemeData _buildDarkGlassTheme(Color primary, Color secondary, Color background) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: primaryFontFamily,
      brightness: Brightness.dark, // 🎯 Forces Dark Mode constraints globally
      scaffoldBackgroundColor: background,

      // 🎯 FIX 1: GLOBALLY FIXES DROPDOWN BUTTONS
      // Standard DropdownButtons use canvasColor for their menu background.
      canvasColor: background,

      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: Colors.white.withOpacity(0.04), // 🎯 Ultra-sheer glass
        onPrimary: Colors.black, // Text on primary buttons
        onSurface: Colors.white, // Text on glass cards
      ),
      cardTheme: _buildGlassCardTheme(),
      appBarTheme: _buildPremiumAppBarTheme(),
      bottomNavigationBarTheme: _buildPremiumBottomNavTheme(primary),
      iconTheme: const IconThemeData(color: Colors.white),
      timePickerTheme: _buildPremiumTimePickerTheme(primary, background),

      // 🎯 FIX 2: GLOBALLY FIXES 3-DOT POPUP MENUS
      popupMenuTheme: _buildPremiumPopupMenuTheme(background),
    );
  }

  // ===========================================================================
  // GLASS COMPONENT STYLING
  // ===========================================================================
  static CardThemeData _buildGlassCardTheme() {
    return CardThemeData(
      color: Colors.white.withOpacity(0.05), // Frosted dark glass fill
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(
          color: Colors.white.withOpacity(0.12), // 🎯 Delicate light-catching rim
          width: 1.0,
        ),
      ),
    );
  }

  static AppBarTheme _buildPremiumAppBarTheme() {
    return const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent, // Let the orbs shine through
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  static BottomNavigationBarThemeData _buildPremiumBottomNavTheme(Color selectedColor) {
    return BottomNavigationBarThemeData(
      elevation: 0,
      backgroundColor: Colors.transparent,
      selectedItemColor: selectedColor,
      unselectedItemColor: Colors.white38,
      type: BottomNavigationBarType.fixed,
    );
  }

  // ===========================================================================
  // PREMIUM TIME PICKER STYLING
  // ===========================================================================
  static TimePickerThemeData _buildPremiumTimePickerTheme(Color primary, Color background) {
    return TimePickerThemeData(
      backgroundColor: background,
      hourMinuteColor: Colors.white.withOpacity(0.08),
      hourMinuteTextColor: Colors.white,
      hourMinuteTextStyle: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
      dialBackgroundColor: Colors.white.withOpacity(0.05),
      dialHandColor: primary,
      dialTextColor: Colors.white,
      entryModeIconColor: primary,
      helpTextStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
      cancelButtonStyle: TextButton.styleFrom(foregroundColor: Colors.white54),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.0),
      ),
    );
  }

  // ===========================================================================
  // PREMIUM POPUP & DROPDOWN MENU STYLING
  // ===========================================================================
  static PopupMenuThemeData _buildPremiumPopupMenuTheme(Color background) {

    return PopupMenuThemeData(
      color: background, // Solid background prevents transparency clash
      surfaceTintColor: Colors.transparent, // Stops Material 3 from tinting it purple
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: Colors.white.withOpacity(0.12), // Delicate glass rim to match cards
          width: 1.0,
        ),
      ),
    );
  }
}