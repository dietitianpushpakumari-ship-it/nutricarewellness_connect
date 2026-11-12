import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pure_shift/new/healthcontent/health_content.dart'; // Point to your masterHealthTips

class DailyInsightAlert extends StatefulWidget {
  const DailyInsightAlert({super.key});

  @override
  State<DailyInsightAlert> createState() => _DailyInsightAlertState();
}

class _DailyInsightAlertState extends State<DailyInsightAlert> with SingleTickerProviderStateMixin {
  late HealthTip _todayTip;
  late AnimationController _glowController;
  bool _isRead = true; // Default to true so it doesn't flash before checking
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkIfReadToday();

    // Pick exactly one tip deterministically per day
    final random = math.Random(DateTime.now().day);
    final shuffled = List<HealthTip>.from(masterHealthTips)..shuffle(random);
    _todayTip = shuffled.first;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _checkIfReadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final String todayDate = DateTime.now().toIso8601String().split('T')[0];
    final String? lastReadDate = prefs.getString('last_insight_read_date');

    if (mounted) {
      setState(() {
        _isRead = (lastReadDate == todayDate);
        _isInitialized = true;
      });
    }
  }

  Future<void> _markAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final String todayDate = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('last_insight_read_date', todayDate);

    if (mounted) {
      setState(() => _isRead = true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If it's not initialized or already read, take up ZERO space.
    if (!_isInitialized || _isRead) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();
          // 1. Open the reader
          await _showHealthTipDetail(context, _todayTip);
          // 2. When they close it, trigger the vanish animation!
          _markAsRead();
        },
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowOpacity = 0.05 + (_glowController.value * 0.1);

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(color: primary.withOpacity(glowOpacity), blurRadius: 10, spreadRadius: 1)
                ],
              ),
              child: Row(
                children: [
                  // Little notification dot & Icon
                  Stack(
                    children: [
                      Icon(Icons.mark_email_unread_rounded, color: primary, size: 20),
                      Positioned(
                        right: 0, top: 0,
                        child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                      )
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "1 New Clinical Insight",
                          style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Tap to unlock today's truth",
                          style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_open_rounded, size: 16, color: theme.hintColor),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM SHEET READER (Includes Language Toggles)
  // ===========================================================================
  Future<void> _showHealthTipDetail(BuildContext context, HealthTip tip) async {
    String currentLang = 'en';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateSheet) {
              final titleText = tip.title[currentLang] ?? tip.title['en'] ?? "";
              final bodyText = tip.body[currentLang] ?? tip.body['en'] ?? "";

              return Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.paddingOf(context).bottom + 32),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF121826) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(tip.category.toUpperCase(), style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: colorScheme.primary))),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                          child: Row(
                            children: ['en', 'hi', 'or'].map((lang) {
                              bool isSelected = currentLang == lang;
                              return GestureDetector(
                                onTap: () { HapticFeedback.selectionClick(); setStateSheet(() => currentLang = lang); },
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isSelected ? colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Text(lang.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600, color: isSelected ? Colors.white : theme.hintColor))),
                              );
                            }).toList(),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(titleText, style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 22, fontWeight: FontWeight.w900, height: 1.2, color: colorScheme.onSurface)),
                    const SizedBox(height: 16),
                    ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45), child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Text(bodyText, style: TextStyle(fontFamily: 'Inter', fontSize: 15, height: 1.6, fontWeight: FontWeight.w500, color: theme.hintColor)))),
                  ],
                ),
              );
            }
        );
      },
    );
  }
}