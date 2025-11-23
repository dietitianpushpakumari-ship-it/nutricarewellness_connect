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
  ];
}