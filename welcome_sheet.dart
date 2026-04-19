import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pure_shift/core/string_extension.dart';

void showLuxuryWelcomeSheet(
    BuildContext context, {
      required String clientName,
      required String companyName,
      required String coachName,
    }) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final bottomPadding = MediaQuery.of(context).padding.bottom;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6), // Darker, cinematic backdrop
    builder: (context) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Glassmorphism
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 32), // 🚀 Perfect SafeArea
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.15),
                  blurRadius: 60,
                  offset: const Offset(0, -10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimalist Drag Handle
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 40),

                // 🚀 1. OVERLINE: Welcome To
                Text(
                  "W E L C O M E   T O",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.0,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 12),

                // 🚀 2. COMPANY NAME (Dynamic & Luxurious)
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [cs.primary, cs.tertiary, cs.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    companyName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white, // Required for ShaderMask
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Visual Separator (Luxury Touch)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 40, height: 1, color: theme.dividerColor.withOpacity(0.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.spa_rounded, size: 16, color: cs.primary.withOpacity(0.5)),
                    ),
                    Container(width: 40, height: 1, color: theme.dividerColor.withOpacity(0.5)),
                  ],
                ),
                const SizedBox(height: 32),

                // 🚀 3. CLIENT NAME
                Text(
                  "Hello, ${clientName.toTitleCase()}.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                // 🚀 4. COACH MESSAGE (Visual Separation)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.primary.withOpacity(0.1)),
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: cs.onSurface.withOpacity(0.8),
                        height: 1.6,
                      ),
                      children: [
                        const TextSpan(text: "Your clinical profile and personalized wellness protocol have been successfully configured by "),
                        TextSpan(

                          text: "Coach ${coachName.toTitleCase()}", // Dynamic Coach Name
                          style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary),
                        ),
                        const TextSpan(text: "."),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // 🚀 5. MODERN CTA BUTTON
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "ENTER DASHBOARD",
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.arrow_right_alt_rounded, size: 20, color: cs.onPrimary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}