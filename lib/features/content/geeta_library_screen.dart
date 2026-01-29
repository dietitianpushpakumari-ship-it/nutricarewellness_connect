import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/tts_service.dart';
import 'package:nutricare_connect/core/utils/geeta_shloka_model.dart';
import 'package:nutricare_connect/main.dart';
import 'dart:ui'; // For ImageFilter (Blur)

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

  @override
  void initState() {
    super.initState();
    _initTtsHandlers();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
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
        text: text,
        languageCode: langCode,
        rate: _speechRate,
        pitch: _speechPitch,
        voice: _selectedVoice
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _GeetaSettingsSheet(
        currentRate: _speechRate,
        currentPitch: _speechPitch,
        currentVoice: _selectedVoice,
        onSettingsChanged: (rate, pitch, voice) {
          setState(() {
            _speechRate = rate;
            _speechPitch = pitch;
            _selectedVoice = voice;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geetaAsync = ref.watch(geetaLibraryProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Gradient Layer
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFAF0), Color(0xFFFFE0B2), Color(0xFFFFCC80)], // Sunrise Gold
              ),
            ),
          ),

          // 2. Decorative Circles (Subtle Mandala Effect)
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 40),
              ),
            ),
          ),

          // 🎯 FIX: Removed invalid 'blurRadius', used BoxShadow instead
          Positioned(
            bottom: -150, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 60,
                    spreadRadius: 20,
                  )
                ],
              ),
            ),
          ),

          // 3. MAIN CONTENT
          geetaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
            error: (e, _) => Center(child: Text("Error: $e")),
            data: (allShlokas) {
              final filteredList = _selectedTag == 'All'
                  ? allShlokas
                  : allShlokas.where((s) => s.tags.contains(_selectedTag)).toList();

              if (filteredList.isEmpty) return const Center(child: Text("No Shlokas found."));

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: filteredList.length,
                onPageChanged: (_) {
                  ttsService.stop();
                  setState(() => _playingShlokaId = null);
                },
                itemBuilder: (context, index) => _buildDivineCard(filteredList[index]),
              );
            },
          ),

          // 4. FLOATING HEADER (Glass)
          Positioned(
            top: 50, left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, color: Colors.brown)),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTag,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.brown),
                          dropdownColor: const Color(0xFFFFF8E1),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 14),
                          onChanged: (val) => setState(() => _selectedTag = val!),
                          items: _emotions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Settings Fab
          Positioned(
            bottom: 30, right: 20,
            child: FloatingActionButton(
              onPressed: _showSettings,
              backgroundColor: Colors.brown,
              child: const Icon(Icons.tune, color: Colors.white),
            ),
          ),

          // Language Fab
          Positioned(
            bottom: 30, left: 20,
            child: FloatingActionButton.extended(
              onPressed: () {
                if (_selectedLang == 'Hindi') setState(() => _selectedLang = 'English');
                else if (_selectedLang == 'English') setState(() => _selectedLang = 'Oriya');
                else setState(() => _selectedLang = 'Hindi');
              },
              backgroundColor: Colors.white,
              elevation: 4,
              label: Text(_selectedLang, style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.translate, color: Colors.brown),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivineCard(GeetaShloka shloka) {
    String displayText = shloka.hindiMeaning;
    String langCode = 'hi-IN';
    if (_selectedLang == 'Oriya') { displayText = shloka.oriyaMeaning; langCode = 'or-IN'; }
    else if (_selectedLang == 'English') { displayText = shloka.englishMeaning; langCode = 'en-US'; }

    final isPlaying = _playingShlokaId == shloka.id;

    return Center(
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                if (isPlaying)
                  BoxShadow(
                      color: Colors.orange.withOpacity(0.3 * _glowController.value),
                      blurRadius: 30 + (20 * _glowController.value),
                      spreadRadius: 5
                  ),
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
              ],
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Chapter ${shloka.chapter} • Verse ${shloka.verse}",
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w900, letterSpacing: 1.5)
            ),
            const SizedBox(height: 24),

            Text(
              shloka.sanskrit,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                  height: 1.5,
                  fontFamily: 'Serif'
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(color: Colors.orange, thickness: 1, indent: 40, endIndent: 40),
            ),

            GestureDetector(
              onTap: () => _playText(shloka.id, displayText, langCode),
              child: isPlaying
                  ? _buildKaraokeText(displayText)
                  : Text(
                displayText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87, fontFamily: 'Sans'),
              ),
            ),

            const SizedBox(height: 40),

            GestureDetector(
              onTap: () => _playText(shloka.id, displayText, langCode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.orange.shade800 : Colors.orange.shade50,
                  shape: BoxShape.circle,
                  boxShadow: isPlaying ? [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10)] : [],
                ),
                child: Icon(
                    isPlaying ? Icons.graphic_eq : Icons.play_arrow_rounded,
                    color: isPlaying ? Colors.white : Colors.orange.shade900,
                    size: 32
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(isPlaying ? "Listening..." : "Listen", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildKaraokeText(String text) {
    if (_highlightEnd > text.length) return Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18));

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87, fontFamily: 'Sans'),
        children: [
          TextSpan(text: text.substring(0, _highlightStart), style: TextStyle(color: Colors.grey.shade400)),
          TextSpan(
            text: text.substring(_highlightStart, _highlightEnd),
            style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          TextSpan(text: text.substring(_highlightEnd)),
        ],
      ),
    );
  }
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Audio Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Row(children: [
            const Text("Speed"),
            Expanded(child: Slider(value: _rate, min: 0.2, max: 0.8, activeColor: Colors.orange, onChanged: (v) { setState(() => _rate = v); }, onChangeEnd: (_) => _applyAndPreview()))
          ]),
          Row(children: [
            const Text("Tone "),
            Expanded(child: Slider(value: _pitch, min: 0.5, max: 1.5, activeColor: Colors.brown, onChanged: (v) { setState(() => _pitch = v); }, onChangeEnd: (_) => _applyAndPreview()))
          ]),
          const SizedBox(height: 20),
          const Text("Select Voice", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _voices.length,
              itemBuilder: (context, index) {
                final v = Map<String, String>.from(_voices[index] as Map);
                final name = v['name'].toString();
                final isFemale = name.toLowerCase().contains('female');
                final isSelected = _voice?['name'] == name;
                return GestureDetector(
                  onTap: () { setState(() => _voice = v); _applyAndPreview(); },
                  child: Container(
                    decoration: BoxDecoration(color: isSelected ? Colors.orange.shade100 : Colors.grey.shade100, border: Border.all(color: isSelected ? Colors.orange : Colors.transparent), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isFemale ? Icons.female : Icons.male, color: isSelected ? Colors.deepOrange : Colors.grey), const SizedBox(width: 8), Text(isFemale ? "Female ${index+1}" : "Male ${index+1}", style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.deepOrange : Colors.black87))]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}