import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ShrugTestPage extends StatefulWidget {
  const ShrugTestPage({super.key});

  @override
  State<ShrugTestPage> createState() => _ShrugTestPageState();
}

class _ShrugTestPageState extends State<ShrugTestPage> with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animations/shrug.json', // 🎯 Update path
          controller: _controller,
          width: 300,
          height: 300,
          onLoaded: (composition) {
            _controller
              ..duration = const Duration(milliseconds: 1000)
              ..repeat();
          },
          delegates: LottieDelegates(
            values: [
              // 🎯 1. LOCK THE BODY
       //       ValueDelegate.transformPosition(
         //       const ['Pre-comp 3', '**'],
           //     value: const Offset(360, 416),
             // ),

              // ==========================================
              // 🎯 2. LEFT ARM (Move all 3 parts together)
              // ==========================================
              ValueDelegate.transformPosition(
                const ['Bắp tay trái Outlines', '**'], // Left Upper Arm
                callback: (frameInfo) => Offset(0, -35 * _controller.value),
              ),
              ValueDelegate.transformPosition(
                const ['Cẳng tay trái Outlines', '**'], // Left Forearm
                callback: (frameInfo) => Offset(0, -35 * _controller.value),
              ),
              ValueDelegate.transformPosition(
                const ['Bàn tay trái Outlines', '**'], // Left Hand
                callback: (frameInfo) => Offset(0, -35 * _controller.value),
              ),

              // ==========================================
              // 🎯 3. RIGHT ARM (Move all 3 parts together)
              // ==========================================
              ValueDelegate.transformPosition(
                const ['Bắp tay phải Outlines', '**'], // Right Upper Arm
                callback: (frameInfo) => Offset(0, -35 * _controller.value),
              ),
              ValueDelegate.transformPosition(
                const ['Cẳng tay phải Outlines', '**'], // Right Forearm
                callback: (frameInfo) => Offset(0, -35 * _controller.value),
              ),
              ValueDelegate.transformPosition(
                const ['Bàn tay phải Outlines', '**'], // Right Hand
                callback: (frameInfo) => Offset(0, -35 * _controller.value),
              ),

              // 🎯 4. HIDE WEIGHTS
              ValueDelegate.opacity(
                const ['Shape Layer 10', '**'],
                value: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}