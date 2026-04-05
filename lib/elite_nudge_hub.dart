import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutricare_connect/health_content.dart';


// ===========================================================================
// 1. 🌟 THE GLOWING DASHBOARD NUDGE BUTTON
// ===========================================================================
class EliteNudgeHub extends StatefulWidget {
  final String clientId;
  const EliteNudgeHub({super.key, required this.clientId});

  @override
  State<EliteNudgeHub> createState() => _EliteNudgeHubState();
}

class _EliteNudgeHubState extends State<EliteNudgeHub> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openInsightDeck(BuildContext context) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InsightCarouselDeck(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final neonGreen = const Color(0xFF00E676);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: neonGreen.withOpacity(0.15 + (pulse * 0.15)),
                blurRadius: 24 + (pulse * 8),
                spreadRadius: 1 + (pulse * 2),
                offset: const Offset(-4, -4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openInsightDeck(context),
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      neonGreen.withOpacity(0.15 + (pulse * 0.1)),
                      isDark ? const Color(0xFF121826) : Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.6],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: neonGreen.withOpacity(0.3 + (pulse * 0.3)),
                      width: 1.5 + (pulse * 0.5)
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: neonGreen.withOpacity(0.15),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: neonGreen.withOpacity(0.4), blurRadius: 8)]
                      ),
                      child: Icon(Icons.local_fire_department_rounded, color: neonGreen, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text("DAILY INSIGHT READY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: neonGreen, letterSpacing: 1.0)),
                              const SizedBox(width: 6),
                              Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(color: neonGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: neonGreen, blurRadius: 4)])
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tap to explore today's clinical truths",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.hintColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// 🎴 2. THE ZOOM-CAROUSEL MODAL (Cover Flow Effect)
// ===========================================================================
// ===========================================================================
// 🎴 2. THE ZOOM-CAROUSEL MODAL (ELEVATED "DEEP FOCUS" EFFECT)
// ===========================================================================
class InsightCarouselDeck extends StatefulWidget {
  const InsightCarouselDeck({super.key});

  @override
  State<InsightCarouselDeck> createState() => _InsightCarouselDeckState();
}

class _InsightCarouselDeckState extends State<InsightCarouselDeck> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  late List<HealthTip> _deck;
  String _currentLang = 'en';

  @override
  void initState() {
    super.initState();
    _deck = List<HealthTip>.from(masterHealthTips)..shuffle();
    _deck = _deck.take(10).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildLanguageToggle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    Widget langButton(String code, String label) {
      final isSelected = _currentLang == code;
      return GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
            setState(() => _currentLang = code);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? Colors.white : theme.hintColor,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          langButton('en', 'EN'),
          langButton('hi', 'HI'),
          langButton('or', 'OR'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final neonGreen = const Color(0xFF00E676);

    // 🚀 1. THE BLUR EFFECT
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // Increased blur for smoother glass
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          // 🚀 2. THE FIX: TRUE FROSTED GLASS GRADIENT
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              // Top is more transparent to show the blur, bottom is slightly darker to anchor the UI
              isDark ? const Color(0xFF0B0F19).withOpacity(0.65) : Colors.white.withOpacity(0.75),
              isDark ? const Color(0xFF0B0F19).withOpacity(0.85) : Colors.white.withOpacity(0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),

          // 🚀 3. GLOWING TOP EDGE & UPWARD SHADOW
          // Adding a subtle white inner border helps the glass "pop" from the background
          border: Border(
            top: BorderSide(color: neonGreen.withOpacity(0.5), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(color: neonGreen.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, -10)),
            // Drop shadow is darker in light mode, softer in dark mode
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.1), blurRadius: 30, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🚀 4. GLOWING DRAG HANDLE
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Column(
                    children: [
                      Container(
                          width: 48, height: 4,
                          decoration: BoxDecoration(
                              color: neonGreen.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [BoxShadow(color: neonGreen.withOpacity(0.6), blurRadius: 6)]
                          )
                      ),
                      const SizedBox(height: 8),
                      Icon(Icons.lightbulb_outline_rounded, size: 16, color: neonGreen.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),

              // Header row with Title and Language Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("CLINICAL INSIGHTS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white70 : theme.hintColor, letterSpacing: 2.0)),
                    _buildLanguageToggle(theme),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 🚀 THE ZOOM CAROUSEL ENGINE
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _deck.length,
                  onPageChanged: (index) => HapticFeedback.selectionClick(),
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = _pageController.page! - index;
                          value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
                        } else {
                          value = index == 0 ? 1.0 : 0.85;
                        }

                        return Transform.scale(
                          scale: value,
                          child: EliteInsightCard(
                            tip: _deck[index],
                            currentLang: _currentLang,
                            isDark: isDark,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe_left_rounded, color: isDark ? Colors.white54 : theme.hintColor, size: 20),
                    const SizedBox(width: 8),
                    Text("Swipe to explore", style: TextStyle(color: isDark ? Colors.white54 : theme.hintColor, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Icon(Icons.swipe_right_rounded, color: isDark ? Colors.white54 : theme.hintColor, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ===========================================================================
// 🎴 3. THE DIRECT-LOAD EDITORIAL CARD (No Scratching!)
// ===========================================================================
class EliteInsightCard extends StatelessWidget {
  final HealthTip tip;
  final String currentLang;
  final bool isDark;

  const EliteInsightCard({
    super.key,
    required this.tip,
    required this.currentLang,
    required this.isDark,
  });

  // 🎨 DYNAMIC GRADIENT ENGINE BASED ON CATEGORY
  List<Color> _getCategoryGradient(String category, bool isDark) {
    final cat = category.toLowerCase();
    if (cat.contains("weight") || cat.contains("diet") || cat.contains("liver")) {
      return isDark ? [const Color(0xFF0F2027), const Color(0xFF203A43)] : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)];
    } else if (cat.contains("heart") || cat.contains("blood") || cat.contains("pain")) {
      return isDark ? [const Color(0xFF4A0000), const Color(0xFF280000)] : [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)];
    } else if (cat.contains("women") || cat.contains("kids")) {
      return isDark ? [const Color(0xFF2A0845), const Color(0xFF140424)] : [const Color(0xFFF3E5F5), const Color(0xFFE1BEE7)];
    } else if (cat.contains("gut") || cat.contains("kidney")) {
      return isDark ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)];
    }
    return isDark ? [const Color(0xFF141E30), const Color(0xFF243B55)] : [const Color(0xFFF5F7FA), const Color(0xFFE4EBF5)];
  }

  @override
  Widget build(BuildContext context) {
    final titleText = tip.title[currentLang] ?? tip.title['en'] ?? "";
    final bodyText = tip.body[currentLang] ?? tip.body['en'] ?? "";
    final neonGreen = const Color(0xFF00E676);
    final bgColors = _getCategoryGradient(tip.category, isDark);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), // Breathing room for shadows
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.5 : 0.15), blurRadius: 20, offset: const Offset(0, 10))
        ],
        border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CATEGORY BADGE
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: neonGreen, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                    tip.category.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.0,
                        color: isDark ? Colors.white60 : Colors.black54
                    )
                ),
              ],
            ),

            const Spacer(flex: 1),

            // EDITORIAL HEADLINE
            Text(
                titleText,
                style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87
                )
            ),

            const SizedBox(height: 24),
            Container(width: 40, height: 2, color: neonGreen.withOpacity(0.5)),
            const SizedBox(height: 24),

            // BODY TEXT
            Text(
                bodyText,
                style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87
                )
            ),

            const Spacer(flex: 2),

            // WATERMARK/FOOTER
            Center(
              child: Icon(Icons.health_and_safety_rounded, color: isDark ? Colors.white10 : Colors.black12, size: 40),
            )
          ],
        ),
      ),
    );
  }
}