import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/app_theme.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Holistic Tracking",
      "subtitle": "Water, Steps, Sleep & Breath.\nAll in one smart grid.",
      "color": Colors.blue,
    },
    {
      "title": "Spiritual Sanctuary",
      "subtitle": "Mantra Japa, Meditation & \nDaily Wisdom for your soul.",
      "color": Colors.orange,
    },
    {
      "title": "Expert Guidance",
      "subtitle": "Chat with your Dietitian.\nGet personalized meal plans.",
      "color": Colors.indigo,
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (mounted) {
      // Navigate to Auth Screen (Replace current view)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientAuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // 1. SKIP BUTTON
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text("Skip", style: TextStyle(color: Colors.grey)),
              ),
            ),

            // 2. CAROUSEL CONTENT
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPageContent(index);
                },
              ),
            ),

            // 3. TEXT & CONTROLS
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Title & Subtitle
                    Text(
                      _pages[_currentIndex]['title'],
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _pages[_currentIndex]['color'],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _pages[_currentIndex]['subtitle'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                    ),

                    const Spacer(),

                    // Indicators & Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dots
                        Row(
                          children: List.generate(
                            _pages.length,
                                (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              height: 8,
                              width: _currentIndex == index ? 24 : 8,
                              decoration: BoxDecoration(
                                color: _currentIndex == index
                                    ? _pages[index]['color']
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                        // FAB
                        FloatingActionButton(
                          onPressed: () {
                            if (_currentIndex == _pages.length - 1) {
                              _completeOnboarding();
                            } else {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          backgroundColor: _pages[_currentIndex]['color'],
                          child: Icon(
                            _currentIndex == _pages.length - 1 ? Icons.check : Icons.arrow_forward,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 BENTO VISUALIZER FOR EACH SLIDE
  Widget _buildPageContent(int index) {
    switch (index) {
      case 0: // TRACKING (2x2 Grid)
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  // 🎯 INCREASED HEIGHTS to prevent overflow
                  Expanded(child: _buildMockCard(Icons.water_drop, "Hydration", "1.5L", Colors.blue, height: 170)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMockCard(Icons.directions_walk, "Steps", "4,500", Colors.orange, height: 170)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMockCard(Icons.bedtime, "Sleep", "7h 30m", Colors.indigo, height: 150)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMockCard(Icons.self_improvement, "Breathe", "Relax", Colors.teal, height: 150)),
                ],
              ),
            ],
          ),
        );

      case 1: // SPIRITUAL (Hero Card + Tools)
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMockCard(Icons.spa, "Mantra Japa", "108 Counts\nOm Namah Shivaya", Colors.orange, height: 190, isHero: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMockCard(Icons.auto_stories, "Geeta Wisdom", "Chapter 2", Colors.amber, height: 150)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMockCard(Icons.music_note, "Sleep Sounds", "Rain & Fire", Colors.deepPurple, height: 150)),
                ],
              ),
            ],
          ),
        );

      case 2: // COACH (Profile + Package)
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMockCard(Icons.support_agent, "Your Dietitian", "Dr. Anjali\nSenior Nutritionist", Colors.indigo, height: 160),
              const SizedBox(height: 16),
              _buildMockCard(Icons.workspace_premium, "Active Plan", "Weight Loss Pro\nExpires in 24 Days", Colors.green, height: 160, isHero: true),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // 🎯 Helper to create consistent "Bento" style mock cards
  Widget _buildMockCard(IconData icon, String title, String subtitle, Color color, {required double height, bool isHero = false}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16), // 🎯 Reduced padding to 16
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isHero ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),

          // 🎯 Wrap text in Flexible to handle overflow gracefully
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}