import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

enum FluidMode { swarm, repel, orbit }

// 🎯 PARENT WIDGET: Only rebuilds when you press a button
class SomaticFluidSheet extends StatefulWidget {
  const SomaticFluidSheet({super.key});

  @override
  State<SomaticFluidSheet> createState() => _SomaticFluidSheetState();
}

class _SomaticFluidSheetState extends State<SomaticFluidSheet> {
  FluidMode _currentMode = FluidMode.swarm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // 🎯 PHYSICS CONTROL DECK
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  _buildModeBtn("Swarm", FluidMode.swarm, Icons.adjust_rounded, theme),
                  _buildModeBtn("Repel", FluidMode.repel, Icons.trip_origin_rounded, theme),
                  _buildModeBtn("Orbit", FluidMode.orbit, Icons.cyclone_rounded, theme),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 🎯 THE ISOLATED CANVAS WIDGET
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.primary.withOpacity(0.2), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _FluidPhysicsEngine(
                    mode: _currentMode,
                    themeColor: cs.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBtn(String label, FluidMode mode, IconData icon, ThemeData theme) {
    bool isSel = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _currentMode = mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: isSel ? theme.colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSel ? theme.colorScheme.onPrimary : Colors.grey),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: isSel ? theme.colorScheme.onPrimary : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// 🎯 CHILD WIDGET: The Isolated Physics Engine (Rebuilds 60 FPS safely)
class _FluidPhysicsEngine extends StatefulWidget {
  final FluidMode mode;
  final Color themeColor;

  const _FluidPhysicsEngine({required this.mode, required this.themeColor});

  @override
  State<_FluidPhysicsEngine> createState() => _FluidPhysicsEngineState();
}

class _FluidPhysicsEngineState extends State<_FluidPhysicsEngine> {
  late Ticker _ticker;
  final List<_Particle> _particles = [];
  Offset? _touchPosition;
  final int _maxParticles = 350;

  @override
  void initState() {
    super.initState();
    final random = Random();

    for (int i = 0; i < _maxParticles; i++) {
      _particles.add(_Particle(
        x: random.nextDouble() * 400,
        y: random.nextDouble() * 800,
        size: random.nextDouble() * 3.5 + 1.0,
        colorOpacity: random.nextDouble() * 0.5 + 0.2,
      ));
    }

    _ticker = Ticker((_) => _updatePhysics());
    _ticker.start();
  }

  void _updatePhysics() {
    final random = Random();

    for (var p in _particles) {
      p.vx *= 0.90;
      p.vy *= 0.90;

      if (_touchPosition != null) {
        double dx = _touchPosition!.dx - p.x;
        double dy = _touchPosition!.dy - p.y;
        double distance = sqrt(dx * dx + dy * dy);

        if (distance < 180) {
          double force = (180 - distance) / 180;

          // Uses the mode passed down from the parent widget
          if (widget.mode == FluidMode.swarm) {
            p.vx += (dx / distance) * force * 2.5;
            p.vy += (dy / distance) * force * 2.5;
          } else if (widget.mode == FluidMode.repel) {
            p.vx -= (dx / distance) * force * 4.0;
            p.vy -= (dy / distance) * force * 4.0;
          } else if (widget.mode == FluidMode.orbit) {
            double tangentX = -dy;
            double tangentY = dx;
            p.vx += (tangentX / distance) * force * 3.0 + (dx / distance) * force * 0.5;
            p.vy += (tangentY / distance) * force * 3.0 + (dy / distance) * force * 0.5;
          }
        }
      } else {
        p.vx += (random.nextDouble() - 0.5) * 0.6;
        p.vy += (random.nextDouble() - 0.5) * 0.6;
      }

      p.x += p.vx;
      p.y += p.vy;

      if (p.x < 0) p.x = 400;
      if (p.x > 400) p.x = 0;
      if (p.y < 0) p.y = 800;
      if (p.y > 800) p.y = 0;
    }

    if (mounted) setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _touchPosition = details.localPosition);
    HapticFeedback.selectionClick();
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _touchPosition = null);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This widget now ONLY contains the gesture detector and the canvas.
    return GestureDetector(
      onPanStart: (d) => _onPanUpdate(DragUpdateDetails(globalPosition: d.globalPosition, localPosition: d.localPosition)),
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        size: Size.infinite,
        painter: _ThemedFluidPainter(
          particles: _particles,
          themeColor: widget.themeColor,
        ),
      ),
    );
  }
}

// 🎯 DATA MODEL
class _Particle {
  double x, y, vx = 0, vy = 0;
  final double size;
  final double colorOpacity;
  _Particle({required this.x, required this.y, required this.size, required this.colorOpacity});
}

// 🎯 PAINTER
class _ThemedFluidPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color themeColor;

  _ThemedFluidPainter({required this.particles, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.blendMode = BlendMode.screen;

    for (var p in particles) {
      double dx = (p.x / 400) * size.width;
      double dy = (p.y / 800) * size.height;
      double speed = sqrt(p.vx * p.vx + p.vy * p.vy);

      double dynamicOpacity = (p.colorOpacity + (speed * 0.05)).clamp(0.1, 1.0);
      paint.color = themeColor.withOpacity(dynamicOpacity);

      canvas.drawCircle(Offset(dx, dy), p.size + (speed * 0.1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThemedFluidPainter old) => true;
}