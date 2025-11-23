import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/tts_service.dart';
import 'package:nutricare_connect/core/utils/geeta_shloka_model.dart';
import 'package:nutricare_connect/main.dart';

class GeetaLibraryScreen extends ConsumerStatefulWidget {
  const GeetaLibraryScreen({super.key});

  @override
  ConsumerState<GeetaLibraryScreen> createState() => _GeetaLibraryScreenState();
}

class _GeetaLibraryScreenState extends ConsumerState<GeetaLibraryScreen> {
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

  @override
  void initState() {
    super.initState();
    _initTtsHandlers();
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
    // 🎯 FIX: Stop audio immediately when leaving
    ttsService.stop();
    _pageController.dispose();
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

    // 🎯 FIX: Pass the selected voice directly to the speak method
    await ttsService.speak(
        text: text,
        languageCode: langCode,
        rate: _speechRate,
        pitch: _speechPitch,
        voice: _selectedVoice // Passed here to ensure correct order
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: [Color(0xFFFFFAF0), Color(0xFFFFCC80)],
          ),
        ),
        child: geetaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
          error: (e, _) => Center(child: Text("Error: $e")),
          data: (allShlokas) {
            final filteredList = _selectedTag == 'All'
                ? allShlokas
                : allShlokas.where((s) => s.tags.contains(_selectedTag)).toList();

            if (filteredList.isEmpty) return const Center(child: Text("No Shlokas found."));

            return Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: filteredList.length,
                  onPageChanged: (_) {
                    ttsService.stop();
                    setState(() => _playingShlokaId = null);
                  },
                  itemBuilder: (context, index) => _buildImmersiveCard(filteredList[index]),
                ),

                // Top Bar
                Positioned(
                  top: 50, left: 20, right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const CircleAvatar(backgroundColor: Colors.black12, child: Icon(Icons.arrow_back, color: Colors.brown)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(30)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTag,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.brown),
                            dropdownColor: const Color(0xFFFFF8E1),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                            onChanged: (val) => setState(() => _selectedTag = val!),
                            items: _emotions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings Button
                Positioned(
                  bottom: 30, right: 20,
                  child: FloatingActionButton(
                    onPressed: _showSettings,
                    backgroundColor: Colors.orange.shade900,
                    child: const Icon(Icons.tune, color: Colors.white),
                  ),
                ),
                // Language Button
                Positioned(
                  bottom: 30, left: 20,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      if (_selectedLang == 'Hindi') setState(() => _selectedLang = 'English');
                      else if (_selectedLang == 'English') setState(() => _selectedLang = 'Oriya');
                      else setState(() => _selectedLang = 'Hindi');
                    },
                    backgroundColor: Colors.white,
                    label: Text(_selectedLang, style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                    icon: Icon(Icons.translate, color: Colors.orange.shade900),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImmersiveCard(GeetaShloka shloka) {
    String displayText = shloka.hindiMeaning;
    String langCode = 'hi-IN';

    if (_selectedLang == 'Oriya') {
      displayText = shloka.oriyaMeaning;
      langCode = 'or-IN';
    } else if (_selectedLang == 'English') {
      displayText = shloka.englishMeaning;
      langCode = 'en-US';
    }

    final isPlaying = _playingShlokaId == shloka.id;

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Chapter ${shloka.chapter} • Verse ${shloka.verse}",
                  style: TextStyle(fontSize: 14, color: Colors.orange.shade900.withOpacity(0.8), fontWeight: FontWeight.w600, letterSpacing: 2.0)
              ),
              const SizedBox(height: 30),

              Text(
                shloka.sanskrit,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3E2723), height: 1.6, fontFamily: 'Serif'),
              ),

              const SizedBox(height: 50),

              GestureDetector(
                onTap: () => _playText(shloka.id, displayText, langCode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isPlaying ? Colors.white : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: isPlaying ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))] : [],
                  ),
                  child: Column(
                    children: [
                      // 🎯 3. PREMIUM HIGHLIGHTER
                      if (isPlaying)
                        _buildKaraokeText(displayText)
                      else
                        Text(
                          displayText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87),
                        ),

                      const SizedBox(height: 16),
                      Icon(isPlaying ? Icons.graphic_eq : Icons.volume_up_rounded, color: Colors.orange, size: 28),
                      const SizedBox(height: 4),
                      Text(isPlaying ? "Listening..." : "Tap to Listen", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  // 🎯 4. MODERN HIGHLIGHTING (Size + Color + Weight)
  Widget _buildKaraokeText(String text) {
    if (_highlightEnd > text.length) return Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18));

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87, fontFamily: 'Roboto'),
        children: [
          TextSpan(text: text.substring(0, _highlightStart), style: TextStyle(color: Colors.grey.shade400)), // Past
          TextSpan(
            text: text.substring(_highlightStart, _highlightEnd),
            style: const TextStyle(
              color: Colors.deepOrange, // Highlight Color
              fontWeight: FontWeight.w900, // Extra Bold
              fontSize: 22, // Larger Scale
            ),
          ),
          TextSpan(text: text.substring(_highlightEnd)), // Future
        ],
      ),
    );
  }
}

// --- SETTINGS SHEET (Instant Apply) ---
class _GeetaSettingsSheet extends StatefulWidget {
  final double currentRate;
  final double currentPitch;
  final Map<String, String>? currentVoice;
  final Function(double, double, Map<String, String>) onSettingsChanged;

  const _GeetaSettingsSheet({
    required this.currentRate, required this.currentPitch, required this.currentVoice, required this.onSettingsChanged
  });

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

  // 🎯 5. INSTANT PREVIEW (Plays when any setting changes)
  void _applyAndPreview() {
    widget.onSettingsChanged(_rate, _pitch, _voice!);

    // Speak sample
    ttsService.speak(
        text: "Om Namah Shivaya",
        languageCode: "hi-IN",
        rate: _rate,
        pitch: _pitch,
        voice: _voice
    );
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

          // Speed
          Row(children: [
            const Text("Speed"),
            Expanded(child: Slider(value: _rate, min: 0.2, max: 0.8, activeColor: Colors.orange, onChanged: (v) { setState(() => _rate = v); }, onChangeEnd: (_) => _applyAndPreview()))
          ]),

          // Pitch (Tone)
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
                final isFemale = name.toLowerCase().contains('female'); // Simple check
                final isSelected = _voice?['name'] == name;

                return GestureDetector(
                  onTap: () {
                    setState(() => _voice = v);
                    _applyAndPreview();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        color: isSelected ? Colors.orange.shade100 : Colors.grey.shade100,
                        border: Border.all(color: isSelected ? Colors.orange : Colors.transparent),
                        borderRadius: BorderRadius.circular(12)
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isFemale ? Icons.female : Icons.male, color: isSelected ? Colors.deepOrange : Colors.grey),
                        const SizedBox(width: 8),
                        Text(isFemale ? "Female ${index+1}" : "Male ${index+1}", style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.deepOrange : Colors.black87)),
                      ],
                    ),
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