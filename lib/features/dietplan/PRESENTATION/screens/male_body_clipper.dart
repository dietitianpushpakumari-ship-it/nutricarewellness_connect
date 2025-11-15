import 'package:flutter/material.dart';

class MaleBodyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double w = size.width;
    double h = size.height;
    final path = Path();

    // Start at top of head
    path.moveTo(w * 0.5, h * 0.05);
    // Left side of head
    path.cubicTo(w * 0.35, h * 0.05, w * 0.28, h * 0.12, w * 0.28, h * 0.2);
    // Left neck
    path.lineTo(w * 0.3, h * 0.28);
    // Left shoulder
    path.cubicTo(w * 0.25, h * 0.3, w * 0.05, h * 0.33, w * 0.05, h * 0.43);
    // Left sleeve
    path.lineTo(w * 0.05, h * 0.48);
    path.cubicTo(w * 0.05, h * 0.5, w * 0.1, h * 0.52, w * 0.15, h * 0.5);
    // Left armpit/torso
    path.lineTo(w * 0.28, h * 0.48); // Armpit
    path.lineTo(w * 0.28, h * 0.65); // Torso side
    path.lineTo(w * 0.3, h * 0.9); // Left leg
    // Left foot
    path.cubicTo(w * 0.3, h * 0.98, w * 0.2, h, w * 0.15, h * 0.98);
    path.cubicTo(w * 0.1, h * 0.96, w * 0.25, h * 0.96, w * 0.3, h * 0.98);
    path.lineTo(w * 0.38, h * 0.98); // Between feet
    path.lineTo(w * 0.38, h * 0.65); // Crotch
    path.lineTo(w * 0.62, h * 0.65); // Crotch
    path.lineTo(w * 0.62, h * 0.98); // Right leg
    // Right foot
    path.cubicTo(w * 0.75, h * 0.96, w * 0.9, h * 0.96, w * 0.85, h * 0.98);
    path.cubicTo(w * 0.8, h, w * 0.7, h * 0.98, w * 0.7, h * 0.9);
    path.lineTo(w * 0.72, h * 0.65); // Torso side
    path.lineTo(w * 0.72, h * 0.48); // Armpit
    // Right sleeve
    path.lineTo(w * 0.85, h * 0.5);
    path.cubicTo(w * 0.9, h * 0.52, w * 0.95, h * 0.5, w * 0.95, h * 0.48);
    path.lineTo(w * 0.95, h * 0.43); // Right arm
    path.cubicTo(w * 0.95, h * 0.33, w * 0.75, h * 0.3, w * 0.7, h * 0.28);
    // Right neck
    path.lineTo(w * 0.72, h * 0.2);
    // Right side of head
    path.cubicTo(w * 0.72, h * 0.12, w * 0.65, h * 0.05, w * 0.5, h * 0.05);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}