import 'dart:math';

import 'package:flutter/material.dart';

class WaveClipper extends CustomClipper<Path> {
  final double waveProgress;
  final double fillProgress;

  WaveClipper({required this.waveProgress, required this.fillProgress});

  @override
  Path getClip(Size size) {
    final path = Path();
    final double baseHeight = size.height * (1.0 - fillProgress);
    const double waveHeight = 8.0;
    const double waveFrequency = 1.5;
    final double waveOffset = waveProgress * 2 * pi;

    path.lineTo(0, size.height);
    path.moveTo(0, baseHeight);

    for (double x = 0; x <= size.width; x++) {
      final double y = sin((x / size.width * 2 * pi * waveFrequency) + waveOffset) * (waveHeight / 2) + baseHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper oldClipper) {
    return oldClipper.waveProgress != waveProgress || oldClipper.fillProgress != fillProgress;
  }
}