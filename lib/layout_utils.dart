import 'package:flutter/material.dart';

extension ResponsiveLayout on BuildContext {
  // 🚀 PERFORMANCE FIX: Use View.of instead of MediaQuery to avoid unnecessary rebuilds
  // for simple width checks if you're just looking for layout constraints.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isNarrow => screenWidth < 380;

  double scale(double size) {
    // 🎯 CLARITY: Use 390 (Modern Standard) or 375 (Legacy Standard)
    const double baseWidth = 375.0;

    // 🚀 PERFORMANCE: MediaQuery.sizeOf is faster than MediaQuery.of(this).size
    // because it only listens to size changes, not the whole MediaData.
    double width = MediaQuery.sizeOf(this).width;

    double factor = width / baseWidth;

    // 🎯 THE "PREMIUM" WEIGHTING:
    // On a Redmi 8 (usually 1080p width but scaled), we want to prevent
    // text from becoming "tiny" on small screens.
    // Logic: (factor + 2) / 3 creates a much shallower curve.
    double weightedFactor = (factor + 2.0) / 3.0;

    // 🔒 THE GUARDRAILS:
    // 0.9 ensures it never gets too small to read.
    // 1.15 ensures it doesn't look "blown up" on huge phones.
    return size * weightedFactor.clamp(0.9, 1.15);
  }
}