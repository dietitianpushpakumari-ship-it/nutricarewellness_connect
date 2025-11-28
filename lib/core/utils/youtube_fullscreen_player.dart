import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubeFullscreenPlayer extends StatefulWidget {
  final String videoId;
  const YouTubeFullscreenPlayer({super.key, required this.videoId});

  @override
  State<YouTubeFullscreenPlayer> createState() => _YouTubeFullscreenPlayerState();
}

class _YouTubeFullscreenPlayerState extends State<YouTubeFullscreenPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        forceHD: true, // Forces High Definition if available
        enableCaption: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    // Force portrait mode back when closing the player
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // App Bar to allow closing the player
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
          ),
          // 🎯 FIX: Explicitly define actions to REMOVE PlaybackSpeedButton
          bottomActions: [
            CurrentPosition(),
            ProgressBar(isExpanded: true),
            RemainingDuration(),
            // const PlaybackSpeedButton(), // ❌ REMOVED to fix crash
            const FullScreenButton(),
          ],
          onEnded: (_) => Navigator.pop(context), // Auto-close when video ends
        ),
      ),
    );
  }
}