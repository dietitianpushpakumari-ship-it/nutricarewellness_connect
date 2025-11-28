import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_registry.dart';
import 'package:path_provider/path_provider.dart';

class UnifiedInsightsCarousel extends StatefulWidget {
  final String clientId;
  final VoidCallback onFeatureTap;

  const UnifiedInsightsCarousel({super.key, required this.clientId, required this.onFeatureTap});

  @override
  State<UnifiedInsightsCarousel> createState() => _UnifiedInsightsCarouselState();
}

class _UnifiedInsightsCarouselState extends State<UnifiedInsightsCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  late Future<List<Widget>> _slidesFuture;

  @override
  void initState() {
    super.initState();
    _slidesFuture = _generateSlides();
  }

  Future<List<Widget>> _generateSlides() async {
    List<Widget> slides = [];

    // 1. FEATURE SPOTLIGHT (Discovery)
    final int dayOfYear = int.parse(DateFormat("D").format(DateTime.now()));
    final int featureIndex = dayOfYear % WellnessRegistry.allTools.length;
    final WellnessTool tool = WellnessRegistry.allTools[featureIndex];

    slides.add(_buildFeatureSlide(tool));

    // 2. DAILY WISDOM (Content)
    try {
      final query = await FirebaseFirestore.instance
          .collection('wellness_library')
          .limit(10)
          .get();

      if (query.docs.isNotEmpty) {
        final int wisdomIndex = dayOfYear % query.docs.length;
        final data = query.docs[wisdomIndex].data();
        slides.insert(0, _buildWisdomSlide(data));
      }
    } catch (e) {
      slides.insert(0, _buildWisdomSlide({
        'type': 'TIP',
        'title': 'Stay Consistent',
        'body': 'Small daily habits compound into massive results over time.'
      }));
    }

    return slides;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Widget>>(
      future: _slidesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 140,
          child: PageView(
            controller: _controller,
            padEnds: false,
            children: snapshot.data!.map((w) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: w,
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _buildWisdomSlide(Map<String, dynamic> data) {
    final type = data['type']?.toString().toUpperCase() ?? 'TIP';
    final title = data['title'] ?? '';
    final body = data['body'] ?? '';

    // 🎯 FIX: Changed type from 'Color' to 'MaterialColor' to allow .shade access
    MaterialColor color = Colors.teal;
    IconData icon = Icons.lightbulb;

    if (type == 'MYTH') { color = Colors.purple; icon = Icons.help_outline; }
    else if (type == 'WARNING') { color = Colors.orange; icon = Icons.warning_amber_rounded; }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // 🎯 Now .shade700 is valid
        gradient: LinearGradient(
            colors: [color.shade700, color.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                  child: Text("DAILY $type", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: Colors.white.withOpacity(0.2), size: 60),
        ],
      ),
    );
  }

  Widget _buildFeatureSlide(WellnessTool tool) {
    return GestureDetector(
      onTap: widget.onFeatureTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.shade50),
          boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: tool.color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(tool.icon, color: tool.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Try Something New", style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(tool.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(tool.subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}