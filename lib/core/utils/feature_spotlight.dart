import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_registry.dart';


class FeatureSpotlight extends StatelessWidget {
  final VoidCallback onExplore; // Callback to navigate to Wellness Tab or tool

  const FeatureSpotlight({super.key, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    // 🎯 Logic: Pick a tool based on the Day of Year
    // This ensures a different tip every day automatically.
    final int dayOfYear = int.parse(DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays.toString());
    final int index = dayOfYear % WellnessRegistry.allTools.length;
    final WellnessTool tool = WellnessRegistry.allTools[index];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo.shade900, Colors.indigo.shade600]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onExplore,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(tool.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text("DISCOVER FEATURE", style: TextStyle(color: Colors.amber.shade200, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Try ${tool.title}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(tool.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Text("Open", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}