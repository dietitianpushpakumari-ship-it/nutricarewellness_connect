import 'dart:math';
import 'package:flutter/material.dart';

// Simple database of tips (In production, fetch this from your Library Provider)
const Map<String, List<String>> _contextualTips = {
  'nutrition': [
    "Tip: Walking for 10 mins after a meal curbs blood sugar spikes.",
    "Tip: Eating protein first helps you feel full faster.",
    "Tip: Chew your food 20 times to improve digestion."
  ],
  'hydration': [
    "Fact: Thirst is often mistaken for hunger. Drink water first!",
    "Tip: Cold water may boost metabolism slightly.",
    "Fact: Even mild dehydration causes fatigue."
  ],
  'sleep': [
    "Tip: Avoid blue light (screens) 1 hour before bed.",
    "Fact: Deep sleep repairs muscles and tissues.",
    "Tip: Keep your room cool (around 18°C) for better sleep."
  ]
};

void showContextualSuccessDialog(BuildContext context, String category) {
  final tips = _contextualTips[category] ?? _contextualTips['nutrition']!;
  final randomTip = tips[Random().nextInt(tips.length)];

  showDialog(
    context: context,
    barrierDismissible: false, // Force them to read (briefly)
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 10),
          Text("Saved!"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text("While you're here...", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(randomTip, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("Got it"),
        )
      ],
    ),
  );
}