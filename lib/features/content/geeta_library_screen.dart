import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_shift/main.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/PRESENTATION/providers/tts_service.dart';
import 'package:pure_shift/core/utils/geeta_shloka_model.dart';
import 'dart:ui';
import 'dart:math' as math;

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class GeetaLibrarySheet extends ConsumerStatefulWidget {
  const GeetaLibrarySheet({super.key});

  @override
  ConsumerState<GeetaLibrarySheet> createState() => _GeetaLibrarySheetState();
}

class _GeetaLibrarySheetState extends ConsumerState<GeetaLibrarySheet> with TickerProviderStateMixin {
  String _selectedLang = 'Hindi';
  String _selectedTag = 'All';
  final List<String> _emotions = ['All', 'Motivation', 'Peace', 'Fear', 'Duty', 'Depression', 'Anger'];

  String? _playingShlokaId;
  int _highlightStart = 0;
  int _highlightEnd = 0;

  double _speechRate = 0.4;
  double _speechPitch = 1.0;
  Map<String, String>? _selectedVoice;

  final PageController _pageController = PageController();
  late AnimationController _glowController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _initTtsHandlers();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  void _initTtsHandlers() {
    ttsService.onProgress = (start, end) {
      if (mounted) setState(() { _highlightStart = start; _highlightEnd = end; });
    };
    ttsService.onComplete = () {
      if (mounted) setState(() { _playingShlokaId = null; _highlightStart = 0; _highlightEnd = 0; });
    };
  }

  @override
  void dispose() {
    ttsService.stop();
    _pageController.dispose();
    _glowController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _playText(String id, String text, String langCode) async {
    HapticFeedback.lightImpact();
    if (_playingShlokaId == id) {
      await ttsService.stop();
      setState(() => _playingShlokaId = null);
      return;
    }
    await ttsService.stop();
    setState(() { _playingShlokaId = id; _highlightStart = 0; _highlightEnd = 0; });

    await ttsService.speak(
        text: text, languageCode: langCode, rate: _speechRate, pitch: _speechPitch, voice: _selectedVoice
    );
  }

  void _showSettings() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _GeetaSettingsSheet(
        currentRate: _speechRate, currentPitch: _speechPitch, currentVoice: _selectedVoice,
        onSettingsChanged: (rate, pitch, voice) => setState(() { _speechRate = rate; _speechPitch = pitch; _selectedVoice = voice; }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final geetaAsync = ref.watch(geetaLibraryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      // 🚀 THE FIX: Strict SafeArea handling for Bottom Sheets
      child: SafeArea(
        top: true,
        bottom: true,
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.2,
                  colors: [cs.primary.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
            // Sacred Geometry
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: CustomPaint(painter: _SacredGeometryPainter(color: cs.primary.withOpacity(0.05))),
                  );
                },
              ),
            ),

            Column(
              children: [
                const SizedBox(height: 12),
                // Drag Indicator
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

                // 🚀 NEW: Bottom Sheet Header with Cross Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("SACRED WISDOM", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                            const SizedBox(height: 2),
                            Text("Bhagavad Gita", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 12, fontWeight: FontWeight.w600)),
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

                // 🚀 NEW: Compact Toolbar (Replaces old header and FAB)
                _buildToolbar(theme, cs),

                Expanded(
                  child: geetaAsync.when(
                    loading: () => Center(child: CircularProgressIndicator(color: cs.primary)),
                    error: (e, _) => Center(child: Text("Divine connection error", style: const TextStyle(fontFamily: kBodyFont, fontSize: 12))),
                    data: (allShlokas) {
                      final filteredList = _selectedTag == 'All'
                          ? allShlokas
                          : allShlokas.where((s) => s.tags.contains(_selectedTag)).toList();

                      if (filteredList.isEmpty) {
                        return Center(child: Text("No Shlokas found.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor)));
                      }

                      return PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredList.length,
                        onPageChanged: (_) {
                          HapticFeedback.selectionClick();
                          ttsService.stop();
                          setState(() => _playingShlokaId = null);
                        },
                        itemBuilder: (context, index) => Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
                            child: _buildDivineCard(filteredList[index], theme, cs),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Language Toggle (Moved from FAB to a compact pill)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (_selectedLang == 'Hindi') setState(() => _selectedLang = 'English');
              else if (_selectedLang == 'English') setState(() => _selectedLang = 'Oriya');
              else setState(() => _selectedLang = 'Hindi');
            },
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, color: cs.primary, size: 14),
                  const SizedBox(width: 6),
                  Text(_selectedLang, style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),

          Row(
            children: [
              // Emotion Dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTag,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.hintColor, size: 16),
                    dropdownColor: theme.scaffoldBackgroundColor,
                    focusColor: Colors.transparent,
                    style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, fontSize: 11),
                    onChanged: (val) { HapticFeedback.selectionClick(); setState(() => _selectedTag = val!); },
                    items: _emotions.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: TextStyle(fontFamily: kBodyFont, color: cs.onSurface, fontSize: 11))
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Settings Button
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                ),
                child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.tune_rounded, color: cs.onSurface, size: 16),
                    onPressed: _showSettings
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDivineCard(GeetaShloka shloka, ThemeData theme, ColorScheme cs) {
    String displayText = _selectedLang == 'Oriya' ? shloka.oriyaMeaning : (_selectedLang == 'English' ? shloka.englishMeaning : shloka.hindiMeaning);
    String langCode = _selectedLang == 'Oriya' ? 'or-IN' : (_selectedLang == 'English' ? 'en-US' : 'hi-IN');
    final isPlaying = _playingShlokaId == shloka.id;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: isPlaying ? cs.primary.withOpacity(0.5) : theme.dividerColor.withOpacity(0.1), width: isPlaying ? 2 : 1),
            boxShadow: [
              if (isPlaying) BoxShadow(color: cs.primary.withOpacity(0.15 * _glowController.value), blurRadius: 40, spreadRadius: 10),
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 15)),
            ],
          ),
          child: child,
        );
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(
                "CHAPTER ${shloka.chapter} • VERSE ${shloka.verse}",
                style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: 2.0),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              shloka.sanskrit,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface, height: 1.6),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 40, height: 1, color: cs.primary.withOpacity(0.3)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.spa_rounded, color: cs.primary.withOpacity(0.5), size: 16)),
                  Container(width: 40, height: 1, color: cs.primary.withOpacity(0.3)),
                ],
              ),
            ),

            GestureDetector(
              onTap: () => _playText(shloka.id, displayText, langCode),
              child: isPlaying
                  ? _buildKaraokeText(displayText, cs, theme)
                  : Text(displayText, textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w500, height: 1.6, color: theme.hintColor)),
            ),

            const SizedBox(height: 32),

            GestureDetector(
              onTap: () => _playText(shloka.id, displayText, langCode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPlaying ? cs.primary : theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isPlaying ? Colors.transparent : theme.dividerColor.withOpacity(0.2)),
                  boxShadow: isPlaying ? [BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))] : [],
                ),
                child: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, color: isPlaying ? cs.onPrimary : cs.primary, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKaraokeText(String text, ColorScheme cs, ThemeData theme) {
    int start = _highlightStart.clamp(0, text.length);
    int end = _highlightEnd.clamp(0, text.length);

    if (end <= start) {
      return Text(text, textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w500, height: 1.6, color: cs.onSurface));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w500, height: 1.6, color: theme.hintColor),
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _SacredGeometryPainter extends CustomPainter {
  final Color color;
  _SacredGeometryPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.8;

    for (int i = 0; i < 12; i++) {
      final angle = (i * math.pi) / 6;
      final offset = Offset(math.cos(angle) * radius * 0.5, math.sin(angle) * radius * 0.5);
      canvas.drawCircle(center + offset, radius * 0.5, paint);
    }
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.95, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GeetaSettingsSheet extends StatefulWidget {
  final double currentRate;
  final double currentPitch;
  final Map<String, String>? currentVoice;
  final Function(double, double, Map<String, String>) onSettingsChanged;

  const _GeetaSettingsSheet({required this.currentRate, required this.currentPitch, required this.currentVoice, required this.onSettingsChanged});

  @override
  State<_GeetaSettingsSheet> createState() => _GeetaSettingsSheetState();
}

class _GeetaSettingsSheetState extends State<_GeetaSettingsSheet> {
  late double _rate;
  late double _pitch;
  Map<String, String>? _voice;
  List<dynamic> _voices = [];

  @override
  void initState() {
    super.initState();
    _rate = widget.currentRate;
    _pitch = widget.currentPitch;
    _voice = widget.currentVoice;
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final v = await ttsService.getIndianVoices();
    if(mounted) setState(() => _voices = v);
  }

  void _applyAndPreview() {
    widget.onSettingsChanged(_rate, _pitch, _voice!);
    ttsService.speak(text: "Om Namah Shivaya", languageCode: "hi-IN", rate: _rate, pitch: _pitch, voice: _voice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            // 🚀 REFINED HEADERS (Max Size 12, w700)
            Text("DIVINE ACOUSTICS", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text("Playback Configuration", style: TextStyle(fontFamily: kBodyFont, color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 32),

            _buildSliderRow("Recitation Speed", Icons.speed_rounded, _rate, 0.2, 0.8, (v) => setState(() => _rate = v), cs, theme),
            const SizedBox(height: 16),
            _buildSliderRow("Vocal Pitch", Icons.graphic_eq_rounded, _pitch, 0.5, 1.5, (v) => setState(() => _pitch = v), cs, theme),

            const SizedBox(height: 32),
            Text("AVAILABLE VOICES", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: _voices.length,
                itemBuilder: (context, index) {
                  final v = Map<String, String>.from(_voices[index] as Map);
                  final name = v['name'].toString();
                  final isFemale = name.toLowerCase().contains('female');
                  final isSelected = _voice?['name'] == name;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _voice = v);
                      _applyAndPreview();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary : theme.cardColor,
                        border: Border.all(color: isSelected ? Colors.transparent : theme.dividerColor.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected ? [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isFemale ? Icons.face_3_rounded : Icons.face_rounded, color: isSelected ? cs.onPrimary : theme.hintColor, size: 18),
                            const SizedBox(width: 8),
                            // 🚀 REFINED VOICE LABELS (Max Size 12, w700)
                            Text(isFemale ? "Female ${index+1}" : "Male ${index+1}", style: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 12, color: isSelected ? cs.onPrimary : cs.onSurface))
                          ]
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, IconData icon, double value, double min, double max, Function(double) onChanged, ColorScheme cs, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: theme.hintColor, size: 18),
        const SizedBox(width: 12),
        // 🚀 REFINED ROW LABELS (Max Size 12, w700)
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w700))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: cs.primary, inactiveTrackColor: cs.primary.withOpacity(0.1),
              thumbColor: cs.primary, overlayColor: cs.primary.withOpacity(0.2), trackHeight: 4,
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged, onChangeEnd: (_) => _applyAndPreview()),
          ),
        ),
      ],
    );
  }
}