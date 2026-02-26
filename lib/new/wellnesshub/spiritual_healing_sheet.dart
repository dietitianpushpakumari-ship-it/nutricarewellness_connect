import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/tts_service.dart';
import 'package:nutricare_connect/main.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/utils/spiritual_mantra_model.dart';

class SpiritualHealingSheet extends StatefulWidget {
  const SpiritualHealingSheet({super.key});
  @override
  State<SpiritualHealingSheet> createState() => _SpiritualHealingSheetState();
}

class _SpiritualHealingSheetState extends State<SpiritualHealingSheet> {
  int _activeTabIndex = 0;
  SpiritualMantraModel? _selectedMantra;

  // 🎯 FIX: Picker now has access to the correct state scope
  void _showMantraPicker(BuildContext context, List<SpiritualMantraModel> mantras) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("Mantra Library", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: mantras.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final m = mantras[i];
                  bool isSelected = m.id == _selectedMantra?.id;
                  return ListTile(
                    onTap: () {
                      setState(() => _selectedMantra = m);
                      Navigator.pop(context);
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tileColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Theme.of(context).cardColor,
                    leading: Icon(Icons.spa_rounded, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
                    title: Text(m.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mantra_library').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final mantras = snapshot.data!.docs.map((d) => SpiritualMantraModel.fromFirestore(d)).toList();
              if (mantras.isEmpty) return const Center(child: Text("Library Empty"));
              _selectedMantra ??= mantras.first;
        
              return Column(
                children: [
                  _buildCompactHeader(theme, cs),
                  _buildTabToggle(theme, cs),
                  Expanded(
                    child: IndexedStack(
                      index: _activeTabIndex,
                      children: [
                        MantraChanterWidget(
                          mantra: _selectedMantra!,
                          onOpenPicker: () => _showMantraPicker(context, mantras), // 🎯 Pass callback
                        ),
                        MantraGuideWidget(
                          selectedMantra: _selectedMantra!,
                          allMantras: mantras,
                          onMantraChanged: (m) => setState(() => _selectedMantra = m),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
        ),
      ),
    );
  }

  // ... (Header and Toggle buttons remain same as your code)
  Widget _buildCompactHeader(ThemeData theme, ColorScheme cs) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("VAGUS NERVE STIMULATION", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    Text("Spiritual Sanctuary", style: TextStyle(color: theme.hintColor, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildTabToggle(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            _toggleBtn("Manual Chant", _activeTabIndex == 0, () => setState(() => _activeTabIndex = 0), cs),
            _toggleBtn("Guided Audio", _activeTabIndex == 1, () => setState(() => _activeTabIndex = 1), cs),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool isSel, VoidCallback onTap, ColorScheme cs) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isSel ? cs.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }
}

class MantraChanterWidget extends StatefulWidget {
  final SpiritualMantraModel mantra;
  final VoidCallback onOpenPicker; // 🎯 Added callback
  const MantraChanterWidget({super.key, required this.mantra, required this.onOpenPicker});

  @override
  State<MantraChanterWidget> createState() => _MantraChanterWidgetState();
}

class _MantraChanterWidgetState extends State<MantraChanterWidget> with SingleTickerProviderStateMixin {
  int _count = 0;
  int _rounds = 0;
  bool _isLotusBlooming = false;
  String _script = "Sanskrit";
  final _audio = WellnessAudioService();
  late AnimationController _beadController;

  @override
  void initState() {
    super.initState();
    _beadController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), lowerBound: 0.95, upperBound: 1.0);
  }

  void _tapBead() {
    if (_isLotusBlooming) return;
    _beadController.forward().then((_) => _beadController.reverse());

    // Syllabic Rhythmic Feedback
    if (_script == "Sanskrit") {
      _audio.hapticMedium();
      Future.delayed(const Duration(milliseconds: 80), () => _audio.hapticMedium());
    } else {
      _audio.hapticHeavy();
    }

    setState(() {
      _count++;
      if (_count >= 108) {
        _count = 0;
        _rounds++;
        _isLotusBlooming = true;
        _audio.playSuccess();
        Future.delayed(const Duration(seconds: 4), () { if (mounted) setState(() => _isLotusBlooming = false); });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    double progress = (_count / 108).clamp(0.0, 1.0);
    bool showBreathPrompt = (_count > 0 && _count % 27 == 0);

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: RepaintBoundary(
            child: ScaleTransition(
              scale: _beadController,
              child: GestureDetector(
                onTap: _tapBead,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(width: 180, height: 180, child: CircularProgressIndicator(value: 1.0, strokeWidth: 8, color: theme.dividerColor.withOpacity(0.05))),
                    SizedBox(width: 180, height: 180, child: CircularProgressIndicator(value: _isLotusBlooming ? 1.0 : progress, strokeWidth: 8, strokeCap: StrokeCap.round, valueColor: AlwaysStoppedAnimation<Color>(cs.primary))),
                    Container(
                      width: 150, height: 150,
                      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: cs.primary.withOpacity(progress * 0.2), blurRadius: 35)]),
                      child: _isLotusBlooming
                          ? const Icon(Icons.spa_rounded, color: Colors.pinkAccent, size: 70)
                          : (showBreathPrompt
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.air_rounded, color: cs.primary), const Text("BREATH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))])
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("$_count", style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: cs.primary)), const Text("OF 108", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))])),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildLyricsCard(theme, cs),
      ],
    );
  }

  Widget _buildLyricsCard(ThemeData theme, ColorScheme cs) {
    return Expanded(
      flex: 6,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
        child: Column(
          children: [
            Row(
              children: [
                _scriptToggle("Sanskrit"),
                _scriptToggle("English"),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.volume_up_rounded, color: cs.primary, size: 20),
                  onPressed: () => ttsService.speak(
                    text: _script == "Sanskrit" ? (widget.mantra.sanskritText ?? widget.mantra.name) : widget.mantra.meaning,
                    languageCode: _script == "Sanskrit" ? "hi-IN" : "en-US",
                    rate: 0.35,
                  ),
                ),
                IconButton(icon: Icon(Icons.grid_view_rounded, color: theme.hintColor, size: 20), onPressed: widget.onOpenPicker),
              ],
            ),
            const Divider(height: 24),
            Expanded(child: Center(child: SingleChildScrollView(child: Text(_script == "Sanskrit" ? (widget.mantra.sanskritText ?? widget.mantra.name) : widget.mantra.meaning, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.6, fontFamily: 'Serif'))))),
            Text("SESSION ROUNDS: $_rounds", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _scriptToggle(String s) {
    bool isSel = _script == s;
    return GestureDetector(onTap: () => setState(() => _script = s), child: Padding(padding: const EdgeInsets.only(right: 16), child: Text(s, style: TextStyle(color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey, fontWeight: isSel ? FontWeight.bold : FontWeight.normal))));
  }

  @override
  void didUpdateWidget(MantraChanterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mantra.id != widget.mantra.id) {
      setState(() { _count = 0; _isLotusBlooming = false; });
      ttsService.stop();
    }
  }

  @override
  void dispose() { _beadController.dispose(); super.dispose(); }
}

// ... (MantraGuideWidget remains same as your code)
class MantraGuideWidget extends StatefulWidget {
  final SpiritualMantraModel selectedMantra;
  final List<SpiritualMantraModel> allMantras;
  final Function(SpiritualMantraModel) onMantraChanged;

  const MantraGuideWidget({super.key, required this.selectedMantra, required this.allMantras, required this.onMantraChanged});

  @override
  State<MantraGuideWidget> createState() => _MantraGuideWidgetState();
}

class _MantraGuideWidgetState extends State<MantraGuideWidget> {
  late YoutubePlayerController _ytController;

  @override
  void initState() {
    super.initState();
    final id = YoutubePlayer.convertUrlToId(widget.selectedMantra.youtubeUrl)!;
    _ytController = YoutubePlayerController(initialVideoId: id, flags: const YoutubePlayerFlags(autoPlay: false));
  }

  @override
  void didUpdateWidget(MantraGuideWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMantra.id != widget.selectedMantra.id) {
      final id = YoutubePlayer.convertUrlToId(widget.selectedMantra.youtubeUrl)!;
      _ytController.load(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(20), child: YoutubePlayer(controller: _ytController)),
        const SizedBox(height: 24),
        Text("PLAYLIST", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ...widget.allMantras.map((m) => ListTile(
          onTap: () => widget.onMantraChanged(m),
          contentPadding: EdgeInsets.zero,
          leading: Icon(m.id == widget.selectedMantra.id ? Icons.play_circle_filled : Icons.play_circle_outline, color: m.id == widget.selectedMantra.id ? theme.colorScheme.primary : Colors.grey),
          title: Text(m.name, style: TextStyle(fontSize: 14, fontWeight: m.id == widget.selectedMantra.id ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(m.meaning, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
        )),
      ],
    );
  }

  @override
  void dispose() { _ytController.dispose(); super.dispose(); }
}