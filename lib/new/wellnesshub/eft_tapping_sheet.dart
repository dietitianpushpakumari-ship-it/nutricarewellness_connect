import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

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
      _audio.playClick();
      setState(() => _currentStep++);
    } else {
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

    return SafeArea(
      child: Container(
        height: MediaQuery
            .of(context)
            .size
            .height * 0.90,
        decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32))
        ),
        child: Column(
          children: [
            // 🎯 COMPACT HEADER
            const SizedBox(height: 12),
            Center(child: Container(width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2)))),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
              child: Row(
                children: [
                  Text("EFT TAPPING", style: TextStyle(color: theme.hintColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5)),
                  const Spacer(),
                  IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.hintColor),
                      onPressed: () => Navigator.pop(context)
                  )
                ],
              ),
            ),

            // 🎯 MAIN CONTENT AREA (MAXIMIZED)
            Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Dynamically size image based on available height
                    double imageSize = (constraints.maxHeight * 0.5).clamp(
                        200.0, 320.0);

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),

                            // 🎯 PULSING IMAGE CONTAINER
                            // 🎯 PULSING IMAGE CONTAINER
                            // 🎯 DYNAMIC PULSING IMAGE (ADAPTS TO SPACE)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  // 🎨 The pulsing glow now wraps the image tightly
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
                                  padding: const EdgeInsets.all(8), // Subtle padding for the glow
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.asset(
                                      stepData['imagePath']!,
                                      key: ValueKey<int>(_currentStep),
                                      // 🎯 'width' fills the screen width, 'fit' ensures height is automatic
                                      width: MediaQuery.of(context).size.width * 0.85,
                                      fit: BoxFit.fitWidth,
                                      errorBuilder: (context, error, stackTrace) => _buildErrorState(theme),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // 🎯 INSTRUCTION CARD
                            Text(
                              "Step ${_currentStep + 1}: ${stepData['point']}",
                              style: TextStyle(color: colorScheme.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: theme.dividerColor.withOpacity(
                                          0.1))
                              ),
                              child: Text(
                                  "${stepData['desc']}",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18,
                                      height: 1.5,
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w500)
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
              padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery
                  .of(context)
                  .padding
                  .bottom + 20),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: FilledButton.icon(
                  onPressed: _nextStep,
                  icon: Icon(_currentStep == _steps.length - 1 ? Icons
                      .check_circle_rounded : Icons.arrow_forward_rounded),
                  label: Text(_currentStep == _steps.length - 1
                      ? "Complete Session"
                      : "Next Point", style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 ACTUAL IMAGE RENDERING WITH FALLBACK
  // 🎯 FIXED IMAGE RENDERING
  // 🎯 THE "PERFECT FILL" IMAGE RENDERING
  // 🎯 THE "FULL VIEW" IMAGE RENDERING
  Widget _buildImage({required Key key, required String imagePath, required ThemeData theme, required bool isDark}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(8), // 🎯 Gives the image "breathing room"
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24), // 🎯 Modern rounded corners instead of a circle
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          imagePath,
          // 🎯 'contain' ensures 100% of the image is visible
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined, size: 40, color: theme.hintColor),
                  const SizedBox(height: 8),
                  Text("Image Missing", style: TextStyle(color: theme.hintColor, fontSize: 10)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      height: 200,
      width: double.infinity,
      color: theme.dividerColor.withOpacity(0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 40, color: theme.hintColor),
          const SizedBox(height: 8),
          Text("Illustration Missing", style: TextStyle(color: theme.hintColor, fontSize: 12)),
        ],
      ),
    );
  }
}