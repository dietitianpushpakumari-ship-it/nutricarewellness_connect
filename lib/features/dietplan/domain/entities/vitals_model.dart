import 'package:cloud_firestore/cloud_firestore.dart';

class VitalsModel {
  final String id;
  final String clientId;
  final DateTime date;

  // Body Composition
  final double heightCm;
  final double bmi;
  final double idealBodyWeightKg;
  final double weightKg;
  final double bodyFatPercentage;
  final Map<String, double> measurements; // waist, hip, etc.

  // Clinical & Lab
  final Map<String, String> labResults;
  final String? notes;
  final List<String> labReportUrls;

  // 🎯 NEW / RESTORED FIELDS
  final List<String> medicalHistory; // List of diseases/conditions
  final List<String> diagnosis;      // Current diagnosis
  final String? existingMedication;  // Text description
  final String? medicalHistoryDurations; // "Diabetes (5 yrs)"

  // Diet & Lifestyle
  final String? foodHabit;
  final String? activityType;
  final String? complaints;
  final String? foodAllergies;
  final String? restrictedDiet;
  final Map<String, String>? otherLifestyleHabits; // Smoking/Alcohol

  final bool isFirstConsultation;

  // Cardio
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRate;

  // Admin Metadata
  final List<String> assignedDietPlanIds;

  const VitalsModel({
    required this.id,
    required this.clientId,
    required this.date,
    required this.heightCm,
    required this.bmi,
    required this.idealBodyWeightKg,
    required this.weightKg,
    required this.bodyFatPercentage,
    this.measurements = const {},
    this.labResults = const {},
    this.notes,
    this.labReportUrls = const [],
    this.assignedDietPlanIds = const [],
    this.foodHabit,
    this.activityType,
    this.otherLifestyleHabits,
    this.complaints,
    this.existingMedication,
    this.foodAllergies,
    this.restrictedDiet,
    this.medicalHistory = const [], // 🎯 Default Empty
    this.diagnosis = const [],      // 🎯 Default Empty
    this.medicalHistoryDurations,
    required this.isFirstConsultation,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
  });

  factory VitalsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VitalsModel.fromMap(doc.id, data);
  }

  factory VitalsModel.fromMap(String id, Map<String, dynamic> map) {
    return VitalsModel(
      id: id,
      clientId: map['clientId'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0.0,
      bmi: (map['bmi'] as num?)?.toDouble() ?? 0.0,
      idealBodyWeightKg: (map['idealBodyWeightKg'] as num?)?.toDouble() ?? 0.0,
      bodyFatPercentage: (map['bodyFatPercentage'] as num?)?.toDouble() ?? 0.0,

      measurements: Map<String, double>.from(map['measurements'] ?? {}),
      labResults: Map<String, String>.from(map['labResults'] ?? {}),

      notes: map['notes'],
      labReportUrls: List<String>.from(map['labReportUrls'] ?? []),
      assignedDietPlanIds: List<String>.from(map['assignedDietPlanIds'] ?? []),

      foodHabit: map['foodHabit'],
      activityType: map['activityType'],
      otherLifestyleHabits: Map<String, String>.from(map['otherLifestyleHabits'] ?? {}),

      complaints: map['complaints'],
      existingMedication: map['existingMedication'],
      foodAllergies: map['foodAllergies'],
      restrictedDiet: map['restrictedDiet'],

      // 🎯 MAP LISTS SAFELY
      medicalHistory: List<String>.from(map['medicalHistory'] ?? []),
      diagnosis: List<String>.from(map['diagnosis'] ?? []),
      medicalHistoryDurations: map['medicalHistoryDurations'],

      isFirstConsultation: map['isFirstConsultation'] ?? false,
      bloodPressureSystolic: (map['bloodPressureSystolic'] as num?)?.toInt(),
      bloodPressureDiastolic: (map['bloodPressureDiastolic'] as num?)?.toInt(),
      heartRate: (map['heartRate'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'date': Timestamp.fromDate(date),
      'heightCm': heightCm,
      'bmi': bmi,
      'idealBodyWeightKg': idealBodyWeightKg,
      'weightKg': weightKg,
      'bodyFatPercentage': bodyFatPercentage,
      'measurements': measurements,
      'labResults': labResults,
      'notes': notes,
      'labReportUrls': labReportUrls,
      'assignedDietPlanIds': assignedDietPlanIds,
      'foodHabit': foodHabit,
      'activityType': activityType,
      'otherLifestyleHabits': otherLifestyleHabits,
      'complaints': complaints,
      'existingMedication': existingMedication,
      'foodAllergies': foodAllergies,
      'restrictedDiet': restrictedDiet,
      // 🎯 SAVE NEW LISTS
      'medicalHistory': medicalHistory,
      'diagnosis': diagnosis,
      'medicalHistoryDurations': medicalHistoryDurations,
      'isFirstConsultation': isFirstConsultation,
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'heartRate': heartRate,
    };
  }
}