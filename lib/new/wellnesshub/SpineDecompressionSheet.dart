import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SpineDecompressionSheet extends StatefulWidget {
  const SpineDecompressionSheet({super.key});
  @override
  State<SpineDecompressionSheet> createState() => _SpineDecompressionSheetState();
}

class _SpineDecompressionSheetState extends State<SpineDecompressionSheet> {
  double _pelvicAngle = 180.0;

  @override
  Widget build(BuildContext context) {
    bool isCompressed = _pelvicAngle < 165; // High tilt
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text("Lumbar Decompression", style: TextStyle(fontSize: 22, color: Colors.white)),
          const SizedBox(height: 40),
          Icon(Icons.straighten, size: 80, color: isCompressed ? Colors.redAccent : Colors.greenAccent),
          const SizedBox(height: 30),
          Text(isCompressed ? "Pelvic Tilt Detected" : "Spine Aligned", style: TextStyle(fontSize: 20, color: isCompressed ? Colors.redAccent : Colors.greenAccent)),
          const SizedBox(height: 10),
          const Text("Stand sideways to the camera. Tuck your tailbone until the icon turns green.", textAlign: TextAlign.center),
        ],
      ),
    );
  }
}