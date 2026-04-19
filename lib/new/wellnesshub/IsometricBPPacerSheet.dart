import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pure_shift/core/utils/wellness_audio_service.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class IsometricBPPacerSheet extends StatefulWidget {
  const IsometricBPPacerSheet({super.key});

  @override
  State<IsometricBPPacerSheet> createState() => _IsometricBPPacerSheetState();
}

class _IsometricBPPacerSheetState extends State<IsometricBPPacerSheet> with TickerProviderStateMixin {
  final _audio = WellnessAudioService();
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isProcessing = false;
  bool _isActive = false;

  double _currentKneeAngle = 180.0;
  int _holdSeconds = 120;
  Timer? _timer;

  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // 🚀 FIX: Start the pacer immediately on load for UI testing/calibration
    _breathController.repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first),
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
      _startTracking();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _startTracking() {
    _cameraController?.startImageStream((image) async {
      if (_isProcessing || !mounted) return;
      _isProcessing = true;
      try {
        final inputImage = InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation270deg,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
        final poses = await _poseDetector!.processImage(inputImage);
        if (poses.isNotEmpty) {
          final pose = poses.first;
          final hip = pose.landmarks[PoseLandmarkType.leftHip];
          final knee = pose.landmarks[PoseLandmarkType.leftKnee];
          final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];

          if (hip != null && knee != null && ankle != null) {
            setState(() {
              _currentKneeAngle = _calculateAngle(hip, knee, ankle);
            });
          }
        }
      } catch (e) {
        debugPrint("ML Error: $e");
      } finally { _isProcessing = false; }
    });
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    double ang = (atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x)) * 180 / pi;
    double result = ang.abs();
    return result > 180 ? 360 - result : result;
  }

  void _startSession() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isActive = true;
      _holdSeconds = 120;
    });
    _breathController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_holdSeconds > 0 && _isActive) {
        setState(() => _holdSeconds--);
        if (_holdSeconds <= 3) _audio.playTick();
      } else if (_holdSeconds == 0) {
        _stopSession();
        _showSuccessDialog();
      }
    });
  }

  void _stopSession() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    _breathController.stop();
    setState(() => _isActive = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathController.dispose();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    bool inZone = _currentKneeAngle >= 85 && _currentKneeAngle <= 100;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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

            // 🚀 STANDARD HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("VASCULAR TENSION", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text("Isometric BP Protocol", style: TextStyle(fontFamily: kBodyFont, color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w700)),
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

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildBiofeedbackOrb(inZone, cs.primary, theme),
                      const SizedBox(height: 32),
                      _buildStatusInfo(inZone, cs.primary, theme),
                      const SizedBox(height: 40),
                      _buildActionArea(cs.primary, theme),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiofeedbackOrb(bool inZone, Color primary, ThemeData theme) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🚀 FIX: Removed 'if (_isActive)' so the pacer is always visible
          ScaleTransition(
            scale: _breathAnimation,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Using primary color with low opacity for the pacer ring
                border: Border.all(color: primary.withOpacity(0.15), width: 1.5),
              ),
            ),
          ),

          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.cardColor,
              border: Border.all(
                  color: inZone ? Colors.greenAccent.withOpacity(0.5) : primary.withOpacity(0.2),
                  width: 2
              ),
            ),
            child: ClipOval(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_cameraController?.value.isInitialized == true)
                    Opacity(
                      opacity: 0.6,
                      child: Transform.scale(
                          scale: 1.5,
                          child: CameraPreview(_cameraController!)
                      ),
                    ),

                  CustomPaint(
                    size: const Size(160, 160),
                    painter: _BPIsometricPainter(
                      currentAngle: _currentKneeAngle,
                      primaryColor: primary,
                      inZone: inZone,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildStatusInfo(bool inZone, Color primary, ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.straighten_rounded, color: inZone ? Colors.greenAccent : theme.hintColor, size: 16),
            const SizedBox(width: 8),
            Text(
              "${_currentKneeAngle.toStringAsFixed(0)}°",
              style: TextStyle(
                  fontFamily: kDisplayFont,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: inZone ? Colors.greenAccent : theme.colorScheme.onSurface
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          inZone ? "OPTIMAL TENSION" : "SIT LOWER TO 90°",
          style: TextStyle(
              fontFamily: kDisplayFont,
              letterSpacing: 1.2,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: inZone ? Colors.greenAccent : theme.hintColor
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(Color primary, ThemeData theme) {
    if (!_isActive) {
      return SizedBox(
        width: double.infinity, height: 50,
        child: FilledButton(
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundColor: primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _startSession,
          child: const Text("START 2-MIN SESSION", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
      );
    } else {
      return Column(
        children: [
          Text(
            "${_holdSeconds ~/ 60}:${(_holdSeconds % 60).toString().padLeft(2, '0')}",
            style: TextStyle(fontFamily: kDisplayFont, fontSize: 40, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _stopSession,
            child: Text("STOP SESSION", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.error.withOpacity(0.8), letterSpacing: 1)),
          ),
        ],
      );
    }
  }

  void _showSuccessDialog() {
    _audio.playSuccess();
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Session Complete", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: Colors.greenAccent)),
        content: Text(
            "Hold complete. Stand up slowly to allow the vasodilation flush to occur.",
            style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: Theme.of(context).colorScheme.onSurface)
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Done", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700))
          )
        ],
      ),
    );
  }
}

class _BPIsometricPainter extends CustomPainter {
  final double currentAngle;
  final Color primaryColor;
  final bool inZone;

  _BPIsometricPainter({required this.currentAngle, required this.primaryColor, required this.inZone});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 3;

    final ghostPaint = Paint()..color = Colors.white.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    _drawLeg(canvas, cx, cy, 90, ghostPaint);

    final userPaint = Paint()
      ..color = inZone ? Colors.greenAccent : primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    _drawLeg(canvas, cx, cy, currentAngle, userPaint);
  }

  void _drawLeg(Canvas canvas, double cx, double cy, double angle, Paint paint) {
    double rad = angle * (pi / 180);
    Offset knee = Offset(cx, cy + 50);
    canvas.drawLine(Offset(cx, cy), knee, paint);

    double ankleX = cx + (50 * sin(pi - rad));
    double ankleY = cy + 50 + (50 * cos(pi - rad));
    canvas.drawLine(knee, Offset(ankleX, ankleY), paint);
  }

  @override
  bool shouldRepaint(covariant _BPIsometricPainter oldDelegate) => true;
}