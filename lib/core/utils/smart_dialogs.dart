import 'dart:math';
import 'dart:ui'; // 🎯 Required for the blur effect
import 'package:flutter/material.dart';

// Simple database of tips (In production, fetch this from your Library Provider)
const Map<String, List<String>> _contextualTips = {
  'nutrition': [
    "Tip: Walking for 10 mins after a meal curbs blood sugar spikes.",
    "Tip: Eating protein first helps you feel full faster.",
    "Tip: Chew your food 20 times to improve digestion."
  ],
  'hydration': [
    "Fact: Thirst is often mistaken for hunger. Drink water first!",
    "Tip: Cold water may boost metabolism slightly.",
    "Fact: Even mild dehydration causes fatigue."
  ],
  'sleep': [
    "Tip: Avoid blue light (screens) 1 hour before bed.",
    "Fact: Deep sleep repairs muscles and tissues.",
    "Tip: Keep your room cool (around 18°C) for better sleep."
  ]
};

void showContextualSuccessDialog(BuildContext context, String category) {
  final tips = _contextualTips[category] ?? _contextualTips['nutrition']!;
  final randomTip = tips[Random().nextInt(tips.length)];

  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.4), // Darkens the background slightly
    builder: (ctx) => BackdropFilter(
      // 🎯 FIX 1: Blurs the app background behind the dialog for a premium look!
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: AlertDialog(
        // 🎯 FIX 2: Uses scaffoldBackgroundColor which is ALWAYS a solid, opaque color
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 24, // Adds a nice drop shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text(
              "Saved!",
              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 22),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: theme.dividerColor, height: 24),
            Text(
              "While you're here...",
              style: TextStyle(fontSize: 13, color: theme.hintColor, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Text(
              randomTip,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text("Got it", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          )
        ],
      ),
    ),
  );
}