import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Ensure these imports match your project structure
import 'package:pure_shift/health_content.dart';
import 'layout_utils.dart';

// 🚀 EDITORIAL FONT SETUP (Use highly elegant fonts if available)
const String kDisplayFont = 'Playfair Display'; // Or 'Georgia', 'Cinzel'
const String kBodyFont = 'Lora'; // Or 'Merriweather', 'Inter' for modern editorial
const String kSansSerif = 'Inter'; // For UI elements (buttons, tags)

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
    HapticFeedback.lightImpact(); // Editorial feel is subtle
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

    // Editorial Palette
    final Color bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAF9F6); // Off-white/Cream
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
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
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
                  style: TextStyle(
                    fontFamily: kSansSerif,
                    fontSize: context.scale(10),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Curated Clinical Insights",
                  style: TextStyle(
                    fontFamily: kDisplayFont,
                    fontSize: context.scale(18),
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
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
                      border: Border.all(
                        color: textColor.withOpacity(0.1 + (_pulseController.value * 0.2)),
                        width: 1.0,
                      ),
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
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? activeColor : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kSansSerif,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 1.0,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        langButton('en', 'EN'),
        langButton('hi', 'HI'),
        langButton('or', 'OR'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color sheetBg = isDark ? const Color(0xFF121212) : const Color(0xFFF4F3EF); // Premium paper feel
    final Color textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90, // Taller for reading
      decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40)
          ]
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: theme.hintColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2)
                    )
                ),
              ),
            ),

            // Header Top Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.scale(24), vertical: context.scale(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      "Vol. 1 — Daily Edition",
                      style: TextStyle(
                          fontFamily: kSansSerif,
                          fontSize: context.scale(10),
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                          letterSpacing: 1.0,
                          fontStyle: FontStyle.italic
                      )
                  ),
                  _buildLanguageToggle(theme, isDark),
                ],
              ),
            ),

            // Thin elegant divider
            Divider(color: textColor.withOpacity(0.1), height: 1, thickness: 1),
            const SizedBox(height: 24),

            // Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: 1000,
                onPageChanged: (index) => HapticFeedback.selectionClick(),
                itemBuilder: (context, index) {
                  final tip = _randomDeck[index % _randomDeck.length];

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = (_pageController.page! - index).abs();
                        value = (1 - (value * 0.10)).clamp(0.0, 1.0); // Subtle scale
                      }

                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value,
                          child: EliteInsightCard(
                            tip: tip,
                            currentLang: _currentLang,
                            isDark: isDark,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Subtle Footer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Swipe to continue reading",
                style: TextStyle(
                  fontFamily: kSansSerif,
                  color: theme.hintColor.withOpacity(0.5),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 🎴 3. THE MAGAZINE ARTICLE CARD
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

    // Elegant Palette
    final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color primaryText = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A);
    final Color secondaryText = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF666666);
    final Color accentColor = const Color(0xFF8B0000); // Deep Crimson for drop cap/lines

    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(8)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(2), // Sharp, print-like corners
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, 15)
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(context.scale(32)), // Massive, luxurious margins
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KICKER (Category)
            Text(
              tip.category.toUpperCase(),
              style: TextStyle(
                fontFamily: kSansSerif,
                fontSize: context.scale(10),
                fontWeight: FontWeight.w800,
                letterSpacing: 3.0,
                color: accentColor,
              ),
            ),

            const SizedBox(height: 16),

            // HEADLINE
            Text(
              titleText,
              style: TextStyle(
                fontFamily: kDisplayFont,
                fontSize: context.scale(32), // Huge, elegant title
                fontWeight: FontWeight.w700,
                height: 1.1,
                letterSpacing: -0.5,
                color: primaryText,
              ),
            ),

            const SizedBox(height: 24),

            // EDITORIAL DIVIDER
            Row(
              children: [
                Expanded(child: Container(height: 1, color: secondaryText.withOpacity(0.2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.spa_rounded, size: 12, color: secondaryText.withOpacity(0.5)),
                ),
                Expanded(child: Container(height: 1, color: secondaryText.withOpacity(0.2))),
              ],
            ),

            const SizedBox(height: 24),

            // BODY TEXT (With Drop Cap styling simulated)
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
                          fontSize: context.scale(56), // Giant letter
                          fontWeight: FontWeight.w400,
                          color: primaryText,
                          height: 1.0, // Tight line height to align with text
                        ),
                      ),
                      // THE REST OF THE BODY
                      TextSpan(
                        text: bodyText.length > 1 ? bodyText.substring(1) : "",
                        style: TextStyle(
                          fontFamily: kBodyFont,
                          fontSize: context.scale(16),
                          fontWeight: FontWeight.w400,
                          height: 1.8, // Wide, highly legible line height
                          color: secondaryText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // VERIFICATION FOOTER
            Container(
              margin: const EdgeInsets.fromLTRB(0,16,0,0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: secondaryText.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: secondaryText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Medically Reviewed & Clinically Verified",
                      style: TextStyle(
                        fontFamily: kSansSerif,
                        fontSize: context.scale(10),
                        fontWeight: FontWeight.w600,
                        color: secondaryText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}