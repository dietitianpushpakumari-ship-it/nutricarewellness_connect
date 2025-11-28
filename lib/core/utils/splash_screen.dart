import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Animated Logo (Simple Fade/Scale effect via Hero or just Icon)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.1), // Soft Emerald
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.spa, // Leaf/Wellness Icon
                size: 80,
                color: Color(0xFF00BFA5), // Emerald Green
              ),
            ),
            const SizedBox(height: 24),

            // 2. Brand Name
            const Text(
              "NutriCare Wellness",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A), // Dark Grey
                letterSpacing: 1.2,
                fontFamily: 'Roboto', // Matches your theme
              ),
            ),

            const SizedBox(height: 12),

            // 3. Tagline
            Text(
              "Your Journey to Health",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 50),

            // 4. Loader
            const CircularProgressIndicator(
              color: Color(0xFF00BFA5),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}