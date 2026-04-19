import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class BiometricScannerSheet extends StatefulWidget {
  final List<CameraDescription> cameras;
  const BiometricScannerSheet({super.key, required this.cameras});

  @override
  State<BiometricScannerSheet> createState() => _BiometricScannerSheetState();
}

class _BiometricScannerSheetState extends State<BiometricScannerSheet> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isScanning = false;

  final List<double> _waveform = [];
  int _bpm = 0;
  String _scanStatus = "Place index finger over the rear camera and flash.";

  DateTime? _lastBeatTime;
  final List<int> _beatIntervals = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final rearCamera = widget.cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(rearCamera, ResolutionPreset.low, enableAudio: false);

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.torch);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _startScan() {
    if (_isScanning || _cameraController == null) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isScanning = true;
      _waveform.clear();
      _beatIntervals.clear();
      _bpm = 0;
      _scanStatus = "Calibrating optical sensor... Hold still.";
    });

    int frameCount = 0;
    _cameraController!.startImageStream((CameraImage image) {
      frameCount++;
      if (frameCount % 3 != 0) return;
      _processImageFrame(image);
    });

    Future.delayed(const Duration(seconds: 30), _stopScan);
  }

  void _processImageFrame(CameraImage image) {
    if (!mounted || !_isScanning) return;

    final int width = image.width;
    final int height = image.height;
    final int centerOffset = (height ~/ 2) * width + (width ~/ 2);

    double totalLuminance = 0;
    int samples = 0;
    for (int i = -5; i < 5; i++) {
      for (int j = -5; j < 5; j++) {
        int index = centerOffset + (i * width) + j;
        if (index > 0 && index < image.planes[0].bytes.length) {
          totalLuminance += image.planes[0].bytes[index];
          samples++;
        }
      }
    }

    double avgLuminance = totalLuminance / samples;

    if (avgLuminance > 200 || avgLuminance < 10) {
      setState(() {
        _scanStatus = "Finger not detected. Cover completely.";
        _waveform.add(0.0);
      });
      return;
    }

    setState(() {
      _scanStatus = "Acquiring PPG Signal... Relax hand.";
      _waveform.add(avgLuminance);
      if (_waveform.length > 50) _waveform.removeAt(0);

      if (_waveform.length > 3) {
        double prev = _waveform[_waveform.length - 2];
        double current = _waveform.last;

        if (prev > current + 1.5) {
          DateTime now = DateTime.now();
          if (_lastBeatTime != null) {
            int difference = now.difference(_lastBeatTime!).inMilliseconds;
            if (difference > 300 && difference < 1500) {
              _beatIntervals.add(difference);
              if (_beatIntervals.length > 10) _beatIntervals.removeAt(0);
              double avgInterval = _beatIntervals.reduce((a, b) => a + b) / _beatIntervals.length;
              _bpm = (60000 / avgInterval).round();
              HapticFeedback.selectionClick();
            }
          }
          _lastBeatTime = now;
        }
      }
    });
  }

  Future<void> _stopScan() async {
    if (!_isScanning) return;
    await _cameraController?.stopImageStream();
    HapticFeedback.heavyImpact();

    if (mounted) {
      setState(() {
        _isScanning = false;
        _scanStatus = _bpm > 0 ? "Scan Complete. Data logged." : "Scan failed. Try again.";
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.setFlashMode(FlashMode.off);
    _cameraController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32))
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: !_isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                        Text("BIOMETRIC TELEMETRY", style: TextStyle(fontFamily: kDisplayFont, color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text("Optical HRV Scanner", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 12, fontWeight: FontWeight.w600)),
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 🎯 STATUS BOX
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.primary.withOpacity(0.1))
                      ),
                      child: Text(_scanStatus, textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, color: cs.primary, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),

                    const Spacer(),

                    // 🎯 LIVE HEART RATE DISPLAY
                    Text("HEART RATE", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 2)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // 🚀 REFINED BPM FOCAL NUMBER (Capped at 48)
                        Text(_bpm > 0 ? "$_bpm" : "--", style: TextStyle(fontFamily: kDisplayFont, fontSize: 48, fontWeight: FontWeight.w700, color: cs.primary)),
                        const SizedBox(width: 4),
                        Text("BPM", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, color: theme.hintColor)),
                      ],
                    ),

                    const Spacer(),

                    // 🎯 CLINICAL LIVE WAVEFORM
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: _WaveformPainter(data: _waveform, color: cs.primary),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // 🎯 ACTION CONTROLS
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _isScanning ? _stopScan : _startScan,
                        icon: Icon(_isScanning ? Icons.stop_rounded : Icons.fingerprint_rounded, size: 18),
                        label: Text(_isScanning ? "ABORT SCAN" : "INITIALIZE SCAN", style: const TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _isScanning ? theme.colorScheme.error.withOpacity(0.8) : cs.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _WaveformPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    double minVal = data.reduce((a, b) => a < b ? a : b);
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    double range = maxVal - minVal;
    if (range < 1) range = 1;

    double stepX = size.width / 50;

    for (int i = 0; i < data.length; i++) {
      double normalizedY = (data[i] - minVal) / range;
      double y = size.height - (normalizedY * size.height * 0.7) - (size.height * 0.15);
      double x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => true;
}