import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

enum ReleaseElement { fire, water, air, earth, space }

class ElementConfig {
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const ElementConfig(this.name, this.description, this.icon, this.color);
}

class WorryShredderSheet extends StatefulWidget {
  const WorryShredderSheet({super.key});

  @override
  State<WorryShredderSheet> createState() => _WorryShredderSheetState();
}

class _WorryShredderSheetState extends State<WorryShredderSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final _audio = WellnessAudioService();

  ReleaseElement _selectedElement = ReleaseElement.fire;
  bool _isReleasing = false;

  late AnimationController _animationController;

  final Map<ReleaseElement, ElementConfig> _elements = {
    ReleaseElement.fire: const ElementConfig("Fire", "Burn away anger & frustration", Icons.local_fire_department_rounded, Colors.orange),
    ReleaseElement.water: const ElementConfig("Water", "Wash away sadness & regret", Icons.water_drop_rounded, Colors.blue),
    ReleaseElement.air: const ElementConfig("Air", "Scatter overthinking & stress", Icons.air_rounded, Colors.cyan),
    ReleaseElement.earth: const ElementConfig("Earth", "Bury fears to grow stronger", Icons.park_rounded, Colors.green),
    ReleaseElement.space: const ElementConfig("Space", "Surrender what you can't control", Icons.flare_rounded, Colors.deepPurpleAccent),
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 5500)
    );
  }

  void _releaseThought() async {
    if (_controller.text.trim().isEmpty) return;

    FocusScope.of(context).unfocus(); // Drop keyboard
    _audio.hapticHeavy();

    setState(() => _isReleasing = true);

    await _animationController.forward();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Thought released to ${_elements[_selectedElement]!.name} 🍃",
                style: const TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)
            ),
            backgroundColor: _elements[_selectedElement]!.color.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final config = _elements[_selectedElement]!;

    // 🚀 STRICT SAFE AREA HANDLING
    return SafeArea(
      top: true,
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),

              // 🎯 HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🚀 REFINED HEADER (Max Size 10, w700)
                          Text("COGNITIVE DEFUSION", style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          // 🚀 REFINED SUBTITLE (Max Size 12, w700)
                          Text("Externalize your worry", style: TextStyle(fontFamily: kBodyFont, color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton(
                        icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        }
                    )
                  ],
                ),
              ),

              // 🎯 CINEMATIC CANVAS
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. The Paper Animation
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final val = _animationController.value;
                        final curve = Curves.easeInOutCubic.transform(val);

                        double dy = 0.0;
                        double dx = 0.0;
                        double scale = 1.0;
                        double rotation = 0.0;

                        double opacity = 1.0;
                        if (curve > 0.4) {
                          opacity = 1.0 - ((curve - 0.4) * 1.6).clamp(0.0, 1.0);
                        }

                        Color filterColor = Colors.transparent;

                        switch (_selectedElement) {
                          case ReleaseElement.fire:
                            dy = -100 * curve;
                            dx = math.sin(curve * math.pi * 30) * 8;
                            rotation = math.sin(curve * math.pi * 20) * 0.03;
                            scale = 1.0 - (curve * 0.4);
                            filterColor = Colors.black.withOpacity(curve.clamp(0.0, 1.0));
                            break;
                          case ReleaseElement.water:
                            dy = 150 * curve;
                            filterColor = Colors.blue.withOpacity(curve * 0.9);
                            break;
                          case ReleaseElement.air:
                            dy = -250 * curve;
                            dx = 100 * math.sin(curve * math.pi * 2);
                            rotation = curve * math.pi * 2;
                            scale = 1.0 - (curve * 0.5);
                            break;
                          case ReleaseElement.earth:
                            dy = 200 * curve;
                            scale = 1.0 - (curve * 0.9);
                            filterColor = Colors.brown.shade900.withOpacity(curve);
                            break;
                          case ReleaseElement.space:
                            rotation = curve * math.pi * 6;
                            scale = 1.0 - curve;
                            filterColor = Colors.deepPurpleAccent.withOpacity(curve);
                            break;
                        }

                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Transform.rotate(
                            angle: rotation,
                            child: Transform.scale(
                              scale: scale.clamp(0.0, 2.0),
                              child: Opacity(
                                opacity: opacity.clamp(0.0, 1.0),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Container(
                                    height: 240,
                                    width: MediaQuery.of(context).size.width * 0.85,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Color.lerp(isDark ? theme.cardColor : const Color(0xFFFDFBF7), filterColor, curve),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                    ),
                                    child: TextField(
                                      controller: _controller,
                                      maxLines: 10,
                                      enabled: !_isReleasing,
                                      // 🚀 REFINED INPUT TEXT (Max Size 12, w500)
                                      style: TextStyle(
                                          fontFamily: kBodyFont,
                                          color: Color.lerp(colorScheme.onSurface, Colors.white, curve),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          height: 1.5
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "I am feeling worried about...",
                                        hintStyle: TextStyle(fontFamily: kBodyFont, color: theme.hintColor.withOpacity(0.5), fontSize: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // 2. The Continuous Particle Engine Overlay
                    if (_isReleasing)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _ContinuousParticlePainter(
                                    globalProgress: _animationController.value,
                                    element: _selectedElement,
                                    themeColor: colorScheme.onSurface
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 🎯 CINEMATIC CONTROL DECK
              AnimatedSize(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _isReleasing ? 0.0 : 1.0,
                  child: _isReleasing
                      ? const SizedBox(width: double.infinity, height: 0)
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      // 🚀 REFINED LABEL (Max Size 10, w700)
                      Text("SELECT ELEMENT", style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ReleaseElement.values.map((el) {
                          final elConfig = _elements[el]!;
                          final isSel = _selectedElement == el;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _audio.playClick();
                              setState(() => _selectedElement = el);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: isSel ? elConfig.color.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : theme.cardColor),
                                shape: BoxShape.circle,
                                border: Border.all(color: isSel ? elConfig.color : theme.dividerColor.withOpacity(0.2), width: isSel ? 2 : 1),
                              ),
                              child: Icon(elConfig.icon, color: isSel ? elConfig.color : theme.hintColor, size: 20),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                            config.description,
                            key: ValueKey(_selectedElement),
                            // 🚀 REFINED DESCRIPTION (Max Size 11, w600)
                            style: TextStyle(fontFamily: kBodyFont, color: config.color, fontWeight: FontWeight.w600, fontSize: 11)
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50, // 🚀 Reduced height to match compact buttons
                          child: FilledButton.icon(
                            onPressed: _releaseThought,
                            icon: Icon(config.icon, size: 18),
                            // 🚀 REFINED BUTTON LABEL (Max Size 12, w700)
                            label: Text("Release to ${config.name}", style: const TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            style: FilledButton.styleFrom(
                              elevation: 0, // 🚀 Flat premium look
                              backgroundColor: config.color,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// 🎯 CONTINUOUS PARTICLE ENGINE (Harry Potter Style)
// =======================================================================
class _ContinuousParticlePainter extends CustomPainter {
  final double globalProgress;
  final ReleaseElement element;
  final Color themeColor;

  _ContinuousParticlePainter({required this.globalProgress, required this.element, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (globalProgress <= 0 || globalProgress >= 1) return;

    final rand = math.Random(12345);
    final paint = Paint()..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    for (int i = 0; i < 250; i++) {
      double spawnDelay = rand.nextDouble() * 0.7;
      double p = (globalProgress - spawnDelay) / 0.3;

      if (p <= 0.0 || p >= 1.0) continue;

      final startX = (rand.nextDouble() * size.width * 1.5) - (size.width * 0.25);
      final startY = (rand.nextDouble() * size.height * 1.5) - (size.height * 0.25);
      final speedX = (rand.nextDouble() - 0.5) * 2;
      final pSize = rand.nextDouble() * 12 + 4;

      double x = startX;
      double y = startY;
      double s = pSize * (1.0 - p);
      Color c = Colors.white;

      double opacityFade = (math.sin(p * math.pi)).clamp(0.0, 1.0);

      if (element == ReleaseElement.fire) {
        final flameStartX = cx + (rand.nextDouble() - 0.5) * 250;
        final flameStartY = cy + 150 + (rand.nextDouble() * 100);
        y = flameStartY - (p * (300 + rand.nextDouble() * 200));
        x = flameStartX + math.sin(p * 10 + i) * 30;

        if (p < 0.2) c = Colors.white;
        else if (p < 0.5) c = Colors.yellow;
        else if (p < 0.8) c = Colors.orange;
        else c = Colors.red.shade900;

        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      }
      else if (element == ReleaseElement.water) {
        final rainStartY = -50 - (rand.nextDouble() * 100);
        y = rainStartY + (p * size.height * 1.5);
        x = startX + (speedX * 50 * p);

        c = (i % 2 == 0) ? Colors.blueAccent : Colors.lightBlue;
        paint.maskFilter = null;
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: s * 0.4, height: s * 3), paint..color = c.withOpacity(opacityFade));
        continue;
      }
      else if (element == ReleaseElement.air) {
        y = startY - (p * 400);
        x = cx + (math.sin(p * math.pi * 4 + i) * (p * 300));
        c = (i % 3 == 0) ? Colors.cyan : Colors.white;
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      }
      else if (element == ReleaseElement.earth) {
        final rockStartX = cx + (rand.nextDouble() - 0.5) * 200;
        final rockStartY = cy + (rand.nextDouble() - 0.5) * 100;

        y = rockStartY + (p * p * 400);
        x = rockStartX + (speedX * p * 150);
        c = (i % 3 == 0) ? Colors.brown.shade800 : (i % 3 == 1 ? Colors.brown.shade400 : Colors.green.shade900);

        paint.maskFilter = null;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(p * 10 * speedX);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s), paint..color = c.withOpacity(opacityFade));
        canvas.restore();
        continue;
      }
      else if (element == ReleaseElement.space) {
        final edgeX = cx + (math.cos(i) * size.width);
        final edgeY = cy + (math.sin(i) * size.height);

        x = edgeX + ((cx - edgeX) * p);
        y = edgeY + ((cy - edgeY) * p);

        final angle = p * 15;
        final spiralX = cx + (x - cx) * math.cos(angle) - (y - cy) * math.sin(angle);
        final spiralY = cy + (x - cx) * math.sin(angle) + (y - cy) * math.cos(angle);
        x = spiralX;
        y = spiralY;

        c = (i % 4 == 0) ? Colors.purpleAccent : (i % 4 == 1 ? Colors.white : Colors.deepPurple);
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      }

      canvas.drawCircle(Offset(x, y), s, paint..color = c.withOpacity(opacityFade));
    }
  }

  @override
  bool shouldRepaint(covariant _ContinuousParticlePainter old) => true;
}