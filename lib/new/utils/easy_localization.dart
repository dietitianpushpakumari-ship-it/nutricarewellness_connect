import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';

class PremiumLanguageSheet extends StatelessWidget {
  const PremiumLanguageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentLang = EasyLocalization.of(context)?.locale.languageCode ?? 'en';
    // Get the currently active language from easy_localization

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 🎯 Deep Glass Blur
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withOpacity(0.85), // Frosted background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, -5))
            ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎯 Premium Dragger Pill
            Center(
                child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2))
                )
            ),
            const SizedBox(height: 24),

            Text("APP LOCALIZATION", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text("Select Language", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text("The interface will instantly translate to your preference.", style: TextStyle(fontSize: 13, color: theme.hintColor)),
            const SizedBox(height: 24),

            // 🎯 The Language Options
            _buildLangTile(context, "English", "English", "en", currentLang, cs, theme),
            const SizedBox(height: 12),
            _buildLangTile(context, "हिंदी", "Hindi", "hi", currentLang, cs, theme),
            const SizedBox(height: 12),
            _buildLangTile(context, "ଓଡ଼ିଆ", "Oriya", "or", currentLang, cs, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLangTile(BuildContext context, String nativeName, String englishName, String code, String currentLang, ColorScheme cs, ThemeData theme) {
    final bool isSelected = currentLang == code;

    return GestureDetector(
      onTap: () async {
        // 🎯 Instantly switches the app's entire language
        await context.setLocale(Locale(code));
        if (context.mounted) Navigator.pop(context); // Close the sheet smoothly
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withOpacity(0.15) : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? cs.primary.withOpacity(0.5) : theme.dividerColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // Custom Language Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isSelected ? cs.primary : theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? Colors.transparent : theme.dividerColor.withOpacity(0.2))
              ),
              child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? cs.onPrimary : theme.hintColor
                  )
              ),
            ),
            const SizedBox(width: 16),

            // Language Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nativeName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? cs.primary : cs.onSurface)),
                  Text(englishName, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                ],
              ),
            ),

            // Checkmark
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 24),
          ],
        ),
      ),
    );
  }
}