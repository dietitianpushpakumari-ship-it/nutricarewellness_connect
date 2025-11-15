
import 'package:cloud_firestore/cloud_firestore.dart';

class VitalsModel {
  final String id;
  final String clientId;
  final DateTime date;
  final double heightCm;
  final double bmi;
  final double idealBodyWeightKg;
  final double weightKg;
  final double bodyFatPercentage;
  final Map<String, double> measurements; // e.g., {'waist': 75.0, 'hip': 90.0}
  final Map<String, String> labResults; // e.g., {'hba1c': '5.5', 'fasting_glucose': '95'}
  final String? notes;
  final List<String> labReportUrls;
  final List<String> assignedDietPlanIds;
  final String? foodHabit;
  final String? activityType;
  final String? complaints;
  final String? existingMedication;
  final String? foodAllergies;
  final String? restrictedDiet;
//  final List<String> medicalHistoryIds;
  final String? medicalHistoryDurations;

  // 🎯 NEW FIELD FOR DRINKING, SMOKING, AND OTHER HABITS
  final Map<String, String>? otherLifestyleHabits;

  final bool isFirstConsultation;

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
    this.otherLifestyleHabits, // Initialize the new field
    this.complaints,
    this.existingMedication,
    this.foodAllergies,
    this.restrictedDiet,
  //  this.medicalHistoryIds = const [],
    this.medicalHistoryDurations,
    required this.isFirstConsultation
  });

  factory VitalsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VitalsModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0.0,
      bodyFatPercentage: (data['bodyFatPercentage'] as num?)?.toDouble() ?? 0.0,
      measurements: Map<String, double>.from(data['measurements'] ?? {}),
      labResults: Map<String, String>.from(data['labResults'] ?? {}), // Read NEW field
      notes: data['notes'],
      labReportUrls: List<String>.from(data['labReportUrls'] ?? []),
      foodHabit: data['foodHabit'],
      activityType: data['activityType'],
      heightCm: (data['heightCm'] as num?)?.toDouble() ?? 0.0,
      bmi: (data['bmi'] as num?)?.toDouble() ?? 0.0,
      idealBodyWeightKg: (data ['idealBodyWeightKg'] as num?)?.toDouble() ?? 0.0,
        otherLifestyleHabits: Map<String, String>.from(data['otherLifestyleHabits'] ?? {}),
      complaints: data['complaints'] ,
      existingMedication: data['existingMedication'] ,
      foodAllergies: data['foodAllergies'] ,
      restrictedDiet: data['restrictedDiet'] ,
    //  medicalHistoryIds: List<String>.from(data['medicalHistoryIds'] ?? []),
      medicalHistoryDurations: data['medicalHistoryDurations'],
      isFirstConsultation: data['isFirstConsultation'] ?? false
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
      'otherLifestyleHabits': otherLifestyleHabits, // Add to map
      'complaints': complaints,
      'existingMedication': existingMedication,
      'foodAllergies': foodAllergies,
      'restrictedDiet': restrictedDiet,
     // 'medicalHistoryIds': medicalHistoryIds,
      'medicalHistoryDurations': medicalHistoryDurations,
      'isFirstConsultation' : isFirstConsultation
    };
  }

  factory VitalsModel.fromMap(String id, Map<String, dynamic> map) {
    return VitalsModel(
      id: id,
      clientId: map['clientId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0.0,
      bmi: (map['bmi'] as num?)?.toDouble() ?? 0.0,
      idealBodyWeightKg: (map['idealBodyWeightKg'] as num?)?.toDouble() ?? 0.0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      bodyFatPercentage: (map['bodyFatPercentage'] as num?)?.toDouble() ?? 0.0,
      measurements: Map<String, double>.from(map['measurements'] ?? {}),
      // Firebase stores numbers, ensure we get strings for lab values
      labResults: Map<String, String>.from(map['labResults']?.map((k, v) => MapEntry(k, v.toString())) ?? {}),
      notes: map['notes'] as String?,
      labReportUrls: List<String>.from(map['labReportUrls'] ?? []),
      assignedDietPlanIds: List<String>.from(map['assignedDietPlanIds'] ?? []),
      foodHabit: map['foodHabit'] as String?,
      activityType: map['activityType'] as String?,
      // Retrieve the new field
      otherLifestyleHabits: Map<String, String>.from(map['otherLifestyleHabits'] ?? {}),
      // Load New Fields
      complaints: map['complaints'] as String?,
      existingMedication: map['existingMedication'] as String?,
      foodAllergies: map['foodAllergies'] as String?,
      restrictedDiet: map['restrictedDiet'] as String?,
     // medicalHistoryIds: List<String>.from(map['medicalHistoryIds'] ?? []),
      medicalHistoryDurations: map['medicalHistoryDurations'] as String,
      isFirstConsultation: map['isFirstConsultation'] ?? false
    );
  }

}