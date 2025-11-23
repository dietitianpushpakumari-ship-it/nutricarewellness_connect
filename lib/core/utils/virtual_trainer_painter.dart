import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/workout_config.dart';

class VirtualTrainerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (One rep cycle)
  final ExerciseType type;
  final Color color;

  VirtualTrainerPainter({required this.progress, required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.6; // Center of body

    // Paint Styles
    final paintBody = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    final paintHead = Paint()..color = color..style = PaintingStyle.fill;
    final paintFloor = Paint()..color = Colors.grey.withOpacity(0.3)..strokeWidth = 2;

    // --- DEFAULT STANDING POSE ---
    double headX = cx;
    double headY = -60;
    double shoulderY = -40; // Where arms attach
    double torsoBotY = 30;

    // Arms (Offsets from shoulder)
    Offset leftHand = Offset(-30, 50);
    Offset rightHand = Offset(30, 50);

    // Legs
    Offset leftKnee = Offset(-15, 60);
    Offset rightKnee = Offset(15, 60);
    Offset leftFoot = Offset(-20, 100);
    Offset rightFoot = Offset(20, 100);

    double floorY = cy + 105;

    // ============================================================
    // 🎯 ANIMATION LOGIC
    // ============================================================

    // 1. JUMPING JACKS
    if (type == ExerciseType.jumpingJack) {
      final t = sin(progress * pi); // 0 -> 1 -> 0

      headY -= (t * 10);
      shoulderY -= (t * 10);
      torsoBotY -= (t * 5);

      // Legs Out
      leftFoot = Offset(-20 - (t * 30), 100);
      rightFoot = Offset(20 + (t * 30), 100);
      leftKnee = Offset(-15 - (t * 15), 60);
      rightKnee = Offset(15 + (t * 15), 60);

      // Arms Up
      leftHand = Offset(-50 - (t * 20), 50 - (t * 120)); // Arcs up
      rightHand = Offset(50 + (t * 20), 50 - (t * 120));
    }

    // 2. SQUATS
    else if (type == ExerciseType.squat) {
      final t = sin(progress * pi); // Down -> Up
      double drop = t * 40;

      headY += drop;
      shoulderY += drop;
      torsoBotY += drop;

      // Knees bend out
      leftKnee = Offset(-15 - (t * 15), 60 + (drop * 0.5));
      rightKnee = Offset(15 + (t * 15), 60 + (drop * 0.5));

      // Arms forward
      leftHand = Offset(-30, 50 - (t * 40));
      rightHand = Offset(30, 50 - (t * 40));
    }

    // 3. HIGH KNEES
    else if (type == ExerciseType.highKnees) {
      final t = progress;
      if (t < 0.5) {
        final lift = sin(t * 2 * pi) * 40;
        leftKnee = Offset(-15, 60 - lift);
        leftFoot = Offset(-20, 100 - lift);
      } else {
        final lift = sin((t - 0.5) * 2 * pi) * 40;
        rightKnee = Offset(15, 60 - lift);
        rightFoot = Offset(20, 100 - lift);
      }
      leftHand = Offset(-30, 50 - (sin(t * 4 * pi) * 20)); // Arms swing
      rightHand = Offset(30, 50 + (sin(t * 4 * pi) * 20));
    }

    // 4. ARM CIRCLES
    else if (type == ExerciseType.armCircles) {
      final t = progress * 2 * pi;
      // Hands orbit shoulders
      leftHand = Offset(-50 + (15 * cos(t)), -10 + (15 * sin(t)));
      rightHand = Offset(50 + (15 * cos(t + pi)), -10 + (15 * sin(t + pi)));
    }

    // 5. SHOULDER SHRUGS (Lift & Drop)
    else if (type == ExerciseType.shoulderShrug) {
      // 0 -> 1 -> 0 (Up then Down)
      final t = sin(progress * pi);

      // Shoulders go UP
      double lift = t * 15;
      shoulderY -= lift;

      // Hands go up with shoulders
      leftHand = Offset(-30, 50 - lift);
      rightHand = Offset(30, 50 - lift);
    }

    // 6. NECK ROLLS
    else if (type == ExerciseType.neckRoll) {
      final t = sin(progress * 2 * pi); // -1 to 1

      // Head moves Left <-> Right in an arc
      headX = cx + (t * 15);
      headY = -60 + (t.abs() * 5); // Dips slightly at sides
    }

    // 7. PUSHUPS (Side View Override)
    else if (type == ExerciseType.pushup) {
      final t = sin(progress * pi);
      floorY = cy + 40;
      double bodyH = 10 + (t * 30); // Height from floor

      canvas.drawCircle(Offset(cx - 50, floorY - bodyH - 10), 12, paintHead); // Head
      canvas.drawLine(Offset(cx - 40, floorY - bodyH), Offset(cx + 40, floorY - 10), paintBody); // Body
      canvas.drawLine(Offset(cx - 35, floorY - bodyH), Offset(cx - 35, floorY), paintBody..strokeWidth=4); // Arms
      canvas.drawLine(Offset(cx - 80, floorY), Offset(cx + 80, floorY), paintFloor); // Floor
      return;
    }

    // ============================================================
    // ✍️ DRAWING
    // ============================================================

    // Floor
    canvas.drawLine(Offset(cx - 60, floorY), Offset(cx + 60, floorY), paintFloor);

    // Legs
    canvas.drawLine(Offset(cx - 10, cy + torsoBotY), Offset(cx + leftKnee.dx, cy + leftKnee.dy), paintBody);
    canvas.drawLine(Offset(cx + leftKnee.dx, cy + leftKnee.dy), Offset(cx + leftFoot.dx, cy + leftFoot.dy), paintBody);

    canvas.drawLine(Offset(cx + 10, cy + torsoBotY), Offset(cx + rightKnee.dx, cy + rightKnee.dy), paintBody);
    canvas.drawLine(Offset(cx + rightKnee.dx, cy + rightKnee.dy), Offset(cx + rightFoot.dx, cy + rightFoot.dy), paintBody);

    // Torso
    canvas.drawLine(Offset(cx, cy + shoulderY), Offset(cx, cy + torsoBotY), paintBody);

    // Arms
    canvas.drawLine(Offset(cx, cy + shoulderY), Offset(cx + leftHand.dx, cy + leftHand.dy), paintBody);
    canvas.drawLine(Offset(cx, cy + shoulderY), Offset(cx + rightHand.dx, cy + rightHand.dy), paintBody);

    // Head
    canvas.drawCircle(Offset(headX, cy + headY), 15, paintHead);
  }

  @override
  bool shouldRepaint(covariant VirtualTrainerPainter old) => true;
}