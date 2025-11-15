

import 'dart:math';

import 'package:flutter/material.dart';

class WaveClipper extends CustomClipper<Path> {
  /// 0.0 to 1.0, drives the "sloshing" animation
  final double waveProgress;
  /// 0.0 (empty) to 1.0 (full)
  final double fillProgress;

  WaveClipper({required this.waveProgress, required this.fillProgress});

  @override
  Path getClip(Size size) {
    final path = Path();

    // 1. Calculate the base Y level based on fillProgress
    // (1.0 = full, 0.0 = empty) -> (Y=0, Y=size.height)
    final double baseHeight = size.height * (1.0 - fillProgress);

    const double waveHeight = 8.0; // How high the wave crests
    const double waveFrequency = 1.5; // How many waves across the width

    // This moves the wave horizontally
    final double waveOffset = waveProgress * 2 * pi;

    // Start path at bottom-left
    path.lineTo(0, size.height);

    // Move to the start of the wave (top-left of water)
    path.moveTo(0, baseHeight);

    for (double x = 0; x <= size.width; x++) {
      // Calculate the Y position of the wave at this X point
      final double y = sin((x / size.width * 2 * pi * waveFrequency) + waveOffset) * (waveHeight / 2) + baseHeight;
      path.lineTo(x, y);
    }

    // Close the path
    path.lineTo(size.width, size.height); // Bottom-right
    path.lineTo(0, size.height); // Bottom-left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper oldClipper) {
    // Reclip every time the animation value or fill level changes
    return oldClipper.waveProgress != waveProgress || oldClipper.fillProgress != fillProgress;
  }
}