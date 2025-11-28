import 'package:flutter/material.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class DailyVitalsCard extends StatelessWidget {
  final ClientLogModel? dailyLog;
  final VoidCallback onTap;

  const DailyVitalsCard({
    super.key,
    required this.dailyLog,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🎯 LOGIC: Determine what to show based on what was logged
    String value = "Log Now";
    String label = "Vitals";
    bool isLogged = false;

    if (dailyLog != null) {
      if ((dailyLog!.weightKg ?? 0) > 0) {
        value = "${dailyLog!.weightKg} kg";
        label = "Weight";
        isLogged = true;
      } else if ((dailyLog!.fbsMgDl ?? 0) > 0) {
        value = "${dailyLog!.fbsMgDl} mg/dL";
        label = "Sugar";
        isLogged = true;
      } else if (dailyLog!.bloodPressureSystolic != null) {
        value = "${dailyLog!.bloodPressureSystolic}/${dailyLog!.bloodPressureDiastolic}";
        label = "BP";
        isLogged = true;
      }
    }

    final Color themeColor = isLogged ? Colors.redAccent : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130, // Matches other rail cards
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
          ],
          border: Border.all(color: isLogged ? Colors.redAccent.withOpacity(0.3) : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.monitor_heart_outlined, color: themeColor, size: 20),
                if (isLogged)
                  Icon(Icons.check_circle, color: Colors.redAccent, size: 16),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                    value,
                    style: TextStyle(fontSize: 11, color: isLogged ? Colors.black87 : Colors.grey, fontWeight: FontWeight.w500)
                ),
              ],
            ),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isLogged ? 1.0 : 0.0,
                minHeight: 4,
                backgroundColor: Colors.red.shade50,
                valueColor: const AlwaysStoppedAnimation(Colors.redAccent),
              ),
            )
          ],
        ),
      ),
    );
  }
}