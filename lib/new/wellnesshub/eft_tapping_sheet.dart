import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class EftTappingSheet extends StatefulWidget {
  const EftTappingSheet({super.key});
  @override
  State<EftTappingSheet> createState() => _EftTappingSheetState();
}

class _EftTappingSheetState extends State<EftTappingSheet> with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final _audio = WellnessAudioService();
  late AnimationController _pulseController;

  final List<Map<String, String>> _steps = [
    {
      "point": "Karate Chop",
      "desc": "Side of hand. 'Even though I feel stressed, I deeply accept myself.'",
      "imagePath": "assets/images/eft_1_karate_chop.png"
    },
    {
      "point": "Eyebrow",
      "desc": "Inner edge of eyebrow. 'This stress...'",
      "imagePath": "assets/images/eft_2_eyebrow.png"
    },
    {
      "point": "Side of Eye",
      "desc": "Bone outside the eye. 'All this tension...'",
      "imagePath": "assets/images/eft_3_side_eye.png"
    },
    {
      "point": "Under Eye",
      "desc": "Bone under the eye. 'This anxiety in my body...'",
      "imagePath": "assets/images/eft_4_under_eye.png"
    },
    {
      "point": "Under Nose",
      "desc": "Between nose and upper lip. 'Letting it go...'",
      "imagePath": "assets/images/eft_5_under_nose.png"
    },
    {
      "point": "Chin",
      "desc": "Crease of the chin. 'It is safe to relax...'",
      "imagePath": "assets/images/eft_6_chin.png"
    },
    {
      "point": "Collarbone",
      "desc": "Just below collarbone. 'Releasing it now...'",
      "imagePath": "assets/images/eft_7_collarbone.png"
    },
    {
      "point": "Top of Head",
      "desc": "Crown of the head. 'I am calm and grounded.'",
      "imagePath": "assets/images/eft_8_top_head.png"
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      HapticFeedback.selectionClick();
      _audio.playClick();
      setState(() => _currentStep++);
    } else {
      HapticFeedback.heavyImpact();
      _audio.playSuccess();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final stepData = _steps[_currentStep];

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32))
      ),
      // 🚀 STRICT SAFE AREA HANDLING (Moved inside container for seamless edges)
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            // 🎯 COMPACT HEADER
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  // 🚀 REFINED HEADER (Max Size 10, w700)
                  Text("EFT TAPPING", style: TextStyle(fontFamily: kDisplayFont, color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const Spacer(),
                  IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      }
                  )
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

            // 🎯 MAIN CONTENT AREA
            Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),

                            // 🎯 DYNAMIC PULSING IMAGE
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    color: colorScheme.primary.withOpacity(0.02 + (_pulseController.value * 0.08)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary.withOpacity(_pulseController.value * 0.15),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.asset(
                                      stepData['imagePath']!,
                                      key: ValueKey<int>(_currentStep),
                                      width: MediaQuery.of(context).size.width * 0.85,
                                      fit: BoxFit.fitWidth,
                                      errorBuilder: (context, error, stackTrace) => _buildErrorState(theme),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 32),

                            // 🎯 INSTRUCTION CARD
                            // 🚀 REFINED TITLE (Capped at 14, w700 instead of 20)
                            Text(
                              "Step ${_currentStep + 1}: ${stepData['point']}",
                              style: TextStyle(fontFamily: kDisplayFont, color: colorScheme.primary, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: theme.dividerColor.withOpacity(0.1))
                              ),
                              // 🚀 REFINED DESCRIPTION (Max Size 12, w500 instead of 18)
                              child: Text(
                                  "${stepData['desc']}",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontFamily: kBodyFont, fontSize: 12, height: 1.6, color: colorScheme.onSurface, fontWeight: FontWeight.w500)
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  }
              ),
            ),

            // 🎯 BOTTOM BUTTON
            Padding(
              // 🚀 Removed MediaQuery padding since SafeArea handles the bottom edge now
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity, height: 50, // 🚀 Standardized to 50
                child: FilledButton.icon(
                  onPressed: _nextStep,
                  icon: Icon(_currentStep == _steps.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 18),
                  // 🚀 REFINED BUTTON TEXT (Max Size 12, w700)
                  label: Text(
                      _currentStep == _steps.length - 1 ? "Complete Session" : "Next Point",
                      style: const TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)
                  ),
                  style: FilledButton.styleFrom(
                    elevation: 0, // 🚀 Flat premium look
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      height: 200,
      width: double.infinity,
      color: theme.dividerColor.withOpacity(0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 32, color: theme.hintColor.withOpacity(0.5)),
          const SizedBox(height: 8),
          Text("Illustration Missing", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}