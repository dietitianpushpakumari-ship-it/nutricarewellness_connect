import 'package:flutter/material.dart';
import 'package:pure_shift/core/utils/nudge_manager.dart'; // Import the manager

class VitalsNudgeBanner extends StatefulWidget {
  final VoidCallback onOpenVitals; // Pass your bottom sheet trigger here

  const VitalsNudgeBanner({super.key, required this.onOpenVitals});

  @override
  State<VitalsNudgeBanner> createState() => _VitalsNudgeBannerState();
}

class _VitalsNudgeBannerState extends State<VitalsNudgeBanner> {
  bool _isVisible = false;
  int? _daysOverdue; // 🚀 Tracks how many days they missed

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    final status = await NudgeManager.getNudgeStatus();
    if (mounted) {
      setState(() {
        _daysOverdue = status;
        _isVisible = status != null; // Show if it returned a number
      });
    }
  }

  void _dismiss() async {
    setState(() => _isVisible = false);
    await NudgeManager.dismissNudgeTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 🚀 DYNAMIC SMART TEXT
    final String titleText = _daysOverdue == -1
        ? "Set your baseline vitals"
        : "Time for a check-in?";

    final String bodyText = _daysOverdue == -1
        ? "You haven't logged your starting body vitals yet. Let's record them so we can track your progress!"
        : "It's been $_daysOverdue days since you last logged your vitals. Keeping track helps your dietitian tune your plan.";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2232) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.primary.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_weight_rounded, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titleText, // 🚀 Uses dynamic title
                  style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
              ),
              GestureDetector(
                onTap: _dismiss,
                child: Icon(Icons.close, size: 16, color: theme.hintColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            bodyText, // 🚀 Uses dynamic body text
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: theme.hintColor, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _dismiss,
                child: const Text("Skip for now", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                onPressed: () {
                  // 🚀 1. Trigger the Bottom Sheet FIRST
                  widget.onOpenVitals();

                  // 🚀 2. Wait a split second for the sheet to animate up, THEN hide the banner
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (mounted) setState(() => _isVisible = false);
                  });
                },
                child: Text(_daysOverdue == -1 ? "Log Now" : "Update Now", style: const TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          )
        ],
      ),
    );
  }
}