import 'dart:ui'; // 🎯 NEW: Required for the frosted glass BackdropFilter
import 'package:flutter/material.dart';

class ModernBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ModernBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🎯 Extract glass color and border directly from the AppTheme
    final Color baseColor = theme.cardTheme.color ?? colorScheme.surface;
    Color borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.4);

    if (theme.cardTheme.shape is RoundedRectangleBorder) {
      borderColor = (theme.cardTheme.shape as RoundedRectangleBorder).side.color;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24), // Float off the bottom
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          // 🎯 Subtle glowing shadow, adjusted for light/dark mode
          BoxShadow(
            color: isDark
                ? colorScheme.primary.withOpacity(0.05)
                : colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 🎯 Frosted glass blur effect
          child: Container(
            decoration: BoxDecoration(
              color: baseColor, // Translucent glass fill
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: borderColor, width: 1.5), // Delicate glass rim
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent, // 🎯 Must be transparent to let glass show
                indicatorColor: colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1), // Glowing selection pill

                // Adaptive Text Styling
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary
                    );
                  }
                  return TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.6)
                  );
                }),

                // Adaptive Icon Styling
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: colorScheme.primary);
                  }
                  return IconThemeData(color: colorScheme.onSurface.withOpacity(0.5));
                }),
              ),
              child: NavigationBar(
                height: 65,
                elevation: 0,
                selectedIndex: currentIndex,
                onDestinationSelected: onTap,
                backgroundColor: Colors.transparent, // 🎯 Transparent to reveal glass
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.restaurant_menu_outlined),
                    selectedIcon: Icon(Icons.restaurant_menu_rounded),
                    label: 'Plan',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.directions_run_outlined),
                    selectedIcon: Icon(Icons.directions_run_rounded),
                    label: 'Move',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.self_improvement_outlined),
                    selectedIcon: Icon(Icons.self_improvement_rounded),
                    label: 'Wellness',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.rss_feed_rounded),
                    selectedIcon: Icon(Icons.rss_feed),
                    label: 'Feed',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.support_agent_outlined),
                    selectedIcon: Icon(Icons.support_agent_rounded),
                    label: 'Coach',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}