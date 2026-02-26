import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _trackingAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));

    // Smooth fade in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.8, curve: Curves.easeOut)),
    );

    // Subtle scale up (camera push-in)
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic)),
    );

    // 🎯 The "Breath" Effect: Letters start squished and slowly slide apart
    _trackingAnimation = Tween<double>(begin: -2.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    // Background ambient illumination
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF0B0F19);
    const Color neonGreen = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. Centered Ambient Glow
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: neonGreen.withOpacity(_glowAnimation.value * 0.15),
                          blurRadius: 100,
                          spreadRadius: 20,
                        )
                      ]
                  ),
                ),
              );
            },
          ),

          // 2. The Text Layout
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0), // Safe margins
              child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 🎯 FittedBox ensures the 9 letters maximize screen width without breaking
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 56, // Massive baseline size
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: _trackingAnimation.value, // Animates the spacing!
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: "NUTRI",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    TextSpan(
                                      text: "CARE",
                                      style: TextStyle(
                                        color: neonGreen,
                                        shadows: [
                                          Shadow(
                                            color: neonGreen.withOpacity(_glowAnimation.value * 0.5),
                                            blurRadius: 15,
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Subtitle with matching tracking animation
                            Text(
                              "WELLNESS", // 🎯 Simplified to just "WELLNESS"
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade400,
                                // 🎯 Increased base spacing so it stretches nicely under NUTRICARE
                                letterSpacing: _trackingAnimation.value + 8.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
              ),
            ),
          ),
        ],
      ),
    );
  }
}