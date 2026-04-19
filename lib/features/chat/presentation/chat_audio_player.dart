import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class ChatAudioPlayer extends StatefulWidget {
  final String? audioUrl;
  final bool isSender;

  const ChatAudioPlayer({
    super.key,
    required this.audioUrl,
    required this.isSender,
  });

  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    // Listen to play state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _position = Duration.zero;
            _isPlaying = false;
          }
        });
      }
    });

    // Listen to audio duration
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    // Listen to audio position
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    HapticFeedback.lightImpact();
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() => _isLoading = true);
        // If it's the first time playing, we need to set the source
        if (_position == Duration.zero) {
          await _audioPlayer.setSourceUrl(widget.audioUrl!);
        }
        await _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint("Audio Play Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 🚀 PREMIUM COLOR LOGIC
    // If sent by ME (solid colored bubble), use transparent white overlays
    // If sent by THEM (white/card bubble), use subtle primary color overlays
    final Color baseColor = widget.isSender ? cs.onPrimary : cs.primary;
    final Color pillBgColor = widget.isSender ? Colors.black.withOpacity(0.15) : cs.primary.withOpacity(0.08);
    final Color activeTrackColor = baseColor;
    final Color inactiveTrackColor = baseColor.withOpacity(0.3);

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: pillBgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🚀 1. PLAY / PAUSE BUTTON WITH SOFT SHADOW
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: baseColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: _isLoading && _duration == Duration.zero
                  ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.isSender ? cs.primary : cs.onPrimary,
                ),
              )
                  : Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isSender ? cs.primary : cs.onPrimary,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 🚀 2. CUSTOM SLEEK SLIDER
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3.5, // Thick, modern track
                activeTrackColor: activeTrackColor,
                inactiveTrackColor: inactiveTrackColor,
                thumbColor: baseColor,
                overlayColor: baseColor.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0), // Smaller, sleeker thumb
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                trackShape: const RoundedRectSliderTrackShape(), // Rounded ends
              ),
              child: Slider(
                min: 0.0,
                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                onChanged: (value) async {
                  final newPosition = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(newPosition);
                  setState(() => _position = newPosition);
                },
              ),
            ),
          ),

          // 🚀 3. CRISP TYPOGRAPHY TIMESTAMP
          Padding(
            padding: const EdgeInsets.only(right: 8.0, left: 4.0),
            child: SizedBox(
              width: 36, // Fixed width prevents jittering when seconds change
              child: Text(
                _formatDuration(_duration == Duration.zero || !_isPlaying ? _duration : _position),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: kDisplayFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: baseColor.withOpacity(0.9),
                  fontFeatures: const [FontFeature.tabularFigures()], // Keeps numbers aligned
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}