import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/layout_utils.dart'; // Adjust path if needed

// ==========================================
// 🚀 THE MODELS (Single Source of Truth)
// ==========================================
enum PulseState { workout, chat, nudge, calm, feed } // 🚀 Added feed state

class PulseAction {
  final PulseState state;
  final String title;
  final String subtitle;
  final String actionText;
  final IconData icon;
  final Color color;
  final bool isElapsed;
  final VoidCallback onAction;
  final Widget? customContent; // 🚀 ADDED: Allows us to inject the mini gallery!

  PulseAction({
    required this.state,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.icon,
    required this.color,
    this.isElapsed = false,
    required this.onAction,
    this.customContent,
  });
}

// ==========================================
// 1. THE ATMOSPHERIC CAROUSEL CARD
// ==========================================
class AtmosphericPulseCard extends StatefulWidget {
  final List<PulseAction> actions;

  const AtmosphericPulseCard({super.key, required this.actions});

  @override
  State<AtmosphericPulseCard> createState() => _AtmosphericPulseCardState();
}

class _AtmosphericPulseCardState extends State<AtmosphericPulseCard> with TickerProviderStateMixin {
  late AnimationController _fluidController;
  late AnimationController _pulseController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fluidController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AtmosphericPulseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.actions.length) {
      _selectedIndex = 0;
    }
  }

  @override
  void dispose() {
    _fluidController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final focusAction = widget.actions[_selectedIndex];

    return GestureDetector(
      onTap: focusAction.onAction,
      // 🚀 BULLETPROOF SWIPE LOGIC
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -300) {
          // Swiped Left -> Move Forward
          HapticFeedback.selectionClick();
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % widget.actions.length;
          });
        } else if (velocity > 300) {
          // Swiped Right -> Move Backward
          HapticFeedback.selectionClick();
          setState(() {
            _selectedIndex = (_selectedIndex - 1 + widget.actions.length) % widget.actions.length;
          });
        }
      },  child: Container(
        margin: EdgeInsets.symmetric(horizontal: context.scale(20)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.scale(32)),
          boxShadow: [
            BoxShadow(
              color: focusAction.color.withOpacity(isDark ? 0.2 : 0.1),
              blurRadius: 40, spreadRadius: 0, offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.scale(32)),
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: isDark ? const Color(0xFF0B0F19) : Colors.white)),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _fluidController,
                  builder: (context, child) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -50 + math.sin(_fluidController.value * 2 * math.pi) * 30,
                          left: -50 + math.cos(_fluidController.value * 2 * math.pi) * 40,
                          child: Transform.rotate(
                            angle: _fluidController.value * 2 * math.pi,
                            child: AnimatedContainer(duration: const Duration(milliseconds: 500), width: context.scale(250), height: context.scale(200), decoration: BoxDecoration(shape: BoxShape.circle, color: focusAction.color.withOpacity(0.6))),
                          ),
                        ),
                        Positioned(
                          bottom: -80 + math.cos(_fluidController.value * 2 * math.pi) * 20,
                          right: -30 + math.sin(_fluidController.value * 2 * math.pi) * 30,
                          child: AnimatedContainer(duration: const Duration(milliseconds: 500), width: context.scale(200), height: context.scale(250), decoration: BoxDecoration(shape: BoxShape.circle, color: focusAction.color.withOpacity(0.3))),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent))),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(context.scale(32)),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04), width: 1.0),
                  ),
                ),
              ),

              Container(
                constraints: BoxConstraints(minHeight: context.scale(200)),
                padding: EdgeInsets.all(context.scale(20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: context.scale(12), vertical: context.scale(6)),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(context.scale(20)),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              Icon(focusAction.state == PulseState.calm || focusAction.state == PulseState.feed ? Icons.auto_awesome : Icons.fiber_manual_record, size: context.scale(10), color: isDark ? Colors.white70 : Colors.black54),
                              SizedBox(width: context.scale(6)),
                              Text(
                                focusAction.state == PulseState.calm || focusAction.state == PulseState.feed ? "EXPLORE" : "LIVE PRIORITY",
                                style: TextStyle(fontFamily: 'Space Grotesk', fontSize: context.scale(10), fontWeight: FontWeight.w800, letterSpacing: 2.0, color: isDark ? Colors.white : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.scale(12)),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: SizedBox( // 🚀 THE FIX: Lock the height of this middle section!
                      key: ValueKey(focusAction.title),
                      height: context.scale(96), // 90px fits BOTH the gallery and the 2-line text perfectly
                      width: double.infinity,
                        child: SizedBox(
                          key: ValueKey(focusAction.title),
                          height: context.scale(96),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (focusAction.state == PulseState.feed) ...[
                                // 🎴 FEED LAYOUT
                                Text(
                                  focusAction.title,
                                  maxLines: 1, // 🚀 FORCE 1 LINE
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontSize: context.scale(18),
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black87,
                                      height: 1.1
                                  ),
                                ),
                                SizedBox(height: context.scale(8)), // Tighter gap
                                if (focusAction.customContent != null) focusAction.customContent!,
                              ] else ...[
                                // 📝 STANDARD LAYOUT
                                Text(
                                  focusAction.title,
                                  maxLines: 1, // 🚀 FORCE 1 LINE
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      fontSize: context.scale(22),
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black87,
                                      height: 1.1
                                  ),
                                ),
                                SizedBox(height: context.scale(4)),
                                Text(
                                  focusAction.subtitle,
                                  maxLines: 2, // 🚀 MAX 2 LINES
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: context.scale(13),
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white60 : Colors.black54
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                    ),
                  ),

                    SizedBox(height: context.scale(24)),
                    _buildOrbTimeline(context, widget.actions),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildOrbTimeline(BuildContext context, List<PulseAction> actions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox( // 🚀 Wrap in SizedBox to define a strict height
      height: context.scale(60),
      child: Stack(
          alignment: Alignment.centerLeft,
          children: [
      // Background Line
      Positioned(
      left: context.scale(16),
      right: context.scale(16),
      top: context.scale(15),
      child: Container(height: 2, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
    ),

    SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Row(
    mainAxisSize: MainAxisSize.min, // 🚀 FIX: Prevents Row from demanding infinite space
    crossAxisAlignment: CrossAxisAlignment.start,
    children: actions.asMap().entries.map((entry) {

                int index = entry.key;
                PulseAction action = entry.value;
                bool isSelected = index == _selectedIndex;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedIndex = index);
                  },
                  child: Padding(
                    padding: EdgeInsets.only(right: context.scale(28)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final double glowOpacity = action.isElapsed ? (0.2 + (_pulseController.value * 0.4)) : 0.0;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: context.scale(32), height: context.scale(32),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  // 🚀 THE FIX: If selected, fill it completely with the action's specific color
                                  color: isSelected ? action.color : (isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.5)),
                                  border: Border.all(
                                    // 🚀 THE FIX: Ensure border matches the new solid color
                                    color: isSelected ? action.color : (action.isElapsed ? action.color : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))),
                                    width: isSelected || action.isElapsed ? 2 : 1,
                                  ),
                                  // 🚀 THE FIX: Selected orbs get a permanent, beautiful colored shadow
                                  boxShadow: (isSelected || action.isElapsed) ? [BoxShadow(color: action.color.withOpacity(isSelected ? 0.4 : glowOpacity), blurRadius: 10, spreadRadius: 1)] : null,
                                ),
                                child: Icon(
                                  action.icon,
                                  size: context.scale(14),
                                  // 🚀 THE FIX: If selected, icon is always crisp White for contrast
                                  color: isSelected ? Colors.white : (action.isElapsed ? action.color : (isDark ? Colors.white54 : Colors.black54)),
                                ),
                              );
                            }
                        ),
                        SizedBox(height: context.scale(8)),
                        Text(
                          _getShortLabel(action.state),
                          style: TextStyle(
                            fontFamily: 'Inter', fontSize: context.scale(9), fontWeight: FontWeight.w800, letterSpacing: 1.0,
                            // 🚀 THE FIX: Make the text label adopt the color of the selected action
                            color: isSelected ? action.color : (isDark ? Colors.white30 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  String _getShortLabel(PulseState state) {
    switch (state) {
      case PulseState.workout: return "WORKOUT";
      case PulseState.chat: return "COACH";
      case PulseState.nudge: return "DUTY";
      case PulseState.feed: return "FEED"; // 🚀 Added feed label
      case PulseState.calm: return "ZEN";
    }
  }
}