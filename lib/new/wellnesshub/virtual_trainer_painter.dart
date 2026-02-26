import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/workout_config.dart';

class VirtualTrainerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (One rep cycle)
  final ExerciseType type;
  final Color color;

  VirtualTrainerPainter({required this.progress, required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 🎯 Paint Styles
    final paintBody = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final paintHead = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final paintFloor = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 2;

    // ============================================================
    // 🎯 ROUTE TO CUSTOM ANIMATIONS
    // Some exercises have completely custom sideways/seated views
    // ============================================================
    switch (type) {
      case ExerciseType.pushup:
        _drawPushup(canvas, size, paintBody, paintHead, paintFloor);
        return; // Exit early since it has a custom sideways view
      case ExerciseType.wristStretch:
        _drawWristStretch(canvas, size, paintBody);
        return;
      case ExerciseType.seatedTwist:
        _drawSeatedTwist(canvas, size, paintBody, paintHead);
        return;
      case ExerciseType.pacing:
        _drawPacing(canvas, size, paintBody, paintHead);
        return;
      case ExerciseType.calfRaise:
        _drawCalfRaise(canvas, size, paintBody, paintHead);
        return;
      default:
      // Continue to the default standing humanoid drawing logic below
        break;
    }

    // ============================================================
    // 🎯 DEFAULT STANDING HUMANOID LOGIC
    // ============================================================
    final cx = size.width / 2;
    final cy = size.height * 0.6; // Center of body

    double headX = cx;
    double headY = -60;
    double shoulderY = -40; // Where arms attach
    double torsoBotY = 30;

    // Arms (Offsets from shoulder)
    Offset leftHand = const Offset(-30, 50);
    Offset rightHand = const Offset(30, 50);

    // Legs
    Offset leftKnee = const Offset(-15, 60);
    Offset rightKnee = const Offset(15, 60);
    Offset leftFoot = const Offset(-20, 100);
    Offset rightFoot = const Offset(20, 100);

    double floorY = cy + 105;

    // --- ANIMATION MODIFIERS ---

    // 1. JUMPING JACKS
    if (type == ExerciseType.jumpingJack) {
      final t = math.sin(progress * math.pi); // 0 -> 1 -> 0

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
      final t = math.sin(progress * math.pi); // Down -> Up
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
        final lift = math.sin(t * 2 * math.pi) * 40;
        leftKnee = Offset(-15, 60 - lift);
        leftFoot = Offset(-20, 100 - lift);
      } else {
        final lift = math.sin((t - 0.5) * 2 * math.pi) * 40;
        rightKnee = Offset(15, 60 - lift);
        rightFoot = Offset(20, 100 - lift);
      }
      leftHand = Offset(-30, 50 - (math.sin(t * 4 * math.pi) * 20)); // Arms swing
      rightHand = Offset(30, 50 + (math.sin(t * 4 * math.pi) * 20));
    }

    // 4. ARM CIRCLES
    else if (type == ExerciseType.armCircles) {
      final t = progress * 2 * math.pi;
      // Hands orbit shoulders
      leftHand = Offset(-50 + (15 * math.cos(t)), -10 + (15 * math.sin(t)));
      rightHand = Offset(50 + (15 * math.cos(t + math.pi)), -10 + (15 * math.sin(t + math.pi)));
    }

    // 5. SHOULDER SHRUGS (Lift & Drop)
    else if (type == ExerciseType.shoulderShrug) {
      // 0 -> 1 -> 0 (Up then Down)
      final t = math.sin(progress * math.pi);

      // Shoulders go UP
      double lift = t * 15;
      shoulderY -= lift;

      // Hands go up with shoulders
      leftHand = Offset(-30, 50 - lift);
      rightHand = Offset(30, 50 - lift);
    }

    // 6. NECK ROLLS
    else if (type == ExerciseType.neckRoll) {
      final t = math.sin(progress * 2 * math.pi); // -1 to 1

      // Head moves Left <-> Right in an arc
      headX = cx + (t * 15);
      headY = -60 + (t.abs() * 5); // Dips slightly at sides
    }

    // --- DRAW DEFAULT HUMANOID ---

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

  // =========================================================
  // 🎯 CUSTOM DRAWING METHODS (For non-standard poses)
  // =========================================================

  void _drawPushup(Canvas canvas, Size size, Paint paintBody, Paint paintHead, Paint paintFloor) {
    final cx = size.width / 2;
    final cy = size.height * 0.6;
    final t = math.sin(progress * math.pi);
    final floorY = cy + 40;

    double bodyH = 10 + (t * 30); // Height from floor

    canvas.drawCircle(Offset(cx - 50, floorY - bodyH - 10), 12, paintHead); // Head
    canvas.drawLine(Offset(cx - 40, floorY - bodyH), Offset(cx + 40, floorY - 10), paintBody); // Body
    canvas.drawLine(Offset(cx - 35, floorY - bodyH), Offset(cx - 35, floorY), paintBody..strokeWidth=4); // Arms
    canvas.drawLine(Offset(cx - 80, floorY), Offset(cx + 80, floorY), paintFloor); // Floor
  }

  void _drawWristStretch(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw the forearm (static)
    canvas.drawLine(Offset(center.dx - 40, center.dy), center, paint);

    // Draw the hand bending up and down based on progress
    final double angle = math.sin(progress * math.pi * 2) * (math.pi / 3); // Bends up to 60 degrees
    const double handLength = 35.0;

    final Offset handEnd = Offset(
      center.dx + handLength * math.cos(angle),
      center.dy + handLength * math.sin(angle),
    );

    // Hand
    canvas.drawLine(center, handEnd, paint);

    // Subtle indicator arc to show motion
    paint.strokeWidth = 2.0;
    paint.color = paint.color.withOpacity(0.3);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: 25),
        -math.pi / 3,
        (math.pi / 3) * 2,
        false,
        paint
    );
  }

  void _drawSeatedTwist(Canvas canvas, Size size, Paint paintBody, Paint paintHead) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw the chair & legs (Static)
    canvas.drawLine(Offset(center.dx, center.dy + 10), Offset(center.dx, center.dy + 40), paintBody); // Lower spine
    canvas.drawLine(Offset(center.dx, center.dy + 40), Offset(center.dx + 30, center.dy + 40), paintBody); // Thighs
    canvas.drawLine(Offset(center.dx + 30, center.dy + 40), Offset(center.dx + 30, center.dy + 80), paintBody); // Calves

    // Twist animation: Shoulders shifting left and right
    final double twist = math.sin(progress * math.pi * 2) * 25;

    // Upper spine twisting slightly
    final topSpine = Offset(center.dx + (twist * 0.2), center.dy - 10);
    canvas.drawLine(Offset(center.dx, center.dy + 10), topSpine, paintBody);

    // Arms swinging side to side
    canvas.drawLine(Offset(topSpine.dx - 20 + twist, topSpine.dy + 15), Offset(topSpine.dx + 20 + twist, topSpine.dy + 15), paintBody);

    // Head (Follows the twist slightly)
    canvas.drawCircle(Offset(topSpine.dx, topSpine.dy - 15), 12, paintHead);
  }

  void _drawPacing(Canvas canvas, Size size, Paint paintBody, Paint paintHead) {
    final center = Offset(size.width / 2, size.height / 2);
    final double stride = math.sin(progress * math.pi * 2) * 20; // Legs moving back and forth

    // Head
    canvas.drawCircle(Offset(center.dx, center.dy - 40), 12, paintHead);

    // Body
    canvas.drawLine(Offset(center.dx, center.dy - 28), Offset(center.dx, center.dy + 20), paintBody);

    // Legs (Scissor motion)
    canvas.drawLine(Offset(center.dx, center.dy + 20), Offset(center.dx - stride, center.dy + 60), paintBody);
    canvas.drawLine(Offset(center.dx, center.dy + 20), Offset(center.dx + stride, center.dy + 60), paintBody);

    // Arms (Opposite of legs)
    canvas.drawLine(Offset(center.dx, center.dy - 10), Offset(center.dx + stride, center.dy + 20), paintBody);
    canvas.drawLine(Offset(center.dx, center.dy - 10), Offset(center.dx - stride, center.dy + 20), paintBody);
  }

  void _drawCalfRaise(Canvas canvas, Size size, Paint paintBody, Paint paintHead) {
    final center = Offset(size.width / 2, size.height / 2);

    // Lift animation: Up and down, pausing slightly at the bottom
    final double rawLift = math.sin(progress * math.pi * 2);
    final double lift = (rawLift > 0 ? rawLift : 0) * -15;

    final double offsetY = center.dy + lift;

    // Head
    canvas.drawCircle(Offset(center.dx, offsetY - 40), 12, paintHead);

    // Body & Arms
    canvas.drawLine(Offset(center.dx, offsetY - 28), Offset(center.dx, offsetY + 20), paintBody);
    canvas.drawLine(Offset(center.dx, offsetY - 10), Offset(center.dx - 15, offsetY + 20), paintBody);
    canvas.drawLine(Offset(center.dx, offsetY - 10), Offset(center.dx + 15, offsetY + 20), paintBody);

    // Legs (Pivot at the toes, lifting the heel)
    if (lift < -1) {
      canvas.drawLine(Offset(center.dx, offsetY + 20), Offset(center.dx - 10, center.dy + 55), paintBody); // leg
      canvas.drawLine(Offset(center.dx - 10, center.dy + 55), Offset(center.dx + 10, center.dy + 60), paintBody); // foot angled
    } else {
      canvas.drawLine(Offset(center.dx, offsetY + 20), Offset(center.dx, center.dy + 60), paintBody); // leg straight
      canvas.drawLine(Offset(center.dx - 5, center.dy + 60), Offset(center.dx + 15, center.dy + 60), paintBody); // flat foot
    }
  }

  @override
  bool shouldRepaint(covariant VirtualTrainerPainter old) => true;
}