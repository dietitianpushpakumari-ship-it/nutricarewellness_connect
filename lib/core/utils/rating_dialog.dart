import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/rating_service.dart';
import 'package:url_launcher/url_launcher.dart';


class RatingDialog extends StatelessWidget {
  const RatingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text("Enjoying NutriCare?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text("Your reviews help us help more people stay healthy!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // 🌟 Love it -> Google/Store
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.star, color: Colors.white),
                label: const Text("Yes, I love it!"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  Navigator.pop(context);
                  _showPlatformSelection(context);
                  RatingService().markAsAsked(rated: true); // Stop asking
                },
              ),
            ),
            const SizedBox(height: 10),

            // 👎 Improvement -> Internal Feedback
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Navigate to Feedback Form or Chat
                  RatingService().markAsAsked(rated: true); // Don't annoy them with ratings if they are unhappy
                },
                child: const Text("I have feedback"),
              ),
            ),
            const SizedBox(height: 10),

            // ❌ Later
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                RatingService().markAsAsked(rated: false); // Ask again later
              },
              child: const Text("Not now", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlatformSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Where would you like to rate us?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text("Google Maps"),
              onTap: () => _launch("https://g.page/r/YOUR_MAPS_LINK/review"),
            ),
            ListTile(
              leading: const Icon(Icons.shop, color: Colors.green),
              title: const Text("Play Store"),
              onTap: () => _launch("https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
  }
}