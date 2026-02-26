import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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

  // Clinical Data
  final List<double> _waveform = [];
  int _bpm = 0;
  String _scanStatus = "Place index finger over the rear camera and flash.";
  double _currentRedness = 0.0;

  // Peak Detection (HR calculation)
  DateTime? _lastBeatTime;
  final List<int> _beatIntervals = [];

  // Animation for the "Scanning" Ring
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Find the rear camera
    final rearCamera = widget.cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    // Use ResolutionPreset.low to save Redmi 8 CPU power
    _cameraController = CameraController(rearCamera, ResolutionPreset.low, enableAudio: false);

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.torch); // Turn on Flashlight

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _startScan() {
    if (_isScanning || _cameraController == null) return;

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
      // Process every 3rd frame to save CPU on older Androids (approx 10 FPS)
      if (frameCount % 3 != 0) return;

      _processImageFrame(image);
    });

    // Auto-stop after 30 seconds of data collection
    Future.delayed(const Duration(seconds: 30), _stopScan);
  }

  void _processImageFrame(CameraImage image) {
    if (!mounted || !_isScanning) return;

    // 1. Extract Light Intensity (Redness/Luminance)
    // In YUV420, plane 0 is Luminance (brightness). When a finger covers the lens and flash,
    // the blood volume changes the overall brightness of the red-tinted frame.
    final int width = image.width;
    final int height = image.height;
    final int centerOffset = (height ~/ 2) * width + (width ~/ 2);

    // Sample a small 10x10 grid in the center to avoid processing 100,000+ pixels
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

    // 2. Detect Finger Presence
    // If it's too bright, the finger isn't fully covering the flash/lens
    if (avgLuminance > 200 || avgLuminance < 10) {
      setState(() {
        _scanStatus = "Finger not detected. Cover the lens and flash completely.";
        _waveform.add(0.0);
      });
      return;
    }

    // 3. Peak Detection (Heartbeat)
    setState(() {
      _scanStatus = "Acquiring PPG Signal... Relax your hand.";
      _currentRedness = avgLuminance;

      // Keep the waveform graph moving (store last 50 points)
      _waveform.add(avgLuminance);
      if (_waveform.length > 50) _waveform.removeAt(0);

      // Simple threshold peak detection for the demo
      // In a strict clinical app, this would use a bandpass filter
      if (_waveform.length > 3) {
        double prev = _waveform[_waveform.length - 2];
        double current = _waveform.last;

        // If the signal goes down (systole blocks light), it's a beat
        if (prev > current + 1.5) {
          DateTime now = DateTime.now();
          if (_lastBeatTime != null) {
            int difference = now.difference(_lastBeatTime!).inMilliseconds;
            // Human physical limits (40 BPM to 200 BPM)
            if (difference > 300 && difference < 1500) {
              _beatIntervals.add(difference);
              if (_beatIntervals.length > 10) _beatIntervals.removeAt(0);

              // Calculate average BPM
              double avgInterval = _beatIntervals.reduce((a, b) => a + b) / _beatIntervals.length;
              _bpm = (60000 / avgInterval).round();
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

    if (mounted) {
      setState(() {
        _isScanning = false;
        _scanStatus = _bpm > 0 ? "Scan Complete. Data logged." : "Scan failed. Please try again.";
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
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                      Text("BIOMETRIC TELEMETRY", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text("Optical HRV Scanner", style: TextStyle(color: theme.hintColor, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor), onPressed: () => Navigator.pop(context))
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary.withOpacity(0.1))),
                    child: Text(_scanStatus, textAlign: TextAlign.center, style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),

                  const Spacer(),

                  // 🎯 LIVE HEART RATE DISPLAY
                  Text("HEART RATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.hintColor, letterSpacing: 2)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(_bpm > 0 ? "$_bpm" : "--", style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: cs.primary, letterSpacing: -2)),
                      const SizedBox(width: 8),
                      Text("BPM", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.hintColor)),
                    ],
                  ),

                  const Spacer(),

                  // 🎯 CLINICAL LIVE WAVEFORM (Custom Painter)
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.2), blurRadius: 20)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                        painter: _WaveformPainter(data: _waveform, color: Colors.greenAccent),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 🎯 ACTION CONTROLS
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isScanning ? _stopScan : _startScan,
                      icon: Icon(_isScanning ? Icons.stop_rounded : Icons.fingerprint_rounded),
                      label: Text(_isScanning ? "ABORT SCAN" : "INITIALIZE SCAN"),
                      style: FilledButton.styleFrom(
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
    );
  }
}

// 🎯 CLINICAL ECG/PPG PAINTER
class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _WaveformPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Auto-scale the graph based on the current data limits
    double minVal = data.reduce((a, b) => a < b ? a : b);
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    double range = maxVal - minVal;
    if (range < 1) range = 1; // Prevent division by zero

    double stepX = size.width / 50; // We keep 50 points

    for (int i = 0; i < data.length; i++) {
      // Normalize data between 0 and 1, then scale to height
      double normalizedY = (data[i] - minVal) / range;
      double y = size.height - (normalizedY * size.height * 0.8) - (size.height * 0.1);
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