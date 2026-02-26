import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

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

  // Breathing Pacer Animation
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4s Inhale, 4s Exhale
    );
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front),
      ResolutionPreset.low,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
    _startTracking();
    if (mounted) setState(() {});
  }

  void _startTracking() {
    _cameraController?.startImageStream((image) async {
      if (_isProcessing) return;
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
            if (mounted) {
              setState(() {
                _currentKneeAngle = _calculateAngle(hip, knee, ankle);
              });
            }
          }
        }
      } finally { _isProcessing = false; }
    });
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    double ang = (atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x)) * 180 / pi;
    double result = ang.abs();
    return result > 180 ? 360 - result : result;
  }

  void _startSession() {
    setState(() {
      _isActive = true;
      _holdSeconds = 120;
    });
    _breathController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_holdSeconds > 0 && _isActive) {
        setState(() => _holdSeconds--);
      } else if (_holdSeconds == 0) {
        _stopSession();
        _showSuccessDialog();
      }
    });
  }

  void _stopSession() {
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
    final primary = Theme.of(context).colorScheme.primary;
    bool inZone = _currentKneeAngle >= 85 && _currentKneeAngle <= 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),

          // 🎯 THE ANIMATED BIOFEEDBACK ORB
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Breathing Guide (Outer Pulsing Ring)
                if (_isActive)
                  ScaleTransition(
                    scale: _breathAnimation,
                    child: Container(
                      width: 240, height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 2),
                      ),
                    ),
                  ),

                // Main Container
                Container(
                  height: 220, width: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: inZone ? Colors.greenAccent : primary.withOpacity(0.2),
                        width: 2
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_cameraController?.value.isInitialized == true)
                        ClipOval(child: SizedBox(width: 210, height: 210, child: CameraPreview(_cameraController!))),

                      CustomPaint(
                        size: const Size(180, 180),
                        painter: _BPIsometricPainter(
                          currentAngle: _currentKneeAngle,
                          primaryColor: primary,
                          inZone: inZone,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildStatusInfo(inZone, primary),
          const SizedBox(height: 40),
          _buildActionArea(primary),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text("Hypertension Hold", style: TextStyle(fontFamily: 'Playfair Display', fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          _isActive ? "Keep Breathing Smoothly" : "Align sideways to the camera",
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(bool inZone, Color primary) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎯 Fixed: lowercase 's' for straighten
            Icon(Icons.straighten, color: inZone ? Colors.greenAccent : Colors.white24, size: 20),
            const SizedBox(width: 8),
            Text(
              "${_currentKneeAngle.toStringAsFixed(0)}°",
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: inZone ? Colors.greenAccent : Colors.white
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          inZone ? "OPTIMAL TENSION" : "SIT LOWER TO 90°",
          style: TextStyle(
              letterSpacing: 1.2,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: inZone ? Colors.greenAccent : Colors.white38
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(Color primary) {
    if (!_isActive) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: _startSession,
        child: const Text("START 2-MIN SESSION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      );
    } else {
      return Column(
        children: [
          Text(
            "${_holdSeconds ~/ 60}:${(_holdSeconds % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w300, color: Colors.white, letterSpacing: 4),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _stopSession,
            child: Text("STOP SESSION", style: TextStyle(color: Colors.redAccent.withOpacity(0.7), letterSpacing: 1)),
          ),
        ],
      );
    }
  }

  void _showSuccessDialog() {
    _audio.playSuccess();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text("Session Complete", style: TextStyle(color: Colors.greenAccent)),
        content: const Text("Great hold! Stand up slowly and remain still for 30 seconds to allow the vasodilation flush to occur.", style: TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
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

    final ghostPaint = Paint()..color = Colors.white10..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    _drawLeg(canvas, cx, cy, 90, ghostPaint);

    final userPaint = Paint()
      ..color = inZone ? Colors.greenAccent : primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = inZone ? const MaskFilter.blur(BlurStyle.normal, 10) : null;

    _drawLeg(canvas, cx, cy, currentAngle, userPaint);
  }

  void _drawLeg(Canvas canvas, double cx, double cy, double angle, Paint paint) {
    double rad = angle * (pi / 180);
    Offset knee = Offset(cx, cy + 60);
    canvas.drawLine(Offset(cx, cy), knee, paint); // Thigh

    double ankleX = cx + (60 * sin(pi - rad));
    double ankleY = cy + 60 + (60 * cos(pi - rad));
    canvas.drawLine(knee, Offset(ankleX, ankleY), paint); // Shin
  }

  @override
  bool shouldRepaint(covariant _BPIsometricPainter oldDelegate) => true;
}