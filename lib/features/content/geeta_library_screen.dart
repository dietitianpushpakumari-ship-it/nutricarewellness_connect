import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/main.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/tts_service.dart';
import 'package:nutricare_connect/core/utils/geeta_shloka_model.dart';
import 'dart:ui';
import 'dart:math' as math;

class GeetaLibraryScreen extends ConsumerStatefulWidget {
  const GeetaLibraryScreen({super.key});

  @override
  ConsumerState<GeetaLibraryScreen> createState() => _GeetaLibraryScreenState();
}

class _GeetaLibraryScreenState extends ConsumerState<GeetaLibraryScreen> with TickerProviderStateMixin {
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

    // The breathing glow for the active card
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    // Slow, ambient rotation for the sacred geometry background (very lightweight)
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // The FAB stays floating at the bottom left
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedLang == 'Hindi') setState(() => _selectedLang = 'English');
          else if (_selectedLang == 'English') setState(() => _selectedLang = 'Oriya');
          else setState(() => _selectedLang = 'Hindi');
        },
        backgroundColor: cs.primary,
        elevation: 4,
        label: Text(_selectedLang, style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold, letterSpacing: 1)),
        icon: Icon(Icons.translate_rounded, color: cs.onPrimary),
      ),
      body: Stack(
        children: [
          // 🎯 1. AMBIENT THEME GRADIENT (Background)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.2,
                colors: [cs.primary.withOpacity(0.15), theme.scaffoldBackgroundColor],
              ),
            ),
          ),

          // 🎯 2. SACRED GEOMETRY BACKGROUND
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

          // 🎯 3. MAIN CONTENT LAYOUT (No more overlapping!)
          Column(
            children: [
              // Minimalist, compact header fixed at the top
              _buildCompactHeader(theme, cs),

              // The reading cards take up the remaining space perfectly
              Expanded(
                child: geetaAsync.when(
                  loading: () => Center(child: CircularProgressIndicator(color: cs.primary)),
                  error: (e, _) => Center(child: Text("Divine connection error: $e")),
                  data: (allShlokas) {
                    final filteredList = _selectedTag == 'All'
                        ? allShlokas
                        : allShlokas.where((s) => s.tags.contains(_selectedTag)).toList();

                    if (filteredList.isEmpty) {
                      return Center(child: Text("No Shlokas found.", style: TextStyle(color: theme.hintColor)));
                    }

                    return PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredList.length,
                      onPageChanged: (_) {
                        ttsService.stop();
                        setState(() => _playingShlokaId = null);
                      },
                      // 🎯 FIX 1: Align to top center and adjust padding
                      itemBuilder: (context, index) => Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          // 16px top gap, 80px bottom gap to clear the translation button
                          padding: const EdgeInsets.only(top: 16.0, bottom: 80.0),
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
    );
  }

  // 🎯 THE NEW COMPACT HEADER
  Widget _buildCompactHeader(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 40, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
              onPressed: () => Navigator.pop(context)
          ),

          // Compact Dropdown Pill
          Container(
            height: 36, // Forces a slim profile
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTag,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary, size: 18),
                dropdownColor: theme.scaffoldBackgroundColor,
                focusColor: Colors.transparent,
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 13),
                onChanged: (val) => setState(() => _selectedTag = val!),
                items: _emotions.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: TextStyle(color: cs.onSurface, fontSize: 13))
                )).toList(),
              ),
            ),
          ),

          // Settings Button
          IconButton(
              icon: Icon(Icons.tune_rounded, color: cs.onSurface),
              onPressed: _showSettings
          ),
        ],
      ),
    );
  }

  Widget _buildDivineCard(GeetaShloka shloka, ThemeData theme, ColorScheme cs) {
    String displayText = _selectedLang == 'Oriya' ? shloka.oriyaMeaning : (_selectedLang == 'English' ? shloka.englishMeaning : shloka.hindiMeaning);
    String langCode = _selectedLang == 'Oriya' ? 'or-IN' : (_selectedLang == 'English' ? 'en-US' : 'hi-IN');
    final isPlaying = _playingShlokaId == shloka.id;

    // 🎯 FIX 2: Removed "Center(child: ...)"
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20), // Left/Right spacing
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75, // Keeps it from overflowing
          ),
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
            // Chapter & Verse
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(
                "CHAPTER ${shloka.chapter} • VERSE ${shloka.verse}",
                style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w900, letterSpacing: 2.5),
              ),
            ),
            const SizedBox(height: 24),

            // Sanskrit Text
            Text(
              shloka.sanskrit,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface, height: 1.6, fontFamily: 'Serif'),
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

            // Translation / Karaoke Text
            GestureDetector(
              onTap: () => _playText(shloka.id, displayText, langCode),
              child: isPlaying
                  ? _buildKaraokeText(displayText, cs, theme)
                  : Text(displayText, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.6, color: theme.hintColor)),
            ),

            const SizedBox(height: 32),

            // Playback Control
            GestureDetector(
              onTap: () => _playText(shloka.id, displayText, langCode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isPlaying ? cs.primary : theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isPlaying ? Colors.transparent : theme.dividerColor.withOpacity(0.2)),
                  boxShadow: isPlaying ? [BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))] : [],
                ),
                child: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, color: isPlaying ? cs.onPrimary : cs.primary, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildKaraokeText(String text, ColorScheme cs, ThemeData theme) {
    // Safety clamp to prevent substring errors if TTS tracking is slightly off
    int start = _highlightStart.clamp(0, text.length);
    int end = _highlightEnd.clamp(0, text.length);

    if (end <= start) return Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.6, color: cs.onSurface));

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(fontSize: 16, height: 1.6, color: theme.hintColor),
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}

// 🎯 HARDWARE ACCELERATED SACRED GEOMETRY (Zero lag background)
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

    // Draws a 12-petaled geometric mandala
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

// 🎯 PREMIUM SETTINGS SHEET
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
            Text("DIVINE ACOUSTICS", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text("Playback Configuration", style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
        
            _buildSliderRow("Recitation Speed", Icons.speed_rounded, _rate, 0.2, 0.8, (v) => setState(() => _rate = v), cs, theme),
            const SizedBox(height: 16),
            _buildSliderRow("Vocal Pitch", Icons.graphic_eq_rounded, _pitch, 0.5, 1.5, (v) => setState(() => _pitch = v), cs, theme),
        
            const SizedBox(height: 32),
            Text("AVAILABLE VOICES", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                    onTap: () { setState(() => _voice = v); _applyAndPreview(); },
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
                            Icon(isFemale ? Icons.face_3_rounded : Icons.face_rounded, color: isSelected ? cs.onPrimary : theme.hintColor, size: 20),
                            const SizedBox(width: 8),
                            Text(isFemale ? "Female ${index+1}" : "Male ${index+1}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? cs.onPrimary : cs.onSurface))
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
        Icon(icon, color: theme.hintColor, size: 20),
        const SizedBox(width: 12),
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
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