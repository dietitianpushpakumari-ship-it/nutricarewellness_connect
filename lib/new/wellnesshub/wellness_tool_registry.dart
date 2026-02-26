import 'package:flutter/material.dart';
import 'package:nutricare_connect/core/utils/wellness_tool_model.dart';

class WellnessRegistry {
  static const List<WellnessTool> allTools = [
    // --- PHYSICAL (MOVE) ---
    WellnessTool(
      id: 'quickfit',
      title: 'QuickFit',
      subtitle: '7-Min HIIT',
      icon: Icons.fitness_center,
      color: Colors.deepOrange,
      category: WellnessCategory.physical,
      priority: 1, // High Priority
      routeKey: 'quickfit',
      activeHours: [6, 7, 8, 9, 17, 18, 19], // Morning/Evening
    ),
    WellnessTool(
      id: 'posture',
      title: 'Posture Fix',
      subtitle: 'Head Up',
      icon: Icons.smartphone,
      color: Colors.amber,
      category: WellnessCategory.physical,
      priority: 3,
      routeKey: 'posture',
      activeHours: [10, 11, 12, 13, 14, 15, 16], // Work hours
    ),
    WellnessTool(
      id: 'neck',
      title: 'Neck Relief',
      subtitle: 'Fix Stiffness',
      icon: Icons.person,
      color: Colors.purple,
      category: WellnessCategory.physical,
      priority: 4,
      routeKey: 'neck',
    ),
    WellnessTool(
      id: 'cardio',
      title: 'Cardio Beat',
      subtitle: 'Rhythm Pacer',
      icon: Icons.speed,
      color: Colors.red,
      category: WellnessCategory.physical,
      priority: 5,
      routeKey: 'cardio',
    ),
    WellnessTool(
      id: 'kegel',
      title: 'Kegel Trainer',
      subtitle: 'Core Strength',
      icon: Icons.accessibility_new,
      color: Colors.pink,
      category: WellnessCategory.physical,
      priority: 8,
      routeKey: 'kegel',
    ),
    WellnessTool(
      id: 'wrist',
      title: 'Wrist Relief',
      subtitle: 'Carpal Health',
      icon: Icons.gesture,
      color: Colors.blueGrey,
      category: WellnessCategory.physical,
      priority: 5,
      routeKey: 'wrist',
    ),
    WellnessTool(
      id: 'bp_hold',
      title: 'BP Pacer',
      subtitle: 'Isometric Hold',
      icon: Icons.bloodtype,
      color: Colors.redAccent,
      category: WellnessCategory.physical,
      priority: 2,
      routeKey: 'bp_hold',
    ),
    WellnessTool(
      id: 'glucose_pulse',
      title: 'Glucose Pulse',
      subtitle: 'Post-Meal Flow',
      icon: Icons.biotech,
      color: Colors.greenAccent,
      category: WellnessCategory.physical,
      priority: 2,
      routeKey: 'glucose_pulse',
    ),
    WellnessTool(
      id: 'balance',
      title: 'Balance Lock',
      subtitle: 'Neuro-Stability',
      icon: Icons.balance,
      color: Colors.cyan,
      category: WellnessCategory.physical,
      priority: 6,
      routeKey: 'balance',
    ),

    // --- MENTAL (CALM) ---
    WellnessTool(
      id: 'breath',
      title: 'Breathing',
      subtitle: 'Focus & Relax',
      icon: Icons.self_improvement,
      color: Colors.teal,
      category: WellnessCategory.mental,
      priority: 1, // Essential
      routeKey: 'breathing',
    ),
    WellnessTool(
      id: 'focus',
      title: 'Focus Grid',
      subtitle: 'Brain Gym',
      icon: Icons.grid_on,
      color: Colors.indigo,
      category: WellnessCategory.mental,
      priority: 4,
      routeKey: 'focus',
      activeHours: [9, 10, 11, 13, 14, 15], // Work hours
    ),
    WellnessTool(
      id: 'eye',
      title: 'Eye Yoga',
      subtitle: 'Vision Care',
      icon: Icons.visibility,
      color: Colors.blue,
      category: WellnessCategory.mental,
      priority: 5,
      routeKey: 'eye',
    ),
    WellnessTool(
      id: 'worry',
      title: 'Worry Shredder',
      subtitle: 'Let it go',
      icon: Icons.delete_forever,
      color: Colors.grey,
      category: WellnessCategory.mental,
      priority: 6,
      routeKey: 'worry',
    ),
    // 🎯 CALM & FOCUS ADDITIONS

    WellnessTool(
      id: 'emdr_pacer',
      title: 'Bilateral Pacer',
      subtitle: 'Rapid anxiety & panic relief',
      icon: Icons.sync_alt_rounded, // Perfect for side-to-side motion
      color: Colors.indigo, // Deep, calming clinical blue
      routeKey: 'emdr',
      priority: 7,
      category: WellnessCategory.mental,
    ),

    WellnessTool(
      id: 'stroop_test',
      title: 'Neuro-Focus',
      subtitle: 'Warm up your cognitive speed',
      icon: Icons.psychology_alt_rounded, // Brain/puzzle icon
      color: const Color(0xFFFFA000),// Energetic, alert color for focus
      priority: 8,
      routeKey: 'stroop',
      category: WellnessCategory.mental,
    ),

    WellnessTool(
      id: 'pomodoro_brainwave',
      title: 'Deep Work',
      subtitle: 'Timer with brainwave frequencies',
      icon: Icons.headphones_rounded, // Represents the audio entrainment
      color: Colors.teal, // Known for deep focus and productivity
      routeKey: 'pomodoro',
      priority: 9,
      category: WellnessCategory.mental,
    ),

    WellnessTool(
      id: 'eft_tapping',
      title: 'EFT Tapping',
      subtitle: 'Somatic stress & cortisol release',
      icon: Icons.touch_app_rounded, // Represents the physical tapping
      color: const Color(0xFFEC407A), // Soft, bodily-warmth color
      routeKey: 'eft_tapping',
      priority: 10,
      category: WellnessCategory.mental, // Can also go in 'spiritual' depending on your preference
    ),

    // --- SPIRITUAL & SLEEP ---
    WellnessTool(
      id: 'mantra',
      title: 'Mantra Japa',
      subtitle: 'Spiritual Sanctuary',
      icon: Icons.spa,
      color: Colors.orange,
      category: WellnessCategory.spiritual,
      priority: 1,
      routeKey: 'mantra',
    ),
    WellnessTool(
      id: 'geeta',
      title: 'Geeta Wisdom',
      subtitle: 'Divine Guide',
      icon: Icons.auto_stories,
      color: Colors.amberAccent,
      category: WellnessCategory.spiritual,
      priority: 2,
      routeKey: 'geeta',
    ),
    WellnessTool(
      id: 'sleep_mix',
      title: 'Sleep Sounds',
      subtitle: 'Nature Mixer',
      icon: Icons.music_note,
      color: Colors.deepPurple,
      category: WellnessCategory.sleep,
      priority: 2,
      routeKey: 'sleep_mix',
      activeHours: [21, 22, 23, 0, 1, 2, 3, 4], // Night only
    ),
    WellnessTool(
      id: 'gratitude',
      title: 'Gratitude',
      subtitle: 'Grow Good',
      icon: Icons.local_florist,
      color: Colors.green,
      category: WellnessCategory.spiritual,
      priority: 3,
      routeKey: 'gratitude',
    ),
    WellnessTool(
      id: 'sleep_debt',
      title: 'Sleep Debt',
      subtitle: 'Calculate & recover lost rest',
      icon: Icons.bedtime_rounded,
      category: WellnessCategory.sleep, // 🎯 Make sure this matches your tab
      priority: 4,
      color: Colors.indigo,
      routeKey: 'sleep_debt',
    ),
    // Inside your wellness_tool_registry.dart
    WellnessTool(
      id: 'vitals_scan',
      title: 'Metabolic Vitals',
      subtitle: 'Optical HRV Scanner',
      icon: Icons.fingerprint_rounded,
      color: Colors.redAccent,
      priority: 7,
      routeKey: 'vitals_scan', // Matches the case we just added!
      category: WellnessCategory.physical,
    ),

    WellnessTool(
      id: 'meal_pacer',
      title: 'Meal Pacer',
      subtitle: 'Slow down for better digestion',
      icon: Icons.restaurant_rounded,
      category: WellnessCategory.physical, // 🎯 Check if this category is being filtered out
      priority: 5,
      color: Colors.orange,
      routeKey: 'meal_pacer',
    ),

    // --- LEARNING ---
    WellnessTool(
      id: 'quiz',
      title: 'Nutri-Quiz',
      subtitle: 'Daily Trivia',
      icon: Icons.school,
      color: Colors.deepPurpleAccent,
      category: WellnessCategory.learning,
      priority: 5,
      routeKey: 'quiz',
    ),

    // 🎯 ADD THESE TO YOUR LIST OF WELLNESS TOOLS

// --- CLINICAL DIAGNOSTICS (Physical) ---


    WellnessTool(
      id: 'co2_tolerance',
      title: 'CO2 Tolerance',
      subtitle: 'Autonomic Breath-Hold',
      icon: Icons.air_rounded,
      color: Colors.lightBlue,
      routeKey: 'co2_tolerance',
      priority: 5,
      category: WellnessCategory.physical,
    ),

// --- COGNITIVE & SOMATIC (Mental/Focus) ---

    WellnessTool(
      id: 'somatic_popit',
      title: 'Somatic Matrix',
      subtitle: 'Tactile Grounding',
      icon: Icons.grid_view_rounded,
      color: Colors.indigo,
      routeKey: 'somatic_popit',
      priority: 5,
      category: WellnessCategory.mental,
    ),
    WellnessTool(
      id: 'somatic_fluid',
      title: 'Particle Flow',
      subtitle: 'Visual-Motor Integration',
      icon: Icons.waves_rounded,
      color: Colors.cyan,
      routeKey: 'somatic_fluid',
      priority: 5,
      category: WellnessCategory.mental,
    ),

  ];
}