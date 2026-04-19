import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:pure_shift/health_content.dart';

class PremiumKnowledgeHub extends StatefulWidget {
  const PremiumKnowledgeHub({super.key});

  @override
  State<PremiumKnowledgeHub> createState() => _PremiumKnowledgeHubState();
}

class _PremiumKnowledgeHubState extends State<PremiumKnowledgeHub> {
  String _currentLang = 'en';
  late List<HealthTip> _displayTips;
  final PageController _pageController = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    // Shuffle the deck once per day/session
    _displayTips = List<HealthTip>.from(masterHealthTips)..shuffle(math.Random(DateTime.now().day));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final topTips = _displayTips.take(7).toList(); // A deck of 7 cards

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER & LANGUAGE TOGGLE
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_circle_rounded, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                      "Insight of the Day",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: -0.5)
                  ),
                ],
              ),
              _buildLanguageToggle(theme),
            ],
          ),
        ),

        // 2. 🚀 THE SWIPEABLE REVEAL DECK
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: topTips.length,
            itemBuilder: (context, index) {
              final tip = topTips[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: EliteRevealCard(
                    tip: tip,
                    currentLang: _currentLang,
                    theme: theme,
                    isDark: isDark
                ),
              );
            },
          ),
        ),
      ],
    );
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
}

// ===========================================================================
// 🎴 THE INDIVIDUAL REVEAL CARD
// ===========================================================================
class EliteRevealCard extends StatefulWidget {
  final HealthTip tip;
  final String currentLang;
  final ThemeData theme;
  final bool isDark;

  const EliteRevealCard({
    super.key,
    required this.tip,
    required this.currentLang,
    required this.theme,
    required this.isDark,
  });

  @override
  State<EliteRevealCard> createState() => _EliteRevealCardState();
}

class _EliteRevealCardState extends State<EliteRevealCard> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;

    final titleText = widget.tip.title[widget.currentLang] ?? widget.tip.title['en'] ?? "";
    final bodyText = widget.tip.body[widget.currentLang] ?? widget.tip.body['en'] ?? "";

    return GestureDetector(
      onTap: () {
        if (!_isRevealed) {
          HapticFeedback.heavyImpact();
          setState(() => _isRevealed = true);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF121826) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. THE ACTUAL CONTENT (Always rendered, but initially blurred)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CATEGORY BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.tip.category.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // HEADLINE
                    Text(
                      titleText,
                      maxLines: 2,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.2, color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 12),

                    // BODY TEXT
                    Expanded(
                      child: Text(
                        bodyText,
                        style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600, color: widget.theme.hintColor),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. 🚀 THE FROSTED GLASS OVERLAY (Melts away when tapped)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _isRevealed ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isRevealed, // Allows clicks to pass through once revealed
                  child: Stack(
                    children: [
                      // The Blur Effect
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(color: (widget.isDark ? Colors.black : Colors.white).withOpacity(0.6)),
                      ),
                      // The "Unlock" UI
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.15), shape: BoxShape.circle),
                              child: Icon(Icons.lock_open_rounded, color: colorScheme.primary, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Tap to Reveal",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: 1.0),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Unlock today's clinical truth",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.theme.hintColor),
                            ),
                          ],
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