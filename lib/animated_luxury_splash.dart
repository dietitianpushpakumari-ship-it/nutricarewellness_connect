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
  late Animation<double> _fade;
  late Animation<double> _glowRadius;

  // 💎 MATCHING CLINICAL LUXURY PALETTE
  final Color bgLight = const Color(0xFFF8FAFC);
  final Color textDark = const Color(0xFF0F172A);
  final Color textMuted = const Color(0xFF64748B);
  final Color clinicalEmerald = const Color(0xFF059669);

  // 🚀 SYNCHRONIZATION FLAGS
  bool _animationDone = false;
  bool _hasRouted = false;

  @override
  void initState() {
    super.initState();

    // 🚀 Extended duration to 3.5 seconds for a lingering, premium feel
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));

    // 1. Fast Fade In (0 to 1 second)
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.25, curve: Curves.easeIn)),
    );

    // 2. Cinematic Breathing Glow (Swells up, then settles)
    _glowRadius = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 25.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 25.0, end: 8.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0)));

    _controller.forward();

    // 🚀 Wait 4 full seconds before allowing the router to push the next screen
    Timer(const Duration(milliseconds: 4000), () {
      _animationDone = true;
      if (mounted) _routeWhenReady(ref.read(authNotifierProvider));
    });
  }

  // 🚀 THE SMART ROUTER
  void _routeWhenReady(AuthState state) {
    if (_hasRouted || !_animationDone) return;

    if (state.initialCheckComplete) {
      _hasRouted = true;

      if (state.clientProfile != null) {
        ref.read(globalUserProvider.notifier).setUser(state.clientProfile!);
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1000), // Smooth 1-second crossfade
            pageBuilder: (context, animation, _) => ClientDashboardScreen(client: state.clientProfile!, showWelcomeSheet: false),
            transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1000),
            pageBuilder: (context, animation, _) => const ClientAuthScreen(),
            transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
      }
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
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.scale(32)),
                      // 🚀 THE STACK: Separates the crisp text from the glowing shadow
                      child: Stack(
                        children: [
                          // 💎 LAYER 1: The Glow (Transparent text, colored shadow)
                          RichText(
                            softWrap: false,
                            maxLines: 1,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: context.scale(42), // Slightly larger
                                fontWeight: FontWeight.w900,
                                letterSpacing: context.scale(2.5),
                                fontFamily: 'Space Grotesk',
                                color: Colors.transparent, // Hide the text, keep the shadow
                                shadows: [
                                  Shadow(
                                    color: clinicalEmerald.withOpacity(0.6),
                                    blurRadius: _glowRadius.value,
                                  )
                                ],
                              ),
                              children: const [
                                TextSpan(text: "NUTRI"),
                                TextSpan(text: "CARE"),
                              ],
                            ),
                          ),
                          // 💎 LAYER 2: The Crisp Foreground Text
                          RichText(
                            softWrap: false,
                            maxLines: 1,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: context.scale(42),
                                fontWeight: FontWeight.w900,
                                letterSpacing: context.scale(2.5),
                                fontFamily: 'Space Grotesk',
                              ),
                              children: [
                                TextSpan(text: "NUTRI", style: TextStyle(color: textDark)),
                                TextSpan(text: "CARE", style: TextStyle(color: clinicalEmerald)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.scale(8)),

                  // Subtitle (No glow, keeps it grounded)
                  Text(
                    "CLINICAL WELLNESS",
                    style: TextStyle(
                      fontSize: context.scale(11),
                      fontWeight: FontWeight.w800,
                      color: textMuted.withOpacity(0.8),
                      letterSpacing: context.scale(8.0), // Extra wide spacing for luxury feel
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}