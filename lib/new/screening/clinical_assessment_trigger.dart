import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClinicalAssessmentTrigger extends StatelessWidget {
  final VoidCallback onTap;

  const ClinicalAssessmentTrigger({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const Color clinicalSage = Color(0xFF10B981);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : clinicalSage.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : clinicalSage.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.troubleshoot_rounded, color: clinicalSage, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Clinical Health Audit",
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Reassess your metabolic score",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: theme.hintColor.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }
}