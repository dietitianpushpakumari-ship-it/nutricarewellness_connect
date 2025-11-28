import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class DailyWisdomCard extends ConsumerStatefulWidget {
  final String clientId;
  final bool compactMode; // 🎯 New Flag

  const DailyWisdomCard({super.key, required this.clientId, this.compactMode = false});

  @override
  ConsumerState<DailyWisdomCard> createState() => _DailyWisdomCardState();
}

class _DailyWisdomCardState extends ConsumerState<DailyWisdomCard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  late Future<List<Map<String, dynamic>>> _contentFuture;

  @override
  void initState() {
    super.initState();
    final List<String> userTags = ['general', 'weight_loss', 'diabetes'];
    _contentFuture = _getDailyContent(userTags);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        final items = snapshot.data!;

        // 🎯 1. COMPACT MODE (For Home Screen Carousel)
        // Just return the FIRST item as a static widget. No internal PageView.
        if (widget.compactMode) {
          return _buildInsightCard(context, items.first);
        }

        // 2. FULL MODE (Original)
        return Column(
          children: [
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                itemCount: items.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) => _buildInsightCard(context, items[index]),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: _currentIndex == index ? 16 : 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInsightCard(BuildContext context, Map<String, dynamic> data) {
    final type = data['type']?.toString().toUpperCase() ?? 'TIP';
    final title = data['title'] ?? '';
    final body = data['body'] ?? '';

    Color color;
    IconData icon;

    if (type == 'MYTH') { color = Colors.purple; icon = Icons.help_outline; }
    else if (type == 'FACT') { color = Colors.blue; icon = Icons.lightbulb_outline; }
    else if (type == 'WARNING') { color = Colors.orange; icon = Icons.warning_amber_rounded; }
    else { color = Colors.teal; icon = Icons.spa; }

    return Container(
      // 🎯 Removed horizontal margin to fit better in carousel
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(type, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const Spacer(),
                    const Icon(Icons.share, color: Colors.white54, size: 18),
                  ],
                ),
                const Spacer(),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2)),
                const SizedBox(height: 6),
                Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... (Keep _getDailyContent and _fetchFromFirestore exactly as they are)
  Future<List<Map<String, dynamic>>> _getDailyContent(List<String> tags) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/daily_wisdom_cache.json');
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          final Map<String, dynamic> cache = jsonDecode(content);
          if (cache['date'] == todayDate && (cache['items'] as List).isNotEmpty) {
            return List<Map<String, dynamic>>.from(cache['items']);
          }
        } catch (e) {}
      }

      final fetchedItems = await _fetchFromFirestore(tags);

      if (fetchedItems.isNotEmpty) {
        final cacheData = {'date': todayDate, 'items': fetchedItems};
        await file.writeAsString(jsonEncode(cacheData), flush: true);
      }
      return fetchedItems;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFromFirestore(List<String> tags) async {
    final now = DateTime.now();
    final daySeed = int.parse(DateFormat("D").format(now));

    final query = await FirebaseFirestore.instance
        .collection('wellness_library')
        .where('tags', arrayContainsAny: tags)
        .limit(20)
        .get();

    var docs = query.docs;

    if (docs.isEmpty) {
      final fallback = await FirebaseFirestore.instance
          .collection('wellness_library')
          .where('tags', arrayContains: 'general')
          .limit(20)
          .get();
      docs = fallback.docs;
    }

    if (docs.isEmpty) return [];

    List<Map<String, dynamic>> dailySelection = [];
    int count = docs.length;
    int takeCount = count < 5 ? count : 5;

    for (int i = 0; i < takeCount; i++) {
      int index = (daySeed + i) % count;

      // 🎯 CRITICAL FIX: Convert Firestore Data to JSON-safe Map
      final data = docs[index].data();
      final safeMap = <String, dynamic>{
        'title': data['title'] ?? '',
        'body': data['body'] ?? '',
        'type': data['type'] ?? 'TIP',
        // Do NOT include Timestamps or complex objects here
      };

      dailySelection.add(safeMap);
    }

    return dailySelection;
  }

}