import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class ChatAudioPlayer extends StatefulWidget {
  final String? audioUrl;
  final String? localPath;
  final bool isSender;

  const ChatAudioPlayer({
    super.key,
    this.audioUrl,
    this.localPath,
    required this.isSender,
  });

  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isSourceSet = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((s) { if(mounted) setState(() => _isPlaying = s == PlayerState.playing); });
    _audioPlayer.onDurationChanged.listen((d) { if(mounted) setState(() => _duration = d); });
    _audioPlayer.onPositionChanged.listen((p) { if(mounted) setState(() => _position = p); });
    _audioPlayer.onPlayerComplete.listen((_) { if(mounted) setState(() { _isPlaying = false; _position = Duration.zero; }); });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (!_isSourceSet) {
          if (widget.audioUrl != null) await _audioPlayer.setSourceUrl(widget.audioUrl!);
          else if (widget.localPath != null) await _audioPlayer.setSourceDeviceFile(widget.localPath!);
          _isSourceSet = true;
        }
        await _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  String _formatTime(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSender ? Colors.teal.shade900 : Colors.grey.shade800;
    final trackColor = widget.isSender ? Colors.teal.withOpacity(0.4) : Colors.grey.withOpacity(0.4);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
      decoration: BoxDecoration(
        color: widget.isSender ? Colors.teal.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Play/Pause Btn
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            color: widget.isSender ? Colors.teal : Colors.grey.shade700,
            iconSize: 38,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _togglePlay,
          ),

          const SizedBox(width: 8),

          // 2. Slider & Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: widget.isSender ? Colors.teal : Colors.grey.shade700,
                      inactiveTrackColor: trackColor,
                      thumbColor: widget.isSender ? Colors.teal : Colors.grey.shade700,
                      trackShape: const RectangularSliderTrackShape(),
                    ),
                    child: Slider(
                      min: 0,
                      max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                      value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                      onChanged: (value) async {
                        final position = Duration(seconds: value.toInt());
                        await _audioPlayer.seek(position);
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatTime(_position), style: TextStyle(fontSize: 10, color: color)),
                      Text(_formatTime(_duration), style: TextStyle(fontSize: 10, color: color)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}