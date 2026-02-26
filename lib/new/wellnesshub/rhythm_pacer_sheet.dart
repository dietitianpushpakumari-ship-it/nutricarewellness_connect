import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

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

enum CardioSessionState { calibrating, active, rpeCheck, resting, summary }

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

  // Clinical State
  CardioSessionState _currentState = CardioSessionState.calibrating;
  late int _currentSet;
  int _completedReps = 0;
  int _restSecondsRemaining = 30;
  Timer? _restTimer;

  // 🚨 WORKOUT MODES RESTORED 🚨
  final Map<String, ClinicalTempo> _modes = {
    "Squats": const ClinicalTempo(eccentricMs: 2000, isometricMs: 500, concentricMs: 1500),
    "Lunges": const ClinicalTempo(eccentricMs: 2000, isometricMs: 1000, concentricMs: 1500),
    "Jumping Jacks": const ClinicalTempo(eccentricMs: 400, isometricMs: 0, concentricMs: 400),
    "High Knees": const ClinicalTempo(eccentricMs: 300, isometricMs: 0, concentricMs: 300),
  };
  String _currentMode = "Squats";

  // Mode Tracking
  bool _useCamera = false; // Default to animation mode for easier testing

  // AI Camera & ML Kit
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isProcessingImage = false;
  bool _isPoseDetected = false;

  // Real-Time Joint Tracking (AI)
  double _liveKneeAngle = 180.0;
  bool _isAtBottom = false;

  // Pacemaker Animation
  late AnimationController _ghostController;
  double _ghostProgress = 0.0;
  DateTime? _repStartTime;

  @override
  void initState() {
    super.initState();
    _currentSet = 1;
    _initializeAICamera();

    _ghostController = AnimationController(vsync: this, duration: const Duration(days: 1))..forward();
    _ghostController.addListener(_updateGhostPacemaker);
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _ghostController.dispose();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  void _changeMode(String mode) {
    setState(() {
      _currentMode = mode;
      _completedReps = 0;
    });
  }

  // ============================================================================
  // CLINICAL PACEMAKER ENGINE (Asymmetric Tempo)
  // ============================================================================
  void _updateGhostPacemaker() {
    if (_currentState != CardioSessionState.active) return;
    if (_useCamera && !_isPoseDetected) return;

    _repStartTime ??= DateTime.now();
    final elapsed = DateTime.now().difference(_repStartTime!).inMilliseconds;

    // 🎯 NEW LOGIC: Prioritize Prescription Tempo over Mode Default
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
        _ghostProgress = elapsed / t.eccentricMs; // Eccentric (Down)
      } else if (elapsed <= t.eccentricMs + t.isometricMs) {
        _ghostProgress = 1.0; // Isometric (Hold)
      } else {
        final upElapsed = elapsed - (t.eccentricMs + t.isometricMs);
        _ghostProgress = 1.0 - (upElapsed / t.concentricMs); // Concentric (Up)
      }
    });
  }

  // ============================================================================
  // AI CAMERA TRACKING
  // ============================================================================
  Future<void> _initializeAICamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
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
      if (!_useCamera || _isProcessingImage || _currentState == CardioSessionState.resting || _currentState == CardioSessionState.rpeCheck) return;
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

                if (_currentState == CardioSessionState.calibrating) {
                  _isPoseDetected = true;
                  _currentState = CardioSessionState.active;
                  _repStartTime = DateTime.now();
                } else if (_currentState == CardioSessionState.active) {
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
    // For AI Camera mode, we use knee angle to verify reps
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
  // SESSION WORKFLOW LOGIC
  // ============================================================================
  void _startAnimationMode() {
    setState(() {
      _useCamera = false;
      _currentState = CardioSessionState.active;
      _repStartTime = DateTime.now();
    });
  }

  void _handleSetComplete() {
    _repStartTime = null;
    if (_currentSet < widget.prescription.sets) {
      setState(() => _currentState = CardioSessionState.rpeCheck);
    } else {
      setState(() => _currentState = CardioSessionState.summary);
    }
  }

  void _submitRpeScore(double rpeScore) {
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
          setState(() {
            _currentSet++;
            _completedReps = 0;
            _currentState = CardioSessionState.active;
            _repStartTime = DateTime.now();
          });
        }
      });
    }
  }

  void _showSafetyAbortDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A0909),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.redAccent.withOpacity(0.5))),
          title: const Text("Medical Override", style: TextStyle(color: Colors.redAccent)),
          content: const Text("Your Perceived Exertion is too high for safe rehabilitation parameters. Terminating session to prevent overexertion.", style: TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("Understood"))],
        )
    );
  }

  // ============================================================================
  // UI BUILDERS
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, -10))]
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildStateContent(primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateContent(Color primary) {
    switch (_currentState) {
      case CardioSessionState.calibrating: return _buildCalibration(primary);
      case CardioSessionState.active: return _buildActiveSession(primary);
      case CardioSessionState.rpeCheck: return _buildRpeCheck(primary);
      case CardioSessionState.resting: return _buildResting(primary);
      case CardioSessionState.summary: return _buildSummary(primary);
    }
  }

  Widget _buildCalibration(Color primary) {
    return Column(
      children: [
        // 🚨 MODE TOGGLE
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _useCamera = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: _useCamera ? primary.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text("AI Camera", style: TextStyle(color: _useCamera ? primary : Colors.white70, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _useCamera = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: !_useCamera ? primary.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text("Animation", style: TextStyle(color: !_useCamera ? primary : Colors.white70, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 🚨 WORKOUT SELECTOR CHIPS 🚨
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _modes.keys.map((m) {
              final isSelected = _currentMode == m;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ChoiceChip(
                  label: Text(m),
                  selected: isSelected,
                  onSelected: (val) => _changeMode(m),
                  selectedColor: primary.withOpacity(0.15),
                  backgroundColor: Colors.white.withOpacity(0.03),
                  side: BorderSide(color: isSelected ? primary.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  labelStyle: TextStyle(color: isSelected ? primary : Colors.white.withOpacity(0.6), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),

        if (_useCamera) ...[
          if (_cameraController?.value.isInitialized == true)
            Container(
              height: 160, width: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orangeAccent, width: 4)),
              child: ClipOval(child: Transform.scale(scaleX: -1, child: CameraPreview(_cameraController!))),
            ),
          const SizedBox(height: 24),
          const Text("Align Camera", style: TextStyle(fontSize: 24, color: Colors.orangeAccent)),
          const SizedBox(height: 16),
          const Text("Step back until your entire body\n(Head to ankles) is visible.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: Colors.orangeAccent),
        ] else ...[
          Icon(Icons.animation, size: 80, color: primary.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text("$_currentMode", style: const TextStyle(fontSize: 24, color: Colors.white)),
          const SizedBox(height: 16),
          const Text("Follow the stick figure's tempo.\nReps will be counted automatically.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 40),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _startAnimationMode,
              child: const Text("Start Workout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
          )
        ]
      ],
    );
  }

  Widget _buildActiveSession(Color primary) {
    // Fake the live progress using ghost progress if camera is off
    double simulatedKneeAngle = 180.0 - (_ghostProgress * 90.0);

    return Column(
      children: [
        Text("Clinical $_currentMode", style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 28, color: Colors.white)),
        Text("Set $_currentSet of ${widget.prescription.sets}", style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),

        // BIOFEEDBACK ORB
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02), shape: BoxShape.circle,
              border: Border.all(color: primary.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: primary.withOpacity(0.05), blurRadius: 40)]
          ),
          child: SizedBox(
            height: 220, width: 220,
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_useCamera && _cameraController?.value.isInitialized == true)
                    Transform.scale(scaleX: -1, child: CameraPreview(_cameraController!)),

                  AnimatedBuilder(
                    animation: _ghostController,
                    builder: (context, child) => CustomPaint(
                      painter: _ClinicalPacerPainter(
                        mode: _currentMode,
                        repCount: _completedReps,
                        ghostProgress: _ghostProgress,
                        liveProgress: _useCamera ? _liveKneeAngle : simulatedKneeAngle,
                        primaryColor: primary,
                        useCamera: _useCamera,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMetricBox("Tempo", "${_modes[_currentMode]!.eccentricMs~/1000}-${_modes[_currentMode]!.isometricMs~/1000}-${_modes[_currentMode]!.concentricMs~/1000}", Colors.white54),
            _buildMetricBox("Reps", "$_completedReps / ${widget.prescription.targetReps}", primary),
          ],
        ),
        const SizedBox(height: 32),

        if (_useCamera && !_isPoseDetected)
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Text("⚠️ POSE LOST: Step back into frame", style: TextStyle(color: Colors.redAccent))),
      ],
    );
  }

  Widget _buildRpeCheck(Color primary) {
    double localRpe = 3;
    return StatefulBuilder(
        builder: (context, setLocalState) {
          return Column(
            children: [
              const Text("Safety Check", style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, color: Colors.white)),
              const SizedBox(height: 16),
              const Text("Borg Rate of Perceived Exertion\nHow hard was that set?", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 40),
              Text(localRpe.toStringAsFixed(0), style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: localRpe >= widget.prescription.maxSafeRpe ? Colors.redAccent : primary)),
              Text(localRpe < 3 ? "Light" : localRpe < 5 ? "Moderate" : localRpe < 7 ? "Hard" : "Very Hard", style: TextStyle(color: Colors.white.withOpacity(0.5))),
              const SizedBox(height: 20),
              Slider(value: localRpe, min: 0, max: 10, divisions: 10, activeColor: localRpe >= widget.prescription.maxSafeRpe ? Colors.redAccent : primary, onChanged: (val) => setLocalState(() => localRpe = val)),
              const SizedBox(height: 40),
              ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => _submitRpeScore(localRpe), child: const Text("Continue"))
            ],
          );
        }
    );
  }

  Widget _buildResting(Color primary) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.favorite, size: 80, color: Colors.redAccent),
        const SizedBox(height: 24),
        const Text("Recovery Time", style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, color: Colors.white)),
        const SizedBox(height: 32),
        Text("00:${_restSecondsRemaining.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Text("Get ready for Set ${_currentSet + 1}", style: TextStyle(color: primary, fontSize: 18)),
      ],
    );
  }

  Widget _buildSummary(Color primary) {
    return Column(
      children: [
        Icon(Icons.check_circle, size: 80, color: primary),
        const SizedBox(height: 24),
        const Text("Therapy Complete", style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28, color: Colors.white)),
        const SizedBox(height: 40),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => Navigator.pop(context), child: const Text("Save & Exit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
      ],
    );
  }

  Widget _buildMetricBox(String label, String val, Color color) {
    return Column(children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)), const SizedBox(height: 4), Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color))]);
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
  final bool useCamera;

  _ClinicalPacerPainter({
    required this.mode,
    required this.repCount,
    required this.ghostProgress,
    required this.liveProgress,
    required this.primaryColor,
    required this.useCamera
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45; // Center Y

    // 1. Draw Ghost (Target Pacemaker)
    if (useCamera) {
      final ghostPaint = Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
      _drawBodyElements(canvas, cx, cy, ghostProgress, ghostPaint, true);
    }

    // 2. Draw Live User Body (Neon lines)
    double userProgress = (180.0 - liveProgress.clamp(90.0, 180.0)) / 90.0;

    final paint = Paint()..color = primaryColor..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = primaryColor..style = PaintingStyle.fill;

    // Draw full body if animation mode. If camera mode, only draw legs to avoid cluttering the face.
    if (!useCamera) {
      canvas.drawCircle(Offset(cx, cy - 80 + (mode == "Squats" ? userProgress * 50 : 0)), 20, fillPaint); // Head
      canvas.drawLine(Offset(cx, cy - 60 + (mode == "Squats" ? userProgress * 50 : 0)), Offset(cx, cy + (mode == "Squats" ? userProgress * 50 : 0)), paint..strokeWidth = 8); // Spine
    }

    _drawBodyElements(canvas, cx, cy, userProgress, paint, false);
  }

  void _drawBodyElements(Canvas canvas, double cx, double cy, double p, Paint paint, bool isGhost) {
    double offsetY = 0.0;
    double legSpread = 0.0;
    double kneeBend = 0.0;
    bool isLunge = mode == "Lunges";
    double backKneeDrop = 0.0;

    // Movement Math
    if (mode == "Jumping Jacks" || mode == "High Knees") {
      offsetY = -(p * 40);
      legSpread = mode == "Jumping Jacks" ? p * 40 : 0;
    } else if (isLunge) {
      offsetY = p * 50;
      backKneeDrop = p * 40;
    } else {
      // Squat
      offsetY = p * 50;
      legSpread = p * 10;
      kneeBend = p * 35;
    }

    // ARMS (Only draw arms if full body animation mode)
    if (!useCamera || isGhost) {
      double armLift = (isLunge || mode == "Squats") ? (p * 40) : (p * 80);
      canvas.drawLine(Offset(cx - 25, cy - 50 + offsetY), Offset(cx - 40, cy + 10 + offsetY - armLift), paint);
      canvas.drawLine(Offset(cx + 25, cy - 50 + offsetY), Offset(cx + 40, cy + 10 + offsetY - armLift), paint);
    }

    // LEGS
    if (isLunge) {
      bool leftLegForward = repCount % 2 == 0;

      void drawForwardLeg(double dir) {
        canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + (30 * dir), cy + 50 + offsetY), paint); // Thigh
        canvas.drawLine(Offset(cx + (30 * dir), cy + 50 + offsetY), Offset(cx + (30 * dir), cy + 110), paint); // Shin
      }
      void drawBackLeg(double dir) {
        canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + (20 * dir), cy + 50 + offsetY + backKneeDrop), paint);
        canvas.drawLine(Offset(cx + (20 * dir), cy + 50 + offsetY + backKneeDrop), Offset(cx + (40 * dir), cy + 100), paint);
      }

      if (leftLegForward) { drawForwardLeg(-1.0); drawBackLeg(1.0); }
      else { drawBackLeg(-1.0); drawForwardLeg(1.0); }

    } else if (mode == "High Knees") {
      bool leftKneeUp = repCount % 2 == 0;
      // Planted Leg
      canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + (leftKneeUp ? 20 : -20), cy + 110), paint);
      // High Knee
      canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + (leftKneeUp ? -30 : 30), cy + 50 - (p * 30)), paint); // Thigh up
      canvas.drawLine(Offset(cx + (leftKneeUp ? -30 : 30), cy + 50 - (p * 30)), Offset(cx + (leftKneeUp ? -30 : 30), cy + 90), paint); // Shin down
    } else {
      // Squats & Jumping Jacks
      canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx - 20 - legSpread - kneeBend, cy + 50 + offsetY), paint); // L Thigh
      canvas.drawLine(Offset(cx - 20 - legSpread - kneeBend, cy + 50 + offsetY), Offset(cx - 20 - legSpread, cy + 110), paint); // L Shin

      canvas.drawLine(Offset(cx, cy + offsetY), Offset(cx + 20 + legSpread + kneeBend, cy + 50 + offsetY), paint); // R Thigh
      canvas.drawLine(Offset(cx + 20 + legSpread + kneeBend, cy + 50 + offsetY), Offset(cx + 20 + legSpread, cy + 110), paint); // R Shin
    }
  }

  @override
  bool shouldRepaint(covariant _ClinicalPacerPainter old) => true;
}