import 'dart:ui';
import 'package:flutter/material.dart';

const String kDisplayFont = 'Space Grotesk';

class ModernBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadChatCount;

  const ModernBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadChatCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 🚀 THE FIX: Reduced to 5 tabs (Discover removed)
    // This perfectly matches the 5 indices in ClientDashboardScreen widgetOptions
    final List<Map<String, dynamic>> tabs = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.restaurant_menu_rounded, 'label': 'Plan'},
      {'icon': Icons.directions_run_rounded, 'label': 'Activity'},
      {'icon': Icons.spa_rounded, 'label': 'Wellness'},
      {'icon': Icons.shield_rounded, 'label': 'Team', 'badge': unreadChatCount}, // Index 4
    ];

    return SafeArea(
      bottom: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 64,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2C).withOpacity(0.8) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(tabs.length, (index) {
                final bool isSelected = currentIndex == index;
                final tab = tabs[index];

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.all(isSelected ? 6 : 4),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                tab['icon'],
                                size: isSelected ? 22 : 20,
                                color: isSelected ? theme.colorScheme.primary : theme.hintColor.withOpacity(0.6),
                              ),
                            ),

                            if (tab['badge'] != null && tab['badge'] > 0)
                              Positioned(
                                top: -2,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                  child: Text(
                                    tab['badge'] > 9 ? '9+' : '${tab['badge']}',
                                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab['label'],
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontFamily: kDisplayFont,
                            fontSize: 10, // Increased slightly since there is more room with 5 tabs
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: 0.2,
                            color: isSelected ? theme.colorScheme.primary : theme.hintColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}