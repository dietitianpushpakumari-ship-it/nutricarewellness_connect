import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_shift/new/login/client_auth_screen.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/dashboard/client_dashboard_main_screen.dart';
import '../../features/auth/auth_provider.dart';
import 'package:pure_shift/features/dietplan/PRESENTATION/providers/global_user_provider.dart';

class LuxurySplashScreen extends ConsumerStatefulWidget {
  const LuxurySplashScreen({super.key});

  @override
  ConsumerState<LuxurySplashScreen> createState() => _LuxurySplashScreenState();
}

class _LuxurySplashScreenState extends ConsumerState<LuxurySplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeText;
  late Animation<double> _stageLightIntensity;

  // 💎 MATCHING CLINICAL LUXURY PALETTE
  final Color bgLight = const Color(0xFFF8FAFC);
  final Color textDark = const Color(0xFF0F172A);
  final Color clinicalEmerald = const Color(0xFF059669);

  // 🚀 SYNCHRONIZATION FLAGS
  bool _animationDone = false;
  bool _hasRouted = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));

    // 1. Crisp Text Fade
    _fadeText = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    // 2. The Stage Light (Animates from small/intense to wide/soft)
    _stageLightIntensity = Tween<double>(begin: 0.1, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOutQuad)),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 4000), () {
      _animationDone = true;
      if (mounted) _routeWhenReady(ref.read(authNotifierProvider));
    });
  }

  void _routeWhenReady(AuthState state) {
    if (_hasRouted || !_animationDone || !state.initialCheckComplete) return;

    _hasRouted = true;

    Widget targetScreen;
    if (state.currentUser != null && state.clientProfile != null) {
      ref.read(globalUserProvider.notifier).setUser(state.clientProfile!);
      targetScreen = ClientDashboardScreen(client: state.clientProfile!, showWelcomeSheet: false);
    } else {
      targetScreen = const ClientAuthScreen();
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (context, animation, _) => targetScreen,
          transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
        ),
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      _routeWhenReady(next);
    });

    return Scaffold(
      backgroundColor: bgLight,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // 🔦 STAGE LIGHT (Background Radial Gradient)
              Positioned(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: _stageLightIntensity.value,
                      colors: [
                        clinicalEmerald.withOpacity(0.08),
                        clinicalEmerald.withOpacity(0.02),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // 💎 CRISP FOREGROUND TEXT
              Center(
                child: FadeTransition(
                  opacity: _fadeText,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // MAIN LOGO
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.scale(32)),
                          child: RichText(
                            softWrap: false,
                            maxLines: 1,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: context.scale(42),
                                fontWeight: FontWeight.w900,
                                letterSpacing: context.scale(3.0),
                                fontFamily: 'Space Grotesk',
                              ),
                              children: [
                                TextSpan(text: "NUTRI", style: TextStyle(color: textDark)),
                                TextSpan(text: "CARE", style: TextStyle(color: clinicalEmerald)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: context.scale(12)),

                      // 🚀 UPDATED SUBTITLE
                      Text(
                        "NUTRICARE WELLNESS",
                        style: TextStyle(
                          fontSize: context.scale(13), // Tuned for the new length
                          fontWeight: FontWeight.w800,
                          color: textDark.withOpacity(0.4),
                          letterSpacing: context.scale(4.0), // Tuned to align perfectly under the logo
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}