import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class VagusNerveResetSheet extends StatefulWidget {
  const VagusNerveResetSheet({super.key});
  @override
  State<VagusNerveResetSheet> createState() => _VagusNerveResetSheetState();
}

class _VagusNerveResetSheetState extends State<VagusNerveResetSheet> {
  CameraController? _controller;
  FaceDetector _detector = FaceDetector(options: FaceDetectorOptions(enableClassification: true, enableLandmarks: true));
  String _status = "Align Face";
  bool _isReseting = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final cams = await availableCameras();
    _controller = CameraController(cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front), ResolutionPreset.low);
    await _controller!.initialize();
    _controller!.startImageStream((img) async {
      final input = InputImage.fromBytes(bytes: img.planes[0].bytes, metadata: InputImageMetadata(size: Size(img.width.toDouble(), img.height.toDouble()), rotation: InputImageRotation.rotation270deg, format: InputImageFormat.nv21, bytesPerRow: img.planes[0].bytesPerRow));
      final faces = await _detector.processImage(input);
      if (faces.isNotEmpty) {
        final f = faces.first;
        // Head must be straight (Euler Y < 10)
        bool headStraight = f.headEulerAngleY!.abs() < 10;
        setState(() {
          if (!headStraight) _status = "Keep Head Still";
          else _status = "Shift Eyes to Right";
        });
      }
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text("Vagus Nerve Reset", style: TextStyle(fontSize: 22, color: Colors.white)),
          const SizedBox(height: 30),
          if (_controller != null) SizedBox(height: 150, width: 150, child: ClipOval(child: CameraPreview(_controller!))),
          const SizedBox(height: 30),
          Text(_status, style: const TextStyle(fontSize: 18, color: Colors.cyan)),
          const SizedBox(height: 20),
          const Text("Keep head neutral and look to the far right for 60s.", textAlign: TextAlign.center),
        ],
      ),
    );
  }
}