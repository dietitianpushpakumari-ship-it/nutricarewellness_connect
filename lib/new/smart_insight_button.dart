import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartInsightButton extends StatefulWidget {
  final VoidCallback onOpenInsight;

  const SmartInsightButton({super.key, required this.onOpenInsight});

  @override
  State<SmartInsightButton> createState() => _SmartInsightButtonState();
}

class _SmartInsightButtonState extends State<SmartInsightButton> with SingleTickerProviderStateMixin {
  bool _isRead = true;
  late AnimationController _glowController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkIfReadToday();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
    if (!_isInitialized) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;

    // 🚀 We use a Stack with Clip.none so the tooltip floats OUTSIDE the button's bounds
    // This guarantees 0 layout shift for the rest of your header icons.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 1. THE FIXED CIRCULAR BUTTON (Never changes size)
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onOpenInsight();
            if (!_isRead) _markAsRead();
          },
          child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final double pulse = _glowController.value;

                return Container(
                  padding: const EdgeInsets.all(6), // Matches your theme/profile icons exactly
                  decoration: BoxDecoration(
                    color: _isRead ? primary.withOpacity(0.1) : primary.withOpacity(0.1 + (pulse * 0.15)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRead ? Colors.transparent : primary.withOpacity(0.4 + (pulse * 0.4)),
                      width: _isRead ? 0 : 1.5,
                    ),
                    boxShadow: _isRead ? [] : [
                      BoxShadow(color: primary.withOpacity(0.2 * pulse), blurRadius: 10 * pulse, spreadRadius: pulse)
                    ],
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: primary,
                    size: 18,
                    shadows: _isRead ? [] : [Shadow(color: primary, blurRadius: 10 * pulse)],
                  ),
                );
              }
          ),
        ),

        // 2. THE RED NOTIFICATION DOT (Top Right)
        if (!_isRead)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
              ),
            ),
          ),

        // 3. THE FLOATING GLOWING TOOLTIP (Bottom)
        if (!_isRead)
          Positioned(
            top: 38, // 🚀 Pushes the tooltip to float directly below the icon
            child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  final double pulse = _glowController.value;
                  return IgnorePointer( // Prevents the tooltip from blocking scrolls/touches
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: primary.withOpacity(0.3 + (pulse * 0.4)),
                                blurRadius: 8 + (pulse * 4),
                                spreadRadius: 1,
                                offset: const Offset(0, 4)
                            )
                          ]
                      ),
                      child: const Text(
                        "Reveal",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                }
            ),
          ),
      ],
    );
  }
}