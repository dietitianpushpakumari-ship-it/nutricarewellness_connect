import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'layout_utils.dart';

class DynamicChatBar extends StatefulWidget {
  final int unreadCount;
  final String? latestMessage;
  final VoidCallback onTap;

  const DynamicChatBar({
    super.key,
    required this.onTap,
    this.unreadCount = 0,
    this.latestMessage
  });

  @override
  State<DynamicChatBar> createState() => _DynamicChatBarState();
}

class _DynamicChatBarState extends State<DynamicChatBar> {
  Timer? _flipTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(DynamicChatBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount == 0 && oldWidget.unreadCount > 0) {
      setState(() => _currentIndex = 0);
    }
  }

  void _startTimer() {
    _flipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && widget.unreadCount > 0) {
        setState(() => _currentIndex = (_currentIndex + 1) % 2);
      }
    });
  }

  @override
  void dispose() {
    _flipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bool hasUnread = widget.unreadCount > 0;

    final Color glowColor = colorScheme.primary.withOpacity(0.6);
    const double glowRadius = 12.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: context.scale(60),
        padding: EdgeInsets.symmetric(horizontal: context.scale(20)),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(context.scale(18)),
          border: Border.all(
            color: hasUnread ? colorScheme.primary.withOpacity(0.6) : theme.dividerColor.withOpacity(0.1),
            width: hasUnread ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.chat_bubble_rounded,
                  color: hasUnread ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.4),
                  size: context.scale(24),
                ),
                if (hasUnread)
                  Positioned(
                    top: -4, right: -4,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: context.scale(12), height: context.scale(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4757),
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, width: 2),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            SizedBox(width: context.scale(14)),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Align(
                  key: ValueKey(_currentIndex),
                  alignment: Alignment.centerLeft,
                  child: hasUnread && _currentIndex == 1
                      ? RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "${widget.unreadCount} New: ",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colorScheme.primary,
                            fontSize: context.scale(15),
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: glowColor, blurRadius: glowRadius)],
                          ),
                        ),
                        TextSpan(
                          text: widget.latestMessage ?? "Message from coach",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colorScheme.onSurface,
                            fontSize: context.scale(14),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                      : Text(
                    "Chat with Coach",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.scale(16),
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(width: context.scale(8)),

            Container(
              padding: EdgeInsets.all(context.scale(6)),
              decoration: BoxDecoration(color: colorScheme.onSurface.withOpacity(0.03), shape: BoxShape.circle),
              child: Icon(Icons.chevron_right_rounded, size: context.scale(20), color: colorScheme.onSurface.withOpacity(0.3)),
            ),
          ],
        ),
      ),
    );
  }
}