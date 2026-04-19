import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

// ============================================================================
// 1. CLINICAL MODELS
// ============================================================================
class ClinicalPrescription {
  final int sets;
  final int holdTimeSeconds;
  final double targetRomAngle;
  final int maxSafePainLevel;

  const ClinicalPrescription({
    this.sets = 3,
    this.holdTimeSeconds = 15,
    this.targetRomAngle = 45.0,
    this.maxSafePainLevel = 6,
  });
}

class SessionAuditLog {
  int prePainLevel = 0;
  int postPainLevel = 0;
  double maxRomAchieved = 0.0;
  bool completedAllSets = false;
}

enum ClinicalSessionState { preAssessment, calibrating, active, resting, postAssessment, summary }

// ============================================================================
// 2. MAIN WIDGET
// ============================================================================
class NeckWristSheet extends StatefulWidget {
  final bool isNeck;
  final ClinicalPrescription prescription;

  const NeckWristSheet({
    super.key,
    required this.isNeck,
    this.prescription = const ClinicalPrescription(),
  });

  @override
  State<NeckWristSheet> createState() => _NeckWristSheetState();
}

class _NeckWristSheetState extends State<NeckWristSheet> with SingleTickerProviderStateMixin {
  ClinicalSessionState _currentState = ClinicalSessionState.preAssessment;
  final SessionAuditLog _auditLog = SessionAuditLog();

  // 🚨 SENSOR ENGINES & CALIBRATION STATE 🚨
  StreamSubscription<AccelerometerEvent>? _wristSubscription;
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isProcessingImage = false;

  bool _isPoseDetected = false;
  int _calibrationSeconds = 3;
  Timer? _calibrationTimer;

  double _baselineAngle = 0.0;
  double _liveSensorAngle = 0.0;

  late int _currentSet;
  late int _secondsRemaining;
  Timer? _timer;

  late AnimationController _animController;
  final _audio = WellnessAudioService();

  @override
  void initState() {
    super.initState();
    _currentSet = 1;
    _secondsRemaining = widget.prescription.holdTimeSeconds;
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

    if (widget.isNeck) _initializeAICamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _calibrationTimer?.cancel();
    _wristSubscription?.cancel();
    _cameraController?.dispose();
    _poseDetector?.close();
    _animController.dispose();
    super.dispose();
  }

// ============================================================================
// AI CAMERA ENGINE (For Neck)
// ============================================================================
  Future<void> _initializeAICamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
      final format = Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420;

      _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.low,
          enableAudio: false,
          imageFormatGroup: format
      );

      await _cameraController!.initialize();
      _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("❌ Camera Error: $e");
    }
  }

  void _startNeckTracking() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingImage || _currentState == ClinicalSessionState.resting) return;
      _isProcessingImage = true;

      try {
        final sensorOrientation = _cameraController!.description.sensorOrientation;
        final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation270deg;

        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
        final inputFormat = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;

        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: imageSize,
            rotation: rotation,
            format: inputFormat,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        final poses = await _poseDetector!.processImage(inputImage);

        if (poses.isNotEmpty) {
          final pose = poses.first;
          final nose = pose.landmarks[PoseLandmarkType.nose];
          final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
          final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

          if (nose != null && leftShoulder != null && rightShoulder != null) {
            double midX = (leftShoulder.x + rightShoulder.x) / 2;
            double midY = (leftShoulder.y + rightShoulder.y) / 2;

            double dx = nose.x - midX;
            double dy = nose.y - midY;
            double rawAngle = (atan2(dy, dx) * 180 / pi) + 90;

            if (_currentState == ClinicalSessionState.calibrating) {
              if (mounted) {
                _baselineAngle = rawAngle;
                if (!_isPoseDetected) {
                  HapticFeedback.mediumImpact();
                  setState(() => _isPoseDetected = true);
                  _startCalibrationCountdown();
                }
              }
            } else if (_currentState == ClinicalSessionState.active) {
              if (mounted) {
                setState(() {
                  double targetAngle = rawAngle - _baselineAngle;
                  _liveSensorAngle = (_liveSensorAngle * 0.8) + (targetAngle * 0.2);
                  _updateMaxRom();
                });
              }
            }
          } else {
            _handlePoseLost();
          }
        } else {
          _handlePoseLost();
        }
      } catch (e) {
        debugPrint("❌ ML Kit Error: $e");
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  void _handlePoseLost() {
    if (_currentState == ClinicalSessionState.calibrating && _isPoseDetected) {
      if (mounted) {
        setState(() {
          _isPoseDetected = false;
          _calibrationSeconds = 3;
        });
        _calibrationTimer?.cancel();
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _startCalibrationCountdown() {
    _calibrationTimer?.cancel();
    _calibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _currentState == ClinicalSessionState.calibrating) {
        if (_calibrationSeconds > 1) {
          setState(() => _calibrationSeconds--);
          _audio.playSuccess();
          HapticFeedback.selectionClick();
        } else {
          timer.cancel();
          _startActiveSet();
        }
      } else {
        timer.cancel();
      }
    });
  }

  // ============================================================================
  // CLINICAL STATE MACHINE LOGIC
  // ============================================================================

  void _submitPreAssessment(int painLevel) async {
    HapticFeedback.lightImpact();
    _auditLog.prePainLevel = painLevel;
    if (painLevel >= widget.prescription.maxSafePainLevel) {
      _showSafetyAbortDialog();
    } else {
      setState(() {
        _currentState = ClinicalSessionState.calibrating;
        _calibrationSeconds = 3;
      });

      if (widget.isNeck) {
        _startNeckTracking();
      } else {
        try {
          final event = await accelerometerEventStream().first.timeout(const Duration(seconds: 2));
          _baselineAngle = atan2(event.y, event.z) * (180 / pi);
        } catch (e) { _baselineAngle = 0.0; }

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _startActiveSet();
        });
      }
    }
  }

  void _startActiveSet() {
    HapticFeedback.heavyImpact();
    _audio.playSuccess();
    setState(() {
      _currentState = ClinicalSessionState.active;
      _secondsRemaining = widget.prescription.holdTimeSeconds;
    });
    _startTimer();

    if (!widget.isNeck) _startWristTracking();
  }

  void _startWristTracking() {
    _wristSubscription?.cancel();
    _wristSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (mounted && _currentState == ClinicalSessionState.active) {
        double pitchRadians = atan2(event.y, event.z);
        double rawDegrees = pitchRadians * (180 / pi);
        double currentAngle = rawDegrees - _baselineAngle;

        setState(() {
          _liveSensorAngle = (_liveSensorAngle * 0.85) + (currentAngle * 0.15);
          _updateMaxRom();
        });
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        _audio.playSuccess();
        HapticFeedback.heavyImpact();
        _handleSetComplete();
      }
    });
  }

  void _handleSetComplete() {
    if (_currentSet < widget.prescription.sets) {
      setState(() {
        _currentState = ClinicalSessionState.resting;
        _secondsRemaining = 10;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          t.cancel();
          setState(() => _currentSet++);
          _startActiveSet();
        }
      });
    } else {
      _cameraController?.stopImageStream();
      _wristSubscription?.cancel();
      _auditLog.completedAllSets = true;
      setState(() => _currentState = ClinicalSessionState.postAssessment);
    }
  }

  void _updateMaxRom() {
    if (_liveSensorAngle.abs() > _auditLog.maxRomAchieved) {
      _auditLog.maxRomAchieved = _liveSensorAngle.abs();
    }
  }

  void _submitPostAssessment(int painLevel) {
    HapticFeedback.lightImpact();
    _auditLog.postPainLevel = painLevel;
    setState(() => _currentState = ClinicalSessionState.summary);
  }

  void _showSafetyAbortDialog() {
    final theme = Theme.of(context);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.redAccent.withOpacity(0.5))),
          title: const Text("Session Aborted", style: TextStyle(fontFamily: kDisplayFont, color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text("Your pain level is too high today. Please rest.", style: TextStyle(fontFamily: kBodyFont, color: theme.colorScheme.onSurface, fontSize: 12)),
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
    final primaryColor = theme.colorScheme.primary;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1), width: 1),
      ),
      // 🚀 STRICT SAFE AREA HANDLING
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),

            // 🚀 STANDARD HEADER WITH CROSS BUTTON
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("CLINICAL ASSESSMENT", style: TextStyle(fontFamily: kDisplayFont, color: primaryColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(widget.isNeck ? "Cervical ROM Therapy" : "Carpal ROM Therapy", style: TextStyle(fontFamily: kBodyFont, color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 8),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0).copyWith(bottom: 24.0),
                child: _buildStateContent(theme, primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateContent(ThemeData theme, Color primary) {
    switch (_currentState) {
      case ClinicalSessionState.preAssessment: return _buildPainAssessment("Pre-Session Check", _submitPreAssessment, theme, primary);
      case ClinicalSessionState.calibrating: return _buildCalibration(theme, primary);
      case ClinicalSessionState.active:
      case ClinicalSessionState.resting: return _buildActiveSession(theme, primary);
      case ClinicalSessionState.postAssessment: return _buildPainAssessment("Post-Session Check", _submitPostAssessment, theme, primary);
      case ClinicalSessionState.summary: return _buildSummary(theme, primary);
    }
  }

  Widget _buildPainAssessment(String title, Function(int) onSubmit, ThemeData theme, Color primary) {
    int localPain = 0;
    return StatefulBuilder(
        builder: (context, setLocalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text("Scale: 0 (No Pain) to 10 (Severe Pain)", textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor)),
              const SizedBox(height: 40),

              Text(localPain.toString(), style: TextStyle(fontFamily: kDisplayFont, fontSize: 40, fontWeight: FontWeight.w700, color: localPain > 6 ? Colors.redAccent : primary)),
              const SizedBox(height: 20),

              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                child: Slider(
                  value: localPain.toDouble(), min: 0, max: 10, divisions: 10,
                  activeColor: localPain > 6 ? Colors.redAccent : primary,
                  inactiveColor: theme.dividerColor.withOpacity(0.1),
                  onChanged: (val) {
                    if (val.toInt() != localPain) HapticFeedback.selectionClick();
                    setLocalState(() => localPain = val.toInt());
                  },
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity, height: 50,
                child: FilledButton(
                    style: FilledButton.styleFrom(elevation: 0, backgroundColor: primary.withOpacity(0.15), foregroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () => onSubmit(localPain),
                    child: const Text("Continue", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5))
                ),
              )
            ],
          );
        }
    );
  }

  Widget _buildCalibration(ThemeData theme, Color primary) {
    return Column(
      children: [
        const SizedBox(height: 20),

        if (widget.isNeck && _cameraController?.value.isInitialized == true)
          Container(
            height: 160, width: 160,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _isPoseDetected ? Colors.greenAccent : Colors.orangeAccent, width: 4),
                boxShadow: _isPoseDetected ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 20)] : []
            ),
            child: ClipOval(
              child: Transform.scale(
                scaleX: -1,
                child: CameraPreview(_cameraController!),
              ),
            ),
          )
        else
          Icon(Icons.screen_rotation_rounded, size: 64, color: primary.withOpacity(0.5)),

        const SizedBox(height: 32),

        if (widget.isNeck) ...[
          if (_isPoseDetected) ...[
            const Text("Perfect Posture!", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, color: Colors.greenAccent, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text("Hold still... Starting in $_calibrationSeconds", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
          ] else ...[
            const Text("Align Camera", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orangeAccent)),
            const SizedBox(height: 12),
            Text("Prop your phone up on a table.\nStep back until your face and shoulders\nare clearly visible in the circle.",
                textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, height: 1.5)),
          ]
        ] else ...[
          Text("Calibrating Sensor...", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 12),
          Text("Hold your phone flat in your palm.\nKeep your hand perfectly still.",
              textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, height: 1.5)),
        ],

        const SizedBox(height: 40),
        if (!_isPoseDetected && widget.isNeck) const CircularProgressIndicator(color: Colors.orangeAccent),
      ],
    );
  }

  Widget _buildActiveSession(ThemeData theme, Color primary) {
    bool isResting = _currentState == ClinicalSessionState.resting;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.isNeck ? "Cervical ROM" : "Carpal ROM", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text("Set $_currentSet / ${widget.prescription.sets}", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, color: primary, fontWeight: FontWeight.w700))
            )
          ],
        ),
        const SizedBox(height: 32),

        // AUGMENTED REALITY ORB
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: isResting ? theme.dividerColor.withOpacity(0.1) : theme.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: isResting ? theme.dividerColor.withOpacity(0.1) : primary.withOpacity(0.3), width: 2),
              boxShadow: isResting ? [] : [BoxShadow(color: primary.withOpacity(0.05), blurRadius: 40)]
          ),
          child: SizedBox(
            height: 200, width: 200,
            child: isResting
                ? Center(child: Text("REST", style: TextStyle(fontFamily: kDisplayFont, fontSize: 24, color: theme.hintColor, fontWeight: FontWeight.w700)))
                : ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.isNeck && _cameraController?.value.isInitialized == true)
                    Transform.scale(
                      scaleX: -1,
                      child: CameraPreview(_cameraController!),
                    ),

                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) => CustomPaint(
                      painter: _MedicalStretchPainter(
                          isNeck: widget.isNeck,
                          pacemakerProgress: _animController.value,
                          primaryColor: primary,
                          hintColor: theme.hintColor,
                          liveHardwareAngle: _liveSensorAngle,
                          targetAngle: widget.prescription.targetRomAngle
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
            _buildMetricBox("Target", "±${widget.prescription.targetRomAngle}°", theme),
            _buildMetricBox("Live ROM", "${_liveSensorAngle.abs().toStringAsFixed(1)}°", theme, highlightColor: primary),
          ],
        ),
        const SizedBox(height: 32),

        Text(isResting ? "Resting..." : "Match the Target Angle", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor)),
        const SizedBox(height: 8),
        Text("00:${_secondsRemaining.toString().padLeft(2, '0')}", style: TextStyle(fontFamily: kDisplayFont, fontSize: 40, fontWeight: FontWeight.w700, color: isResting ? theme.hintColor : primary)),
      ],
    );
  }

  Widget _buildSummary(ThemeData theme, Color primary) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Icon(Icons.check_circle_rounded, size: 64, color: primary),
        const SizedBox(height: 24),
        Text("Session Complete", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 32),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Pain Change", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w500)),
                  Text("${_auditLog.prePainLevel} ➔ ${_auditLog.postPainLevel}", style: TextStyle(fontFamily: kDisplayFont, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14))
                ]),
                Divider(color: theme.dividerColor.withOpacity(0.1), height: 30),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Max ROM Achieved", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.w500)),
                  Text("${_auditLog.maxRomAchieved.toStringAsFixed(1)}°", style: TextStyle(fontFamily: kDisplayFont, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14))
                ]),
              ],
            )
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity, height: 50,
          child: FilledButton(
              style: FilledButton.styleFrom(elevation: 0, backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => Navigator.pop(context),
              child: const Text("Save & Exit", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5))
          ),
        )
      ],
    );
  }

  Widget _buildMetricBox(String label, String val, ThemeData theme, {Color? highlightColor}) {
    return Column(
        children: [
          Text(label, style: TextStyle(fontFamily: kBodyFont, fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: highlightColor ?? theme.colorScheme.onSurface))
        ]
    );
  }
}

// ============================================================================
// 3. AUGMENTED REALITY GONIOMETRY PAINTER
// ============================================================================
class _MedicalStretchPainter extends CustomPainter {
  final bool isNeck;
  final double pacemakerProgress;
  final double liveHardwareAngle;
  final Color primaryColor;
  final Color hintColor;
  final double targetAngle;

  _MedicalStretchPainter({
    required this.isNeck,
    required this.pacemakerProgress,
    required this.primaryColor,
    required this.hintColor,
    required this.liveHardwareAngle,
    required this.targetAngle
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Crosshair Guides
    final guidePaint = Paint()..color = hintColor.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), guidePaint);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), guidePaint);

    // 2. GHOST LINE (Target)
    final ghostAngle = (sin((pacemakerProgress - 0.5) * pi) * targetAngle) * (pi / 180);
    final ghostPaint = Paint()..color = hintColor.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;

    if (isNeck) {
      canvas.drawLine(Offset(cx, cy), Offset(cx + (sin(ghostAngle) * 80), cy - (cos(ghostAngle) * 80)), ghostPaint);
    } else {
      canvas.drawLine(Offset(cx, cy), Offset(cx + (50 * cos(ghostAngle)), cy + (50 * sin(ghostAngle))), ghostPaint);
    }

    // 3. SENSOR LINE (Real Body / Hardware Overlay)
    final hardwareRads = liveHardwareAngle * (pi / 180);
    final paint = Paint()..color = primaryColor..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;

    if (isNeck) {
      canvas.drawLine(Offset(cx, cy), Offset(cx + (sin(hardwareRads) * 80), cy - (cos(hardwareRads) * 80)), paint);
      canvas.drawCircle(Offset(cx, cy), 6, Paint()..color=primaryColor);
    } else {
      canvas.drawLine(Offset(cx - 50, cy), Offset(cx, cy), paint);
      canvas.drawLine(Offset(cx, cy), Offset(cx + (40 * cos(hardwareRads)), cy + (40 * sin(hardwareRads))), paint..strokeWidth = 8);
    }
  }

  @override
  bool shouldRepaint(covariant _MedicalStretchPainter old) => true;
}