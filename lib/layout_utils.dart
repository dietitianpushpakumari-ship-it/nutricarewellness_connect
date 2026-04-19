import 'package:flutter/material.dart';

extension ResponsiveLayout on BuildContext {
  bool get isNarrow => MediaQuery.of(this).size.width < 380;

  double scale(double size) {
    double screenWidth = MediaQuery.of(this).size.width;

    // 🚀 THE FIX: Use a more conservative floor.
    // We don't want to shrink the font as much as we want to grow it.
    // Base: 375 (Standard iPhone) is often better for a "clean" look.
    double factor = (screenWidth / 375);

    // 🎯 THE "DENSITY" TRICK:
    // We use a weighted average so it doesn't shrink 1:1 on small phones,
    // but expands nicely on high-density ones.
    double weightedFactor = (factor + 1.0) / 2;

    return size * weightedFactor.clamp(0.95, 1.25);
  }
}