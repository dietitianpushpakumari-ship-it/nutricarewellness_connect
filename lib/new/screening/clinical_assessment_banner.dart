import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClinicalAssessmentBanner extends StatelessWidget {
  final VoidCallback onTap;

  const ClinicalAssessmentBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const Color clinicalSage = Color(0xFF10B981);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [clinicalSage.withOpacity(0.15), clinicalSage.withOpacity(0.05)]
                : [clinicalSage.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: clinicalSage.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: clinicalSage.withOpacity(isDark ? 0.1 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: clinicalSage.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.troubleshoot_rounded, color: clinicalSage, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Free Clinical Audit",
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: clinicalSage),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Check Your Health Score",
                    style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Identify root causes in 2 mins",
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: clinicalSage, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
            )
          ],
        ),
      ),
    );
  }
}