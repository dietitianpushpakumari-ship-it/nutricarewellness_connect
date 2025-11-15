import 'package:flutter/material.dart';

class FemaleBodyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double w = size.width;
    double h = size.height;
    final path = Path();

    // Start at top of head
    path.moveTo(w * 0.5, h * 0.02);
    // Left hair/head
    path.cubicTo(w * 0.3, h * 0.03, w * 0.15, h * 0.15, w * 0.18, h * 0.25);
    path.cubicTo(w * 0.19, h * 0.3, w * 0.22, h * 0.35, w * 0.25, h * 0.38); // Left shoulder
    path.lineTo(w * 0.18, h * 0.55); // Left arm
    path.cubicTo(w * 0.17, h * 0.6, w * 0.2, h * 0.62, w * 0.25, h * 0.62); // Left hand
    path.lineTo(w * 0.3, h * 0.6); // Left waist
    path.lineTo(w * 0.32, h * 0.7); // Left hip
    path.lineTo(w * 0.35, h * 0.95); // Left leg
    // Left foot
    path.cubicTo(w * 0.35, h * 0.98, w * 0.25, h, w * 0.2, h * 0.98);
    path.cubicTo(w * 0.18, h * 0.96, w * 0.3, h * 0.96, w * 0.35, h * 0.98);
    path.lineTo(w * 0.4, h * 0.98);
    path.lineTo(w * 0.42, h * 0.8); // Crotch area
    path.lineTo(w * 0.58, h * 0.8);
    path.lineTo(w * 0.6, h * 0.98);
    // Right foot
    path.cubicTo(w * 0.7, h * 0.96, w * 0.82, h * 0.96, w * 0.8, h * 0.98);
    path.cubicTo(w * 0.75, h, w * 0.65, h * 0.98, w * 0.65, h * 0.98);
    path.lineTo(w * 0.65, h * 0.7); // Right leg
    path.lineTo(w * 0.7, h * 0.6); // Right waist
    path.lineTo(w * 0.75, h * 0.62); // Right hand
    path.cubicTo(w * 0.8, h * 0.62, w * 0.83, h * 0.6, w * 0.82, h * 0.55); // Right arm
    path.lineTo(w * 0.75, h * 0.38); // Right shoulder
    path.cubicTo(w * 0.78, h * 0.35, w * 0.81, h * 0.3, w * 0.82, h * 0.25); // Right hair
    path.cubicTo(w * 0.85, h * 0.15, w * 0.7, h * 0.03, w * 0.5, h * 0.02); // Right side of head

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}



