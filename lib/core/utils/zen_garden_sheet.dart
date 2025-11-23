import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_audio_service.dart';

class ZenGardenSheet extends StatefulWidget {
  const ZenGardenSheet({super.key});

  @override
  State<ZenGardenSheet> createState() => _ZenGardenSheetState();
}

class _ZenGardenSheetState extends State<ZenGardenSheet> {
  List<Offset?> points = [];
  final _audio = WellnessAudioService();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(color: Color(0xFFE6D7B9), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(20), child: Text("Zen Garden (Drag to Rake)", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold))),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  RenderBox box = context.findRenderObject() as RenderBox;
                  points.add(box.globalToLocal(details.globalPosition));
                });
                // 🎯 Drag Haptic (Grainy feel)
                _audio.hapticLight();
              },
              onPanEnd: (_) => points.add(null),
              child: CustomPaint(
                painter: _SandPainter(points),
                size: Size.infinite,
              ),
            ),
          ),
          TextButton(onPressed: () => setState(() => points.clear()), child: const Text("Smooth Sand", style: TextStyle(color: Colors.brown))),
        ],
      ),
    );
  }
}

class _SandPainter extends CustomPainter {
  final List<Offset?> points;
  _SandPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.brown.withOpacity(0.3)..strokeCap = StrokeCap.round..strokeWidth = 20.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _SandPainter old) => true;
}