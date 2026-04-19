import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class SomaticPopItSheet extends StatefulWidget {
  const SomaticPopItSheet({super.key});

  @override
  State<SomaticPopItSheet> createState() => _SomaticPopItSheetState();
}

class _SomaticPopItSheetState extends State<SomaticPopItSheet> {
  Key _gridKey = UniqueKey();
  final _audio = WellnessAudioService();

  void _resetBoard() {
    HapticFeedback.lightImpact();
    _audio.playSuccess();
    _audio.hapticHeavy();
    setState(() => _gridKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

            // 🚀 THE FIX: Standardized Header with Cross Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TACTILE GROUNDING", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text("Somatic Silicone Matrix", style: TextStyle(fontFamily: kBodyFont, color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
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
            const SizedBox(height: 16),

            // 🎯 2. THE SILICONE BOARD
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ]
                  ),
                  child: GridView.builder(
                    key: _gridKey,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: 30, // 6 rows of 5
                    itemBuilder: (context, index) {
                      return _SiliconeBubble(
                        audioService: _audio,
                        baseColor: cs.primary,
                      );
                    },
                  ),
                ),
              ),
            ),

            // 🎯 3. RESET BUTTON
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: FilledButton.icon(
                  onPressed: _resetBoard,
                  icon: const Icon(Icons.flip_rounded, size: 18),
                  label: const Text("RESTORE MATRIX", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: cs.primary,
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
}

// 🎯 INDIVIDUAL SILICONE BUBBLE
class _SiliconeBubble extends StatefulWidget {
  final WellnessAudioService audioService;
  final Color baseColor;

  const _SiliconeBubble({
    required this.audioService,
    required this.baseColor,
  });

  @override
  State<_SiliconeBubble> createState() => _SiliconeBubbleState();
}

class _SiliconeBubbleState extends State<_SiliconeBubble> {
  bool _isPopped = false;

  void _togglePop() {
    if (_isPopped) return;

    widget.audioService.hapticHeavy();
    HapticFeedback.heavyImpact();

    setState(() => _isPopped = true);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _togglePop,
      child: AnimatedScale(
        scale: _isPopped ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: _isPopped ? const Alignment(0.3, 0.3) : const Alignment(-0.3, -0.3),
              radius: 0.7,
              colors: _isPopped
                  ? [widget.baseColor.withOpacity(0.1), widget.baseColor.withOpacity(0.3)]
                  : [widget.baseColor.withOpacity(0.8), widget.baseColor],
            ),
            boxShadow: _isPopped
                ? []
                : [
              BoxShadow(
                color: isDark ? Colors.black54 : widget.baseColor.withOpacity(0.4),
                blurRadius: 5,
                offset: const Offset(2, 4),
              )
            ],
            border: Border.all(
              color: _isPopped ? widget.baseColor.withOpacity(0.4) : widget.baseColor.withOpacity(0.1),
              width: _isPopped ? 1.5 : 0.5,
            ),
          ),
        ),
      ),
    );
  }
}