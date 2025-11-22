import 'dart:ui';
import 'package:flutter/material.dart';

class CustomGradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool isTransparent; // Option to make it fully invisible

  const CustomGradientAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.isTransparent = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      title: title,
      centerTitle: false, // Align left for a more modern feel
      actions: actions,
      leading: leading,
      bottom: bottom,
      elevation: 0, // Flat
      backgroundColor: Colors.transparent, // Let the glass layer handle color

      // 🎯 Text Styling: Sapphire Blue (Theme Secondary)
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: colorScheme.secondary, // Dark Blue
        letterSpacing: 0.5,
      ),

      // 🎯 Icon Styling: Emerald Green (Theme Primary)
      iconTheme: IconThemeData(color: colorScheme.primary),
      actionsIconTheme: IconThemeData(color: colorScheme.primary),

      // 🎯 The "Frosted Glass" Background
      flexibleSpace: isTransparent
          ? null
          : ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Stronger blur
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85), // Clean White tint
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200, // Subtle separator
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}