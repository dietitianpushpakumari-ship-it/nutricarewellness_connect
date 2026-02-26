import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/new/login/client_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentIndex = 0;
  late AnimationController _scanController;

  // 🎯 Locked Dark Palette
  final Color bgDark = const Color(0xFF0B0F19);
  final Color neonGreen = const Color(0xFF00E676);
  final Color neonCyan = const Color(0xFF00E5FF);
  final Color neonAmber = const Color(0xFFFFC400);
  final Color neonPurple = const Color(0xFFD500F9);

  @override
  void initState() {
    super.initState();
    // Controls the glowing radar scan on Screen 3
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ClientAuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Ambient Glow that changes color based on the screen
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            top: _currentIndex == 4 ? -50 : -100,
            right: _currentIndex == 2 ? 100 : -50,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 300, height: 300,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getAmbientColor().withOpacity(0.1),
                    boxShadow: [BoxShadow(color: _getAmbientColor().withOpacity(0.15), blurRadius: 100)]
                )
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(onPressed: _completeOnboarding, child: Text("SKIP", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                ),

                // 🎯 The Visual Dashboard
                Expanded(
                  flex: 55,
                  child: PageView(
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentIndex = index),
                    children: [
                      _buildNutritionVisual(),
                      _buildVitalsVisual(),
                      _buildAssessmentVisual(), // NEW: Screen 3
                      _buildZenVisual(),
                      _buildCareTribeVisual(),  // NEW: Screen 5
                    ],
                  ),
                ),

                // 🎯 Minimal Text & Controls
                Expanded(
                  flex: 45,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Spacer(),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _getTitle(),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 🎯 FIX: Removed Flexible, maxLines, and overflow.
                        // The text will now wrap naturally and take exactly as much space as it needs.
                        Text(
                          _getSubtitle(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade400, height: 1.4),
                        ),

                        const Spacer(flex: 2),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: List.generate(5, (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 8),
                                height: 6, width: _currentIndex == index ? 24 : 6,
                                decoration: BoxDecoration(color: _currentIndex == index ? neonGreen : Colors.grey.shade800, borderRadius: BorderRadius.circular(3)),
                              )),
                            ),
                            FloatingActionButton(
                              backgroundColor: neonGreen,
                              foregroundColor: bgDark,
                              elevation: 10,
                              onPressed: () {
                                if (_currentIndex == 4) _completeOnboarding();
                                else _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                              },
                              child: Icon(_currentIndex == 4 ? Icons.check_rounded : Icons.arrow_forward_ios_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TEXT LOGIC ---
  String _getTitle() {
    switch (_currentIndex) {
      case 0: return "Precision Nutrition";
      case 1: return "Clinical Vitals";
      case 2: return "Smart Assessments";
      case 3: return "Somatic Recovery";
      case 4: return "Direct Clinic Access";
      default: return "";
    }
  }

  String _getSubtitle() {
    switch (_currentIndex) {
      case 0: return "Macro and meal tracking tailored directly to your clinical bloodwork.";
      case 1: return "Monitor your daily sleep debt, hydration goals, and physical activity.";
      case 2: return "Advanced clinical calculators to screen and track your holistic progress.";
      case 3: return "Regulate your nervous system with ancient wisdom, EMDR, and Vagus resets.";
      case 4: return "24/7 priority chat and secure live video consults with your dietitian.";
      default: return "";
    }
  }

  Color _getAmbientColor() {
    switch (_currentIndex) {
      case 0: return neonGreen;
      case 1: return neonCyan;
      case 2: return neonPurple;
      case 3: return neonAmber;
      case 4: return neonGreen;
      default: return neonCyan;
    }
  }

  // --- HI-TECH VISUAL WIDGETS ---

  Widget _buildNutritionVisual() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 220, height: 220, child: CircularProgressIndicator(value: 0.8, strokeWidth: 12, color: neonGreen, backgroundColor: Colors.white.withOpacity(0.05), strokeCap: StrokeCap.round)),
              SizedBox(width: 170, height: 170, child: CircularProgressIndicator(value: 0.65, strokeWidth: 12, color: neonCyan, backgroundColor: Colors.white.withOpacity(0.05), strokeCap: StrokeCap.round)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 4),
                  const Text("1,840", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("KCAL", style: TextStyle(fontSize: 12, color: neonGreen, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalsVisual() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.monitor_heart_rounded, color: Colors.redAccent),
                    const SizedBox(width: 80),
                    Text("BPM", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("72", style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(width: 40, height: 2, color: neonCyan.withOpacity(0.5)),
                    Container(width: 10, height: 20, color: neonCyan),
                    Container(width: 10, height: 40, color: neonCyan),
                    Container(width: 10, height: 10, color: neonCyan),
                    Container(width: 40, height: 2, color: neonCyan.withOpacity(0.5)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎯 NEW: Clinical Assessment Radar
  Widget _buildAssessmentVisual() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200, height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: neonPurple.withOpacity(0.3), width: 2)),
              ),
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: neonPurple.withOpacity(0.1), width: 1)),
              ),
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return Container(
                    width: 200, height: _scanController.value * 200,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, neonPurple.withOpacity(0.4)],
                        ),
                        border: Border(bottom: BorderSide(color: neonPurple, width: 2))
                    ),
                  );
                },
              ),
              const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZenVisual() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [neonAmber.withOpacity(0.5), bgDark], stops: const [0.2, 1.0]),
              boxShadow: [BoxShadow(color: neonAmber.withOpacity(0.2), blurRadius: 50, spreadRadius: 20)],
            ),
            child: const Center(child: Icon(Icons.waves_rounded, size: 60, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  // 🎯 NEW: Care Tribe / Live Consult Node
  Widget _buildCareTribeVisual() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.05), width: 1))),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNode(Icons.person_rounded, Colors.grey.shade400),
                  Container(width: 40, height: 2, color: neonGreen.withOpacity(0.5)),
                  _buildNode(Icons.chat_bubble_rounded, neonGreen, isCenter: true),
                  Container(width: 40, height: 2, color: neonGreen.withOpacity(0.5)),
                  _buildNode(Icons.video_camera_front_rounded, neonCyan),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(IconData icon, Color color, {bool isCenter = false}) {
    return Container(
      padding: EdgeInsets.all(isCenter ? 24 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: isCenter ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20)] : [],
      ),
      child: Icon(icon, color: color, size: isCenter ? 32 : 24),
    );
  }
}