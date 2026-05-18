import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Ensure these imports match your project structure
import 'package:pure_shift/health_content.dart';
import 'layout_utils.dart';

// 🚀 EDITORIAL FONT SETUP
const String kDisplayFont = 'Playfair Display';
const String kBodyFont = 'Lora';
const String kSansSerif = 'Inter';

// ===========================================================================
// 🎨 CATEGORY VISUAL IDENTITY ENGINE
// ===========================================================================
class CategoryStyle {
  final Color primary;
  final Color background;
  final IconData icon;

  CategoryStyle({required this.primary, required this.background, required this.icon});
}

CategoryStyle _getStyle(String category, bool isDark) {
  category = category.toLowerCase();

  if (category.contains('myth')) {
    return CategoryStyle(
      primary: const Color(0xFFFF5252), // Electric Red
      background: isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFF5F5),
      icon: Icons.auto_awesome_rounded,
    );
  } else if (category.contains('liver') || category.contains('organ') || category.contains('health')) {
    return CategoryStyle(
      primary: const Color(0xFF4CAF50), // Vital Green
      background: isDark ? const Color(0xFF1B2D1B) : const Color(0xFFF5FFF5),
      icon: Icons.favorite_rounded,
    );
  } else if (category.contains('lifestyle') || category.contains('diet')) {
    return CategoryStyle(
      primary: const Color(0xFF00B0FF), // Sky Blue
      background: isDark ? const Color(0xFF1B282D) : const Color(0xFFF5FBFF),
      icon: Icons.wb_sunny_rounded,
    );
  } else if (category.contains('awareness') || category.contains('tip')) {
    return CategoryStyle(
      primary: const Color(0xFFAA00FF), // Deep Purple
      background: isDark ? const Color(0xFF261B2D) : const Color(0xFFFAF5FF),
      icon: Icons.lightbulb_outline_rounded,
    );
  }

  // Default / General
  return CategoryStyle(
    primary: const Color(0xFF8B0000), // Crimson
    background: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    icon: Icons.spa_rounded,
  );
}

// ===========================================================================
// 1. 🌟 THE ELEGANT "EXPLORE" NUDGE BUTTON
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
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openInsightDeck(BuildContext context) {
    HapticFeedback.lightImpact();
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

    final Color bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAF9F6);
    final Color borderColor = isDark ? Colors.white24 : Colors.black12;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () => _openInsightDeck(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "THE DAILY READ",
                  style: TextStyle(fontFamily: kSansSerif, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: 2.0, color: theme.hintColor),
                ),
                const SizedBox(height: 4),
                Text(
                  "Curated Clinical Insights",
                  style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(18), fontWeight: FontWeight.w600, color: textColor, letterSpacing: -0.5),
                ),
              ],
            ),
            AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: textColor.withOpacity(0.1 + (_pulseController.value * 0.2)), width: 1.0),
                    ),
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textColor),
                  );
                }
            )
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 🎴 2. THE EDITORIAL MODAL DECK
// ===========================================================================
class InsightCarouselDeck extends StatefulWidget {
  const InsightCarouselDeck({super.key});

  @override
  State<InsightCarouselDeck> createState() => _InsightCarouselDeckState();
}

class _InsightCarouselDeckState extends State<InsightCarouselDeck> {
  final PageController _pageController = PageController(viewportFraction: 0.90, initialPage: 500);
  late List<HealthTip> _randomDeck;
  String _currentLang = 'en';

  @override
  void initState() {
    super.initState();
    final pool = List<HealthTip>.from(masterHealthTips)..shuffle();
    _randomDeck = pool.take(15).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildLanguageToggle(ThemeData theme, bool isDark) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = theme.hintColor.withOpacity(0.5);

    Widget langButton(String code, String label) {
      final isSelected = _currentLang == code;
      return GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.lightImpact();
            setState(() => _currentLang = code);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? activeColor : Colors.transparent, width: 2.0))),
          child: Text(
            label,
            style: TextStyle(fontFamily: kSansSerif, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, letterSpacing: 1.0, color: isSelected ? activeColor : inactiveColor),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [langButton('en', 'EN'), langButton('hi', 'HI'), langButton('or', 'OR')],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color sheetBg = isDark ? const Color(0xFF121212) : const Color(0xFFF4F3EF);
    final Color textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40)]
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              ),
            ),

            // Header Top Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.scale(24), vertical: context.scale(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Vol. 1 — Daily Edition", style: TextStyle(fontFamily: kSansSerif, fontSize: context.scale(10), fontWeight: FontWeight.w600, color: theme.hintColor, letterSpacing: 1.0, fontStyle: FontStyle.italic)),
                  _buildLanguageToggle(theme, isDark),
                ],
              ),
            ),

            Divider(color: textColor.withOpacity(0.1), height: 1, thickness: 1),
            const SizedBox(height: 24),

            // Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: 1000, // Infinite loop illusion
                onPageChanged: (index) => HapticFeedback.selectionClick(),
                itemBuilder: (context, index) {
                  final tip = _randomDeck[index % _randomDeck.length];

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = (_pageController.page! - index).abs();
                        value = (1 - (value * 0.10)).clamp(0.0, 1.0);
                      }
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value,
                          child: EliteInsightCard(tip: tip, currentLang: _currentLang, isDark: isDark),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Swipe to continue reading",
                style: TextStyle(fontFamily: kSansSerif, color: theme.hintColor.withOpacity(0.5), fontSize: 11, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 🎴 3. THE DYNAMIC MAGAZINE ARTICLE CARD
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

  @override
  Widget build(BuildContext context) {
    final titleText = tip.title[currentLang] ?? tip.title['en'] ?? "";
    final bodyText = tip.body[currentLang] ?? tip.body['en'] ?? "";

    // 🎨 Get the dynamically matched style for this tip's category
    final style = _getStyle(tip.category, isDark);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(8)),
      decoration: BoxDecoration(
        color: style.background, // Dynamic Tinted Background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.primary.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: style.primary.withOpacity(isDark ? 0.15 : 0.08), blurRadius: 30, offset: const Offset(0, 15))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 🌟 AMBIENT CORNER GLOW
            Positioned(
              top: -60, right: -60,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle, color: style.primary.withOpacity(0.08)),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(context.scale(28)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🏁 TOP ROW: Category Pill & Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: style.primary, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          tip.category.toUpperCase(),
                          style: TextStyle(fontFamily: kSansSerif, fontSize: context.scale(9), fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
                        ),
                      ),
                      Icon(style.icon, color: style.primary.withOpacity(0.3), size: 28),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 📰 HEADLINE
                  Text(
                    titleText,
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      fontSize: context.scale(32),
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🖋️ DYNAMIC DIVIDER
                  Container(height: 2, width: 60, color: style.primary),

                  const SizedBox(height: 24),

                  // 📖 BODY TEXT (With Dynamic Drop Cap)
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            // DROP CAP (The giant first letter)
                            TextSpan(
                              text: bodyText.isNotEmpty ? bodyText.substring(0, 1) : "",
                              style: TextStyle(
                                fontFamily: kDisplayFont,
                                fontSize: context.scale(60),
                                fontWeight: FontWeight.w400,
                                color: style.primary, // Dynamically matches the category
                                height: 1.0,
                              ),
                            ),
                            // THE REST OF THE BODY
                            TextSpan(
                              text: bodyText.length > 1 ? bodyText.substring(1) : "",
                              style: TextStyle(
                                fontFamily: kBodyFont,
                                fontSize: context.scale(16),
                                fontWeight: FontWeight.w400,
                                height: 1.8,
                                color: isDark ? Colors.white70 : Colors.black54,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 🛡️ VERIFICATION FOOTER
                  Container(
                    margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: style.primary.withOpacity(0.05),
                      border: Border.all(color: style.primary.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_outlined, size: 16, color: style.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Medically Reviewed & Clinically Verified",
                            style: TextStyle(fontFamily: kSansSerif, fontSize: context.scale(10), fontWeight: FontWeight.w600, color: style.primary, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}