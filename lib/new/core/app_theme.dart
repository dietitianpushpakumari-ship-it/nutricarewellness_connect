import 'package:flutter/material.dart';

class AppTheme {
  static const String kDisplayFont = 'Space Grotesk';
  static const String kBodyFont = 'Inter';

  // ===========================================================================
  // ☀️ PREMIUM LIGHT MODES (Fintech & Apple Style)
  // ===========================================================================

  static ThemeData get appleHealthLight => _buildPremiumLight(
    primary: const Color(0xFFFF2D55),
    background: const Color(0xFFF9F9FB), // Faint wash
    card: Colors.white,                  // Pure white cards
    isDark: false,
  );

  static ThemeData get socialBlue => _buildPremiumLight(
    primary: const Color(0xFF1877F2),
    background: const Color(0xFFF0F2F5),
    card: Colors.white,
    isDark: false,
  );

  static ThemeData get fintechBlurple => _buildPremiumLight(
    primary: const Color(0xFF635BFF),
    background: const Color(0xFFF6F9FC),
    card: Colors.white,
    isDark: false,
  );

  static ThemeData get clinicalMint => _buildPremiumLight(
    primary: const Color(0xFF00A389),
    background: const Color(0xFFF4F9F8),
    card: Colors.white,
    isDark: false,
  );

  static ThemeData get editorialMonoLight => _buildPremiumLight(
    primary: const Color(0xFF000000),
    background: const Color(0xFFF9FAFB),
    card: Colors.white,
    isDark: false,
  );

  // ===========================================================================
  // 🌙 OLED DARK MODES (Pitch Black & Glass Style)
  // ===========================================================================

  static ThemeData get appleOled => _buildTheme(
    primary: const Color(0xFF0A84FF),
    background: const Color(0xFF000000),
    card: const Color(0xFF1C1C1E),
    isDark: true,
  );

  static ThemeData get spotifyGreen => _buildTheme(
    primary: const Color(0xFF1DB954),
    background: const Color(0xFF121212),
    card: const Color(0xFF181818),
    isDark: true,
  );

  static ThemeData get amethystDark => _buildTheme(
    primary: const Color(0xFFBF5AF2),
    background: const Color(0xFF0D0B14),
    card: const Color(0xFF1A1625),
    isDark: true,
  );

  static ThemeData get imperialDark => _buildTheme(
    primary: const Color(0xFFFFD60A),
    background: const Color(0xFF000000),
    card: const Color(0xFF1C1C1E),
    isDark: true,
  );

  static ThemeData get editorialMonoDark => _buildTheme(
    primary: const Color(0xFFFFFFFF),
    background: const Color(0xFF000000),
    card: const Color(0xFF121212),
    isDark: true,
  );

  // ===========================================================================
  // 🛠️ THE THEME BUILDER ENGINES
  // ===========================================================================

  static ThemeData _buildTheme({
    required Color primary,
    required Color background,
    required Color card,
    required bool isDark,
  }) {
    final Color textColor = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1E21);
    final Color subTextColor = isDark ? Colors.white60 : Colors.black45;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      cardColor: card,
      fontFamily: kBodyFont,
      dividerColor: textColor.withOpacity(0.08),
      colorScheme: isDark
          ? ColorScheme.dark(primary: primary, surface: card, onSurface: textColor)
          : ColorScheme.light(primary: primary, surface: card, onSurface: textColor),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kDisplayFont,
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: textColor.withOpacity(0.05), width: 1),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: kDisplayFont, color: textColor, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(fontFamily: kBodyFont, color: textColor),
        bodyMedium: TextStyle(fontFamily: kBodyFont, color: subTextColor),
      ),
    );
  }

  static ThemeData _buildPremiumLight({
    required Color primary,
    required Color background,
    required Color card,
    required bool isDark,
  }) {
    const Color charcoal = Color(0xFF1E293B);
    const Color slateHeader = Color(0xFF0F172A);
    const Color alertRed = Color(0xFFE11D48);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      cardColor: card,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: primary.withOpacity(0.7),
        surface: card,
        onSurface: charcoal,
        error: alertRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: kDisplayFont,
          color: slateHeader,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.7,
        ),
        iconTheme: const IconThemeData(color: slateHeader),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: slateHeader.withOpacity(0.04), width: 1.0),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontFamily: kDisplayFont, color: slateHeader, fontWeight: FontWeight.w800),
        bodyLarge: const TextStyle(fontFamily: kBodyFont, color: charcoal, fontSize: 16, letterSpacing: -0.2),
        bodyMedium: TextStyle(fontFamily: kBodyFont, color: charcoal.withOpacity(0.6), fontSize: 14),
        labelSmall: const TextStyle(
          fontFamily: kDisplayFont,
          color: alertRed,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}