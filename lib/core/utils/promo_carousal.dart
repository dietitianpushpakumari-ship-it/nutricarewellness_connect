import 'package:flutter/material.dart';

class PromoCarousel extends StatelessWidget {
  const PromoCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data - Replace with Firestore Stream later
    final List<Map<String, dynamic>> promos = [
      {"title": "🎉 50% Off Consultations", "sub": "Limited time offer", "color": Colors.purple},
      {"title": "🏆 You're in Top 10%", "sub": "Achievement Unlocked!", "color": Colors.amber},
      {"title": "🥗 New Keto Recipes", "sub": "Check the library", "color": Colors.green},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: promos.length,
        itemBuilder: (context, index) {
          final item = promos[index];
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [item['color'].shade400, item['color'].shade700],
                  begin: Alignment.topLeft, end: Alignment.bottomRight
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: item['color'].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(item['sub'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.white54),
              ],
            ),
          );
        },
      ),
    );
  }
}