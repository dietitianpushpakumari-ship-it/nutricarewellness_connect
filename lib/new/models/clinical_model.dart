import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// --- 1. Master Models (For the Database) ---

class ClinicalItemModel {
  final String id;
  final String name;
  final bool isDeleted;

  const ClinicalItemModel({required this.id, required this.name, this.isDeleted = false});

  factory ClinicalItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClinicalItemModel(
      id: doc.id,
      name: data['name'] ?? '',
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isDeleted': isDeleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// --- 2. Client Assignment Model (For the Vitals Form) ---

final class PrescribedMedication {
  final String medicineName;
  final String frequency;
  final String timing;

  // 🎯 NEW: Reminder Fields
  final bool isReminderEnabled;
  final String? reminderTime; // Stored as "HH:mm"
  final String? photoUrl;

  const PrescribedMedication({
    required this.medicineName,
    required this.frequency,
    required this.timing,
    this.isReminderEnabled = false,
    this.reminderTime,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'frequency': frequency,
      'timing': timing,
      'isReminderEnabled': isReminderEnabled,
      'reminderTime': reminderTime,
      'photoUrl': photoUrl,
    };
  }

  factory PrescribedMedication.fromMap(Map<String, dynamic> map) {
    return PrescribedMedication(
      medicineName: map['medicineName'] ?? '',
      frequency: map['frequency'] ?? '1-0-0',
      timing: map['timing'] ?? 'After Food',
      isReminderEnabled: map['isReminderEnabled'] ?? false,
      reminderTime: map['reminderTime'],
      photoUrl: map['photoUrl'],
    );
  }

  // Helper to get TimeOfDay
  TimeOfDay? get parsedTime {
    if (reminderTime == null) return null;
    final parts = reminderTime!.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // CopyWith for updates
  PrescribedMedication copyWith({
    String? medicineName,
    String? frequency,
    String? timing,
    bool? isReminderEnabled,
    String? reminderTime,String? photoUrl,
  }) {
    return PrescribedMedication(
      medicineName: medicineName ?? this.medicineName,
      frequency: frequency ?? this.frequency,
      timing: timing ?? this.timing,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}