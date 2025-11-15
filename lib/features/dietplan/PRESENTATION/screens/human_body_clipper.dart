import 'package:flutter/material.dart';

class HumanBodyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    double w = size.width;
    double h = size.height;

    // A simple, stylized "person" shape

    // Head
    path.addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.15), radius: h * 0.15));

    // Body
    path.moveTo(w * 0.3, h * 0.3); // Neck left
    path.lineTo(w * 0.2, h * 0.45); // Shoulder left
    path.lineTo(w * 0.1, h * 0.7); // Arm left
    path.lineTo(w * 0.3, h * 0.7); // Torso left
    path.lineTo(w * 0.3, h * 1.0); // Leg left
    path.lineTo(w * 0.45, h * 1.0); // Crotch left
    path.lineTo(w * 0.45, h * 0.7);

    path.lineTo(w * 0.55, h * 0.7);
    path.lineTo(w * 0.55, h * 1.0); // Crotch right
    path.lineTo(w * 0.7, h * 1.0); // Leg right
    path.lineTo(w * 0.7, h * 0.7); // Torso right
    path.lineTo(w * 0.9, h * 0.7); // Arm right
    path.lineTo(w * 0.8, h * 0.45); // Shoulder right
    path.lineTo(w * 0.7, h * 0.3); // Neck right

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}