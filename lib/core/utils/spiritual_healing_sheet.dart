import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/tts_service.dart';

import 'package:nutricare_connect/main.dart'; // For ttsService
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';

import 'spiritual_mantra_model.dart';

class SpiritualHealingSheet extends StatefulWidget {
  const SpiritualHealingSheet({super.key});

  @override
  State<SpiritualHealingSheet> createState() => _SpiritualHealingSheetState();
}

class _SpiritualHealingSheetState extends State<SpiritualHealingSheet> with TickerProviderStateMixin {
  // --- State ---
  bool _isListeningMode = false;
  int _count = 0;
  int _rounds = 0;
  final _audio = WellnessAudioService();

  // TTS Settings
  double _speechRate = 0.3; // Default slow for Sanskrit
  double _speechPitch = 0.9; // Default deeper tone
  bool _enunciateMode = true; // Default ON for clear word separation
  Map<String, String>? _selectedVoice;

  String _lyricLanguage = "Sanskrit";

  late YoutubePlayerController _videoController;
  Key _playerKey = UniqueKey();
  SpiritualMantraModel? _selectedMantra;

  late AnimationController _beadController;

  @override
  void initState() {
    super.initState();
    _videoController = _createNewController("EkcKRFwfuvs", false);

    _beadController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 150),
        lowerBound: 0.95,
        upperBound: 1.0
    );
  }

  YoutubePlayerController _createNewController(String videoId, bool autoPlay) {
    return YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: autoPlay,
        mute: false,
        loop: true,
        enableCaption: false,
        forceHD: false,
        useHybridComposition: true,
      ),
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    _beadController.dispose();
    _audio.stop();
    ttsService.stop();
    super.dispose();
  }

  // --- LOGIC ---

  void _onMantraChanged(SpiritualMantraModel newMantra) {
    if (_selectedMantra?.id == newMantra.id) return;

    final newVideoId = YoutubePlayer.convertUrlToId(newMantra.youtubeUrl) ?? newMantra.youtubeUrl;

    if (_isListeningMode) {
      _videoController.load(newVideoId);
    } else {
      _videoController.cue(newVideoId);
    }

    setState(() {
      _selectedMantra = newMantra;
      _count = 0;
      _playerKey = ValueKey(newMantra.id);
    });
  }

  // 🎯 ENHANCED TTS: With Delays & Settings
  Future<void> _speakSanskrit({String? previewText}) async {
    if (_selectedMantra == null && previewText == null) return;

    String textToSpeak = previewText ?? (_selectedMantra!.sanskritText ?? _selectedMantra!.name);
    String lang = "hi-IN"; // Best for Sanskrit phonetics

    // If user selected English Lyrics, switch language, otherwise force Hindi/Sanskrit
    if (_selectedScript == "English" && previewText == null) {
      textToSpeak = _selectedMantra!.meaning;
      lang = "en-US";
    } else {
      // 🎯 "Word Delay" Logic: Replace spaces with commas to force pauses
      if (_enunciateMode) {
        textToSpeak = textToSpeak.split(' ').join(',   ');
      }
    }

    await ttsService.stop();
    await ttsService.speak(
      text: textToSpeak,
      languageCode: lang,
      rate: _speechRate,
      pitch: _speechPitch,
      voice: _selectedVoice, // Apply selected voice
    );
  }

  void _showVoiceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MantraVoiceSettings(
        currentRate: _speechRate,
        currentPitch: _speechPitch,
        enunciateEnabled: _enunciateMode,
        currentVoice: _selectedVoice,
        onChanged: (rate, pitch, enunciate, voice) {
          setState(() {
            _speechRate = rate;
            _speechPitch = pitch;
            _enunciateMode = enunciate;
            _selectedVoice = voice;
          });
          // 🎯 Immediate Effect: Play a short sample
          _speakSanskrit(previewText: "Om Namah Shivaya");
        },
      ),
    );
  }

  Future<void> _launchInYoutubeApp(String youtubeUrl) async {
    final videoId = YoutubePlayer.convertUrlToId(youtubeUrl) ?? youtubeUrl;
    final Uri appUri = Uri.parse('vnd.youtube://watch?v=$videoId');
    final Uri webUri = Uri.parse("https://www.youtube.com/watch?v=$videoId");
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error
    }
  }

  void _tapBead() {
    if (_isListeningMode) return;

    _audio.hapticMedium();
    _beadController.forward().then((_) => _beadController.reverse());

    setState(() {
      _count++;
      if (_count >= 108) {
        _count = 0;
        _rounds++;
        _audio.hapticSuccess();
        _audio.playDing();
        _showCompletionDialog();
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Round Complete! 🕉️"),
      content: const Text("You have completed 108 chants."),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Continue"))],
    ));
  }

  Map<String, List<SpiritualMantraModel>> _groupMantras(List<SpiritualMantraModel> mantras) {
    return groupBy(mantras, (m) {
      final name = m.name.toLowerCase();
      if (name.contains('shiva') || name.contains('mrityunjaya')) return 'Shiva 🕉️';
      if (name.contains('krishna') || name.contains('vasudevaya') || name.contains('rama') || name.contains('hare')) return 'Krishna 🪈';
      if (name.contains('gayatri') || name.contains('devi') || name.contains('durga') || name.contains('laxmi')) return 'Devi 🌺';
      if (name.contains('ganesha') || name.contains('ganpati')) return 'Ganesha 🐘';
      if (name.contains('om') || name.contains('peace')) return 'Peace & Om 🧘';
      return 'General ✨';
    });
  }

  // 🎯 MANTRA LIBRARY SHEET
  void _showMantraLibrary(BuildContext context, List<SpiritualMantraModel> mantras) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Mantra Library", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: _buildGroupedPlaylist(mantras: mantras, inSheet: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _selectedScript = "Sanskrit";

  String _getOriyaText(SpiritualMantraModel m) {
    // Placeholder for Oriya mapping - ideally this comes from DB
    if (m.name.contains("Gayatri")) return "ଓମ୍ ଭୂର୍ଭୁବଃ ସ୍ୱଃ ତତ୍ସବିତୁର୍ବରେଣ୍ୟଂ...";
    if (m.name.contains("Shiva")) return "ଓମ୍ ନମଃ ଶିବାୟ";
    return "ଓଡିଆ ଲିପି ଉପଲବ୍ଧ ନାହିଁ";
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8E1), // Saffron tint
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mantra_library').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
              final docs = snapshot.data?.docs ?? [];
              final mantras = docs.map((d) => SpiritualMantraModel.fromFirestore(d)).toList();
      
              if (mantras.isEmpty) return const Center(child: Text("No Mantras found."));
      
              if (_selectedMantra == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if(mounted) {
                    final first = mantras.first;
                    _onMantraChanged(first);
                  }
                });
              }
      
              final currentMantra = _selectedMantra ?? mantras.first;
      
              return Column(
                children: [
                  const SizedBox(height: 16),
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.orange.shade200, borderRadius: BorderRadius.circular(2)))),
      
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
                    child: Text("Spiritual Sanctuary", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown)),
                  ),
      
                  // 1. MODE TOGGLE
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.orange.shade100)),
                    child: Row(
                      children: [
                        _buildModeButton("Chant Myself", !_isListeningMode, () {
                          _videoController.pause();
                          setState(() => _isListeningMode = false);
                        }),
                        _buildModeButton("Listen Guide", _isListeningMode, () {
                          setState(() => _isListeningMode = true);
                          Future.delayed(const Duration(milliseconds: 300), () => _videoController.play());
                        }),
                      ],
                    ),
                  ),
      
                  const SizedBox(height: 20),
      
                  // 2. DYNAMIC CONTENT
                  Expanded(
                    child: _isListeningMode
                        ? _buildListeningContent(currentMantra, mantras)
                        : _buildChantingContent(currentMantra, mantras),
                  ),
                ],
              );
            }
        ),
      ),
    );
  }

  // --- TAB 1: LISTEN MODE ---
  Widget _buildListeningContent(SpiritualMantraModel mantra, List<SpiritualMantraModel> allMantras) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: YoutubePlayer(
              key: _playerKey,
              controller: _videoController,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.orange,
              bottomActions: [
                CurrentPosition(),
                ProgressBar(isExpanded: true, colors: const ProgressBarColors(playedColor: Colors.orange, handleColor: Colors.orangeAccent)),
                RemainingDuration(),
                const PlayPauseButton(),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  onPressed: () => _launchInYoutubeApp(mantra.youtubeUrl),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Playlist visible here
        _buildGroupedPlaylist(mantras: allMantras),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- TAB 2: CHANT MODE ---
  Widget _buildChantingContent(SpiritualMantraModel mantra, List<SpiritualMantraModel> allMantras) {
    // Text Selection
    String displayText = "";
    if (_selectedScript == "Sanskrit") displayText = mantra.sanskritText ?? mantra.name;
    else if (_selectedScript == "English") displayText = mantra.meaning;
    else displayText = _getOriyaText(mantra);

    return Column(
      children: [
        // Header: Library Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showMantraLibrary(context, allMantras),
              icon: const Icon(Icons.menu_book, color: Colors.brown),
              label: const Text("Change Mantra", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
            ),
          ),
        ),

        // Bead Counter
        Expanded(
          flex: 2,
          child: Center(
            child: ScaleTransition(
              scale: _beadController,
              child: GestureDetector(
                onTap: _tapBead,
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Colors.orange.shade300, Colors.deepOrange.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
                      BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 0, spreadRadius: 2, offset: const Offset(-2, -2))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint, color: Colors.white24, size: 40),
                      Text("$_count", style: const TextStyle(fontSize: 70, color: Colors.white, fontWeight: FontWeight.bold, height: 1.0)),
                      const Text("/ 108", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Lyrics Card
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Script Tabs
                    Row(
                      children: ["Sanskrit", "English", "Oriya"].map((lang) {
                        final isSel = _selectedScript == lang;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedScript = lang),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Text(
                                lang,
                                style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.deepOrange : Colors.grey, fontSize: 14, decoration: isSel ? TextDecoration.underline : null)
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // 🎯 Settings & Speak Buttons
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.tune, color: Colors.grey, size: 20),
                          onPressed: _showVoiceSettings,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () => _speakSanskrit(),
                          icon: const Icon(Icons.volume_up_rounded, color: Colors.deepOrange),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: "Pronounce",
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      displayText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, height: 1.6, color: Color(0xFF3E2723), fontWeight: FontWeight.w600, fontFamily: 'Serif'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text("Rounds: $_rounds", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
        ),
      ],
    );
  }

  Widget _buildGroupedPlaylist({required List<SpiritualMantraModel> mantras, bool inSheet = false}) {
    final groupedMantras = _groupMantras(mantras);
    final sortedKeys = groupedMantras.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!inSheet)
            const Padding(
              padding: EdgeInsets.only(bottom: 10, left: 4),
              child: Text("Playlist", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),

          ...sortedKeys.map((category) {
            final groupList = groupedMantras[category]!;
            final bool isExpanded = inSheet ? false : groupList.any((m) => m.id == _selectedMantra?.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade100),
                  boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.05), blurRadius: 8)]
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: isExpanded,
                  leading: const Icon(Icons.queue_music, color: Colors.orange),
                  title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                  children: groupList.map((mantra) {
                    final isSelected = mantra.id == _selectedMantra?.id;
                    return ListTile(
                      dense: true,
                      tileColor: isSelected ? Colors.orange.shade50 : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: Icon(
                        isSelected ? Icons.play_circle_filled : Icons.play_circle_outline,
                        color: isSelected ? Colors.deepOrange : Colors.grey,
                      ),
                      title: Text(mantra.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: Colors.black87)),
                      subtitle: Text(mantra.meaning, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        _onMantraChanged(mantra);
                        if (inSheet) Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.deepOrange : Colors.brown.withOpacity(0.6))),
        ),
      ),
    );
  }
}

// =================================================================
// 🎯 VOICE SETTINGS SHEET
// =================================================================
class _MantraVoiceSettings extends StatefulWidget {
  final double currentRate;
  final double currentPitch;
  final bool enunciateEnabled;
  final Map<String, String>? currentVoice;
  final Function(double, double, bool, Map<String, String>?) onChanged;

  const _MantraVoiceSettings({
    required this.currentRate, required this.currentPitch, required this.enunciateEnabled, required this.currentVoice, required this.onChanged
  });

  @override
  State<_MantraVoiceSettings> createState() => _MantraVoiceSettingsState();
}

class _MantraVoiceSettingsState extends State<_MantraVoiceSettings> {
  late double _rate;
  late double _pitch;
  late bool _enunciate;
  Map<String, String>? _voice;
  List<dynamic> _voices = [];

  @override
  void initState() {
    super.initState();
    _rate = widget.currentRate;
    _pitch = widget.currentPitch;
    _enunciate = widget.enunciateEnabled;
    _voice = widget.currentVoice;
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final v = await ttsService.getIndianVoices();
    if(mounted) setState(() => _voices = v);
  }

  void _update() {
    widget.onChanged(_rate, _pitch, _enunciate, _voice);
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
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text("Mantra Voice Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Sliders
          Row(children: [
            const Text("Speed"),
            Expanded(child: Slider(value: _rate, min: 0.1, max: 0.8, activeColor: Colors.orange, onChanged: (v) { setState(() => _rate = v); _update(); }))
          ]),
          Row(children: [
            const Text("Tone "),
            Expanded(child: Slider(value: _pitch, min: 0.5, max: 1.5, activeColor: Colors.brown, onChanged: (v) { setState(() => _pitch = v); _update(); }))
          ]),

          const SizedBox(height: 10),
          // Enunciate Toggle
          SwitchListTile(
            title: const Text("Enhance Word Separation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text("Adds pauses between words for clarity.", style: TextStyle(fontSize: 12)),
            value: _enunciate,
            activeColor: Colors.orange,
            onChanged: (val) { setState(() => _enunciate = val); _update(); },
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(height: 30),

          const Text("Voice Selection", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _voices.map((v) {
                  final Map<String, String> voiceMap = Map<String, String>.from(v as Map);
                  final name = voiceMap['name'] ?? '';
                  final isFemale = name.toLowerCase().contains('female') || name.toLowerCase().contains('hi-in-x');
                  final isSelected = _voice?['name'] == name;
                  final simpleLabel = isFemale ? "Female" : "Male";

                  return ActionChip(
                    avatar: Icon(isFemale ? Icons.female : Icons.male, size: 16, color: isSelected ? Colors.white : Colors.brown),
                    label: Text(simpleLabel),
                    backgroundColor: isSelected ? Colors.orange.shade700 : Colors.grey.shade100,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                    onPressed: () {
                      setState(() => _voice = voiceMap);
                      _update();
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}