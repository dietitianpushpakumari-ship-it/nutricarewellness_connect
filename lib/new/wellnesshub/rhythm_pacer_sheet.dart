import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

// ============================================================================
// 1. CLINICAL MODELS & TEMPOS
// ============================================================================
class ClinicalTempo {
  final int eccentricMs;
  final int isometricMs;
  final int concentricMs;

  const ClinicalTempo({required this.eccentricMs, required this.isometricMs, required this.concentricMs});
}

class CardioPrescription {
  final int sets;
  final int targetReps;
  final int maxSafeRpe;
  final ClinicalTempo? tempo;

  const CardioPrescription({
    this.sets = 3,
    this.targetReps = 10,
    this.maxSafeRpe = 7,
    this.tempo,
  });
}

enum CardioSessionState { calibrating, countdown, active, rpeCheck, resting, summary }

// ============================================================================
// 2. MAIN WIDGET
// ============================================================================
class RhythmPacerSheet extends StatefulWidget {
  final CardioPrescription prescription;

  const RhythmPacerSheet({
    super.key,
    this.prescription = const CardioPrescription(),
  });

  @override
  State<RhythmPacerSheet> createState() => _RhythmPacerSheetState();
}

class _RhythmPacerSheetState extends State<RhythmPacerSheet> with SingleTickerProviderStateMixin {
  final _audio = WellnessAudioService();
  Timer? _videoLoopTimer;
  // Clinical State
  CardioSessionState _currentState = CardioSessionState.calibrating;
  late int _currentSet;
  int _completedReps = 0;
  int _restSecondsRemaining = 30;
  Timer? _restTimer;

  // Countdown Timer
  int _countdownSeconds = 3;
  Timer? _countdownTimer;

  // Workout Modes
  final Map<String, ClinicalTempo> _modes = {
    "Squats": const ClinicalTempo(eccentricMs: 2000, isometricMs: 500, concentricMs: 1500),
    "Lunges": const ClinicalTempo(eccentricMs: 2000, isometricMs: 1000, concentricMs: 1500),
    "Jumping Jacks": const ClinicalTempo(eccentricMs: 400, isometricMs: 0, concentricMs: 400),
    "High Knees": const ClinicalTempo(eccentricMs: 300, isometricMs: 0, concentricMs: 300),
    "Push-Ups": const ClinicalTempo(eccentricMs: 1500, isometricMs: 500, concentricMs: 1000),
  };
  String _currentMode = "Squats";

  // Mode Tracking
  bool _useCamera = false;

  // Instructor Mode (Video)
  VideoPlayerController? _videoController;

  // AI Camera & ML Kit
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isProcessingImage = false;
  bool _isPoseDetected = false;

  // Real-Time Joint Tracking (AI)
  double _liveKneeAngle = 180.0;
  bool _isAtBottom = false;

  // Pacemaker Timer
  late AnimationController _ghostController;
  double _ghostProgress = 0.0;
  DateTime? _repStartTime;

  @override
  void initState() {
    super.initState();
    _currentSet = 1;
    _initVideo(_currentMode);
    _initializeAICamera();

    _ghostController = AnimationController(vsync: this, duration: const Duration(days: 1))..forward();
    _ghostController.addListener(_updateGhostPacemaker);
  }

  void dispose() {
    _restTimer?.cancel();
    _countdownTimer?.cancel();
    _videoLoopTimer?.cancel(); // <--- ADD THIS
    _ghostController.dispose();
    _cameraController?.dispose();
    _poseDetector?.close();
    _videoController?.dispose();
    super.dispose();
  }

  // ============================================================================
  // 🚀 VIDEO ENGINE (FIXED)
  // ============================================================================
  String _getVideoPath(String mode) {
    switch (mode) {
      case "Squats": return 'assets/videos/squat.mp4';
      case "Lunges": return 'assets/videos/lunges2.mp4';
      case "Jumping Jacks": return 'assets/videos/jumping_jacks.mp4';
      case "High Knees": return 'assets/videos/high_knees1.mp4';
      case "Push-Ups": return 'assets/videos/pushup.mp4';
      default: return 'assets/videos/squat.mp4';
    }
  }

// ============================================================================
  // 🚀 VIDEO ENGINE (BULLETPROOF LOOPING FIX)
  // ============================================================================
// Replace your _initVideo method with this:
  void _initVideo(String mode) {
    final oldController = _videoController;

    // Cancel any existing loop timers
    _videoLoopTimer?.cancel();

    _videoController = VideoPlayerController.asset(_getVideoPath(mode));

    _videoController!.initialize().then((_) {
      if (!mounted) return;

      _videoController!.setVolume(0.0);
      _videoController!.setLooping(true); // Keep this as a fallback

      // If we are in instructor mode, play immediately
      if (!_useCamera) {
        _videoController!.play();

        // 🚀 THE MICRO-VIDEO LOOP FIX
        // Since your video is 168ms, we will forcefully seek it to 0 and play it every 150ms.
        // This prevents the MediaCodec from ever reaching "playback complete" and freezing.
        _videoLoopTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
          if (mounted && _videoController != null && _videoController!.value.isInitialized) {
            if (!_videoController!.value.isPlaying) {
              _videoController!.seekTo(Duration.zero);
              _videoController!.play();
            }
          }
        });
      }

      setState(() {});

      Future.delayed(const Duration(milliseconds: 200), () {
        oldController?.dispose();
      });

    }).catchError((e) => debugPrint("Video load error: $e"));
  }

  void _changeMode(String mode) {
    if (_currentMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentMode = mode;
      _completedReps = 0;
    });
    _initVideo(mode);
  }

  // ============================================================================
  // CLINICAL PACEMAKER ENGINE
  // ============================================================================
  void _updateGhostPacemaker() {
    if (_currentState != CardioSessionState.active) return;
    if (_useCamera && !_isPoseDetected) return;

    _repStartTime ??= DateTime.now();
    final elapsed = DateTime.now().difference(_repStartTime!).inMilliseconds;

    final t = widget.prescription.tempo ?? _modes[_currentMode]!;
    final totalRepTime = t.eccentricMs + t.isometricMs + t.concentricMs;

    if (elapsed > totalRepTime) {
      _repStartTime = DateTime.now();
      _audio.playTick();

      if (!_useCamera) {
        if (mounted) {
          setState(() {
            _completedReps++;
            if (_completedReps >= widget.prescription.targetReps) {
              _handleSetComplete();
            }
          });
        }
      }
      return;
    }

    setState(() {
      if (elapsed <= t.eccentricMs) {
        _ghostProgress = elapsed / t.eccentricMs;
      } else if (elapsed <= t.eccentricMs + t.isometricMs) {
        _ghostProgress = 1.0;
      } else {
        final upElapsed = elapsed - (t.eccentricMs + t.isometricMs);
        _ghostProgress = 1.0 - (upElapsed / t.concentricMs);
      }
    });
  }

  // ============================================================================
  // AI CAMERA TRACKING
  // ============================================================================
  Future<void> _initializeAICamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
      final format = Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420;

      _cameraController = CameraController(frontCamera, ResolutionPreset.low, enableAudio: false, imageFormatGroup: format);
      await _cameraController!.initialize();
      _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));

      if (mounted) {
        setState(() {});
        _startPoseTracking();
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _startPoseTracking() {
    if (_cameraController == null) return;

    _cameraController!.startImageStream((CameraImage image) async {
      if (!_useCamera || _isProcessingImage || _currentState == CardioSessionState.resting || _currentState == CardioSessionState.rpeCheck || _currentState == CardioSessionState.countdown) return;

      _isProcessingImage = true;

      try {
        final sensorOrientation = _cameraController!.description.sensorOrientation;
        final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation270deg;

        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) { allBytes.putUint8List(plane.bytes); }
        final bytes = allBytes.done().buffer.asUint8List();

        final inputFormat = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;
        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: inputFormat,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        final poses = await _poseDetector!.processImage(inputImage);

        if (poses.isNotEmpty) {
          final pose = poses.first;
          final hip = pose.landmarks[PoseLandmarkType.leftHip];
          final knee = pose.landmarks[PoseLandmarkType.leftKnee];
          final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];

          if (hip != null && knee != null && ankle != null && hip.likelihood > 0.5) {
            double angle = _calculateJointAngle(hip, knee, ankle);

            if (mounted) {
              setState(() {
                _liveKneeAngle = angle;
                _isPoseDetected = true;

                if (_currentState == CardioSessionState.active) {
                  _processRepLogic(angle);
                }
              });
            }
          } else {
            if (mounted && _isPoseDetected) setState(() => _isPoseDetected = false);
          }
        }
      } catch (e) {
        debugPrint("ML Kit Error: $e");
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  double _calculateJointAngle(PoseLandmark p1, PoseLandmark p2, PoseLandmark p3) {
    double radians = atan2(p3.y - p2.y, p3.x - p2.x) - atan2(p1.y - p2.y, p1.x - p2.x);
    double angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) angle = 360.0 - angle;
    return angle;
  }

  void _processRepLogic(double kneeAngle) {
    double targetDepth = (_currentMode == "Jumping Jacks" || _currentMode == "High Knees") ? 140.0 : 110.0;

    if (kneeAngle < targetDepth && !_isAtBottom) {
      _isAtBottom = true;
      _audio.hapticHeavy();
    } else if (kneeAngle > 160.0 && _isAtBottom) {
      _isAtBottom = false;
      _completedReps++;
      _audio.playSuccess();

      if (_completedReps >= widget.prescription.targetReps) {
        _handleSetComplete();
      }
    }
  }

  // ============================================================================
  // 🚀 SESSION WORKFLOW LOGIC (FIXED VIDEO PLAYBACK)
  // ============================================================================
  void _startWorkoutPhase() {
    HapticFeedback.mediumImpact();

    // 1. Force the video to play immediately as the countdown starts
    if (!_useCamera) _videoController?.play();

    setState(() {
      _currentState = CardioSessionState.countdown;
      _countdownSeconds = 3;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
        _audio.playTick();
      } else {
        timer.cancel();
        _audio.playDing();

        setState(() {
          _currentState = CardioSessionState.active;
          _repStartTime = DateTime.now();
        });

        // 2. Force the video to keep playing when transitioning to active
        if (!_useCamera) _videoController?.play();
      }
    });
  }

  void _handleSetComplete() {
    _repStartTime = null;
    _videoController?.pause();
    _audio.playSuccess();
    HapticFeedback.heavyImpact();
    if (_currentSet < widget.prescription.sets) {
      setState(() => _currentState = CardioSessionState.rpeCheck);
    } else {
      setState(() => _currentState = CardioSessionState.summary);
    }
  }

  void _submitRpeScore(double rpeScore) {
    HapticFeedback.lightImpact();
    if (rpeScore >= widget.prescription.maxSafeRpe) {
      _showSafetyAbortDialog();
    } else {
      setState(() {
        _currentState = CardioSessionState.resting;
        _restSecondsRemaining = 30;
      });

      _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_restSecondsRemaining > 1) {
          setState(() => _restSecondsRemaining--);
        } else {
          timer.cancel();
          HapticFeedback.mediumImpact();
          _audio.playSuccess();
          setState(() {
            _currentSet++;
            _completedReps = 0;
            _currentState = CardioSessionState.active;
            _repStartTime = DateTime.now();
          });
          if (!_useCamera) _videoController?.play();
        }
      });
    }
  }

  void _showSafetyAbortDialog() {
    final theme = Theme.of(context);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.redAccent.withOpacity(0.5))),
          title: const Text("Medical Override", style: TextStyle(fontFamily: kDisplayFont, color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
              "Your Perceived Exertion is too high for safe rehabilitation parameters. Terminating session to prevent overexertion.",
              style: TextStyle(fontFamily: kBodyFont, color: theme.colorScheme.onSurface, fontSize: 12)
          ),
          actions: [
            TextButton(
                onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                child: const Text("Understood", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700))
            )
          ],
        )
    );
  }

  // ============================================================================
  // UI BUILDERS
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("RHYTHM PACER", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text("Clinical Cardio Protocol", style: TextStyle(fontFamily: kBodyFont, color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
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

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildStateContent(theme, cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateContent(ThemeData theme, Color primary) {
    switch (_currentState) {
      case CardioSessionState.calibrating: return _buildCalibration(theme, primary);
      case CardioSessionState.countdown:
      case CardioSessionState.active: return _buildActiveWorkout(theme, primary);
      case CardioSessionState.rpeCheck: return _buildRpeCheck(theme, primary);
      case CardioSessionState.resting: return _buildResting(theme, primary);
      case CardioSessionState.summary: return _buildSummary(theme, primary);
    }
  }

  // 🚀 UNIVERSAL MEDIA CARD: Added ObjectKey to prevent video freezing during rebuilds
  Widget _buildMediaCard(Color primary) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primary.withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(color: primary.withOpacity(0.05), blurRadius: 40)]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            // INSTRUCTOR MODE: Loop MP4 File
            if (!_useCamera && _videoController != null && _videoController!.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    // 🚀 ADDED KEY to prevent Flutter from re-initializing and freezing the video
                    child: VideoPlayer(
                        key: ObjectKey(_videoController!),
                        _videoController!
                    ),
                  ),
                ),
              ),

            // AI MODE: Show Camera Feed
            if (_useCamera && _cameraController?.value.isInitialized == true)
              Transform.scale(scaleX: -1, child: CameraPreview(_cameraController!)),

            // SKELETON GHOST (Only active in AI Mode)
            if (_useCamera && (_currentState == CardioSessionState.active || _currentState == CardioSessionState.calibrating))
              AnimatedBuilder(
                animation: _ghostController,
                builder: (context, child) => CustomPaint(
                  painter: _ClinicalPacerPainter(
                    mode: _currentMode,
                    repCount: _completedReps,
                    ghostProgress: _ghostProgress,
                    liveProgress: _liveKneeAngle,
                    primaryColor: primary,
                  ),
                ),
              ),

            // COUNTDOWN OVERLAY (Darkens the video/camera and pulses numbers)
            if (_currentState == CardioSessionState.countdown)
              Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                        child: Text(
                            "$_countdownSeconds",
                            key: ValueKey<int>(_countdownSeconds),
                            style: const TextStyle(fontFamily: kDisplayFont, fontSize: 120, fontWeight: FontWeight.w800, color: Colors.white)
                        ),
                      )
                  )
              )
          ],
        ),
      ),
    );
  }

  Widget _buildCalibration(ThemeData theme, Color primary) {
    return Column(
      children: [
        // 🚨 MODE TOGGLE (AI Camera vs Instructor)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _useCamera = true); _videoController?.pause(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _useCamera ? primary.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text("AI Camera", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, color: _useCamera ? primary : theme.hintColor, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _useCamera = false);
                    _videoController?.play(); // Resume video on switch
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: !_useCamera ? primary.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text("Instructor", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, color: !_useCamera ? primary : theme.hintColor, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // WORKOUT SELECTOR CHIPS
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _modes.keys.map((m) {
              final isSelected = _currentMode == m;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ChoiceChip(
                  label: Text(m, style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  selected: isSelected,
                  onSelected: (val) => _changeMode(m),
                  selectedColor: primary.withOpacity(0.15),
                  backgroundColor: theme.cardColor,
                  side: BorderSide(color: isSelected ? primary.withOpacity(0.5) : theme.dividerColor.withOpacity(0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  labelStyle: TextStyle(color: isSelected ? primary : theme.hintColor),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),

        // 🚀 LIVE PREVIEW
        _buildMediaCard(primary),

        const SizedBox(height: 24),

        if (_useCamera) ...[
          const Text("Align Camera", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orangeAccent)),
          const SizedBox(height: 8),
          Text("Step back until your entire body\n(Head to ankles) is visible.", textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, height: 1.5)),
        ] else ...[
          Text(_currentMode, style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
              "Follow the instructor's form.\nReps will be counted automatically.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, height: 1.5)
          ),
        ],

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity, height: 50,
          child: FilledButton(
              style: FilledButton.styleFrom(elevation: 0, backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _startWorkoutPhase,
              child: const Text("Start Workout", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5))
          ),
        )
      ],
    );
  }

  // 🚀 SHARED WORKOUT & COUNTDOWN SCREEN
  Widget _buildActiveWorkout(ThemeData theme, Color primary) {
    return Column(
      children: [
        Text("Clinical $_currentMode", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text("Set $_currentSet of ${widget.prescription.sets}", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 32),

        _buildMediaCard(primary),

        const SizedBox(height: 32),

        if (_currentState == CardioSessionState.active) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricBox("Tempo", "${_modes[_currentMode]!.eccentricMs~/1000}-${_modes[_currentMode]!.isometricMs~/1000}-${_modes[_currentMode]!.concentricMs~/1000}", theme),
              _buildMetricBox("Reps", "$_completedReps / ${widget.prescription.targetReps}", theme, highlightColor: primary),
            ],
          ),
          const SizedBox(height: 32),

          if (_useCamera && !_isPoseDetected)
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Text("⚠️ POSE LOST: Step back into frame", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent))
            ),
        ] else ...[
          Text("GET READY", style: TextStyle(fontFamily: kDisplayFont, fontSize: 18, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 2)),
        ]
      ],
    );
  }

  Widget _buildRpeCheck(ThemeData theme, Color primary) {
    double localRpe = 3;
    return StatefulBuilder(
        builder: (context, setLocalState) {
          return Column(
            children: [
              Text("Safety Check", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 16),
              Text("Borg Rate of Perceived Exertion\nHow hard was that set?", textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, height: 1.5)),
              const SizedBox(height: 40),

              Text(localRpe.toStringAsFixed(0), style: TextStyle(fontFamily: kDisplayFont, fontSize: 36, fontWeight: FontWeight.w700, color: localRpe >= widget.prescription.maxSafeRpe ? Colors.redAccent : primary)),
              Text(localRpe < 3 ? "Light" : localRpe < 5 ? "Moderate" : localRpe < 7 ? "Hard" : "Very Hard", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w500, color: theme.hintColor)),
              const SizedBox(height: 20),

              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                child: Slider(
                    value: localRpe, min: 0, max: 10, divisions: 10,
                    activeColor: localRpe >= widget.prescription.maxSafeRpe ? Colors.redAccent : primary,
                    inactiveColor: theme.dividerColor.withOpacity(0.1),
                    onChanged: (val) {
                      if (val != localRpe) HapticFeedback.selectionClick();
                      setLocalState(() => localRpe = val);
                    }
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity, height: 50,
                child: FilledButton(
                    style: FilledButton.styleFrom(elevation: 0, backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () => _submitRpeScore(localRpe),
                    child: const Text("Continue", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5))
                ),
              )
            ],
          );
        }
    );
  }

  Widget _buildResting(ThemeData theme, Color primary) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.favorite_rounded, size: 64, color: Colors.redAccent),
        const SizedBox(height: 24),
        Text("Recovery Time", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 32),
        Text("00:${_restSecondsRemaining.toString().padLeft(2, '0')}", style: TextStyle(fontFamily: kDisplayFont, fontSize: 40, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 16),
        Text("Get ready for Set ${_currentSet + 1}", style: TextStyle(fontFamily: kBodyFont, color: primary, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildSummary(ThemeData theme, Color primary) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.check_circle_rounded, size: 64, color: primary),
        const SizedBox(height: 24),
        Text("Workout Complete", style: TextStyle(fontFamily: kDisplayFont, fontSize: 24, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 12),
        Text("Great job completing your protocol.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor)),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity, height: 50,
          child: FilledButton(
              style: FilledButton.styleFrom(elevation: 0, backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: const Text("Close", style: TextStyle(fontFamily: kDisplayFont, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5))
          ),
        )
      ],
    );
  }

  Widget _buildMetricBox(String label, String val, ThemeData theme, {Color? highlightColor}) {
    return Column(
        children: [
          Text(label, style: TextStyle(fontFamily: kBodyFont, fontSize: 10, fontWeight: FontWeight.w500, color: theme.hintColor)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: highlightColor ?? theme.colorScheme.onSurface))
        ]
    );
  }
}

// ============================================================================
// 3. DYNAMIC AR PAINTER
// ============================================================================
class _ClinicalPacerPainter extends CustomPainter {
  final String mode;
  final int repCount;
  final double ghostProgress;
  final double liveProgress;
  final Color primaryColor;

  _ClinicalPacerPainter({
    required this.mode,
    required this.repCount,
    required this.ghostProgress,
    required this.liveProgress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;

    final ghostPaint = Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    _drawBodyElements(canvas, cx, cy, ghostProgress, ghostPaint, true);

    double userProgress = (180.0 - liveProgress.clamp(90.0, 180.0)) / 90.0;
    final paint = Paint()..color = primaryColor..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    _drawBodyElements(canvas, cx, cy, userProgress, paint, false);
  }

  void _drawBodyElements(Canvas canvas, double cx, double cy, double p, Paint paint, bool isGhost) {
    double offsetY = 0.0;
    double legSpread = 0.0;
    double kneeBend = 0.0;
    bool isLunge = mode == "Lunges";
    double backKneeDrop = 0.0;

    if (mode == "Jumping Jacks" || mode == "High Knees") {
      offsetY = -(p * 40);
      legSpread = mode == "Jumping Jacks" ? p * 40 : 0;
    } else if (isLunge) {
      offsetY = p * 50;
      backKneeDrop = p * 40;
    } else {
      offsetY = p * 50;
      legSpread = p * 10;
      kneeBend = p * 35;
    }

    if (isGhost) {
      double armLift = (isLunge || mode == "Squats" || mode == "Push-Ups") ? (p * 40) : (p * 80);
      canvas.drawLine(Offset(cx - 20, cy - 50 + offsetY), Offset(cx - 40, cy + 10 + offsetY - armLift), paint);
      canvas.drawLine(Offset(cx + 20, cy - 50 + offsetY), Offset(cx + 40, cy + 10 + offsetY - armLift), paint);
    }

    if (isLunge) {
      bool leftLegForward = repCount % 2 == 0;

      void drawForwardLeg(double dir) {
        canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + (30 * dir), cy + 50 + offsetY), paint);
        canvas.drawLine(Offset(cx + (30 * dir), cy + 50 + offsetY), Offset(cx + (30 * dir), cy + 110), paint);
      }
      void drawBackLeg(double dir) {
        canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + (20 * dir), cy + 50 + offsetY + backKneeDrop), paint);
        canvas.drawLine(Offset(cx + (20 * dir), cy + 50 + offsetY + backKneeDrop), Offset(cx + (40 * dir), cy + 100), paint);
      }

      if (leftLegForward) { drawForwardLeg(-1.0); drawBackLeg(1.0); }
      else { drawBackLeg(-1.0); drawForwardLeg(1.0); }

    } else if (mode == "High Knees") {
      bool leftKneeUp = repCount % 2 == 0;
      canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + (leftKneeUp ? 20 : -20), cy + 110), paint);
      canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + (leftKneeUp ? -30 : 30), cy + 50 - (p * 30)), paint);
      canvas.drawLine(Offset(cx + (leftKneeUp ? -30 : 30), cy + 50 - (p * 30)), Offset(cx + (leftKneeUp ? -30 : 30), cy + 90), paint);
    } else {
      canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx - 20 - legSpread - kneeBend, cy + 50 + offsetY), paint);
      canvas.drawLine(Offset(cx - 20 - legSpread - kneeBend, cy + 50 + offsetY), Offset(cx - 20 - legSpread, cy + 110), paint);

      canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + 20 + legSpread + kneeBend, cy + 50 + offsetY), paint);
      canvas.drawLine(Offset(cx + 20 + legSpread + kneeBend, cy + 50 + offsetY), Offset(cx + 20 + legSpread, cy + 110), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ClinicalPacerPainter old) => true;
}