import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/clinical_model.dart';

class VitalsModel {
  final String id;
  final String clientId;
  final DateTime date;

  // Anthro
  final double heightCm;
  final double weightKg;
  final double bmi;
  final double idealBodyWeightKg;
  final double bodyFatPercentage;
  final double? waistCm;
  final double? hipCm;
  final Map<String, double> measurements;

  // Cardio
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRate;
  final double? spO2Percentage;

  // Clinical
  final Map<String, String> labResults;
  final String? notes;
  final List<String> labReportUrls;

  // History
  final List<String> medicalHistory;
  final String? medicalHistoryDurations;
  final List<String> diagnosis;
  final String? complaints;

  // 🎯 MEDICATIONS
  final List<PrescribedMedication> prescribedMedications;
  final String? existingMedication; // Legacy

  final String? foodAllergies;
  final String? restrictedDiet;

  // Lifestyle
  final String? foodHabit;
  final String? activityType;
  final Map<String, String>? otherLifestyleHabits;

  // Meta
  final List<String> assignedDietPlanIds;
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
    this.waistCm,
    this.hipCm,
    this.measurements = const {},
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
    this.spO2Percentage,

    this.prescribedMedications = const [], // Default empty

    this.labResults = const {},
    this.notes,
    this.labReportUrls = const [],
    this.medicalHistory = const [],
    this.medicalHistoryDurations,
    this.diagnosis = const [],
    this.complaints,
    this.existingMedication,
    this.foodAllergies,
    this.restrictedDiet,
    this.foodHabit,
    this.activityType,
    this.otherLifestyleHabits,
    this.assignedDietPlanIds = const [],
    required this.isFirstConsultation,
  });

  // 🎯 COPYWITH METHOD (Fixed to include prescribedMedications)
  VitalsModel copyWith({
    String? id,
    String? clientId,
    DateTime? date,
    double? heightCm,
    double? weightKg,
    double? bmi,
    double? idealBodyWeightKg,
    double? bodyFatPercentage,
    double? waistCm,
    double? hipCm,
    Map<String, double>? measurements,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    int? heartRate,
    double? spO2Percentage,
    Map<String, String>? labResults,
    String? notes,
    List<String>? labReportUrls,
    List<String>? medicalHistory,
    String? medicalHistoryDurations,
    List<String>? diagnosis,
    String? complaints,

    List<PrescribedMedication>? prescribedMedications, // 🎯 ADDED
    String? existingMedication,

    String? foodAllergies,
    String? restrictedDiet,
    String? foodHabit,
    String? activityType,
    Map<String, String>? otherLifestyleHabits,
    List<String>? assignedDietPlanIds,
    bool? isFirstConsultation,
  }) {
    return VitalsModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      date: date ?? this.date,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bmi: bmi ?? this.bmi,
      idealBodyWeightKg: idealBodyWeightKg ?? this.idealBodyWeightKg,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      waistCm: waistCm ?? this.waistCm,
      hipCm: hipCm ?? this.hipCm,
      measurements: measurements ?? this.measurements,
      bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic: bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      heartRate: heartRate ?? this.heartRate,
      spO2Percentage: spO2Percentage ?? this.spO2Percentage,
      labResults: labResults ?? this.labResults,
      notes: notes ?? this.notes,
      labReportUrls: labReportUrls ?? this.labReportUrls,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      medicalHistoryDurations: medicalHistoryDurations ?? this.medicalHistoryDurations,
      diagnosis: diagnosis ?? this.diagnosis,
      complaints: complaints ?? this.complaints,

      prescribedMedications: prescribedMedications ?? this.prescribedMedications, // 🎯
      existingMedication: existingMedication ?? this.existingMedication,

      foodAllergies: foodAllergies ?? this.foodAllergies,
      restrictedDiet: restrictedDiet ?? this.restrictedDiet,
      foodHabit: foodHabit ?? this.foodHabit,
      activityType: activityType ?? this.activityType,
      otherLifestyleHabits: otherLifestyleHabits ?? this.otherLifestyleHabits,
      assignedDietPlanIds: assignedDietPlanIds ?? this.assignedDietPlanIds,
      isFirstConsultation: isFirstConsultation ?? this.isFirstConsultation,
    );
  }

  // ... (Keep existing toMap/fromMap/fromFirestore) ...
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'date': Timestamp.fromDate(date),
      'heightCm': heightCm,
      'weightKg': weightKg,
      'bmi': bmi,
      'idealBodyWeightKg': idealBodyWeightKg,
      'bodyFatPercentage': bodyFatPercentage,
      'waistCm': waistCm,
      'hipCm': hipCm,
      'measurements': measurements,
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'heartRate': heartRate,
      'spO2Percentage': spO2Percentage,
      'labResults': labResults,
      'notes': notes,
      'labReportUrls': labReportUrls,
      'medicalHistory': medicalHistory,
      'medicalHistoryDurations': medicalHistoryDurations,
      'diagnosis': diagnosis,
      'complaints': complaints,
      'existingMedication': existingMedication,
      'foodAllergies': foodAllergies,
      'restrictedDiet': restrictedDiet,

      'prescribedMedications': prescribedMedications.map((m) => m.toMap()).toList(), // 🎯

      'foodHabit': foodHabit,
      'activityType': activityType,
      'otherLifestyleHabits': otherLifestyleHabits,
      'assignedDietPlanIds': assignedDietPlanIds,
      'isFirstConsultation': isFirstConsultation,
    };
  }
  factory VitalsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VitalsModel.fromMap(doc.id, data);
  }

  factory VitalsModel.fromMap(String id, Map<String, dynamic> map) {
    List<PrescribedMedication> meds = [];
    if (map['prescribedMedications'] != null) {
      meds = (map['prescribedMedications'] as List).map((m) => PrescribedMedication.fromMap(m)).toList();
    }
    return VitalsModel(
      id: id,
      clientId: map['clientId'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),

      // Anthro
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0.0,
      bmi: (map['bmi'] as num?)?.toDouble() ?? 0.0,
      idealBodyWeightKg: (map['idealBodyWeightKg'] as num?)?.toDouble() ?? 0.0,
      bodyFatPercentage: (map['bodyFatPercentage'] as num?)?.toDouble() ?? 0.0,
      waistCm: (map['waistCm'] as num?)?.toDouble(),
      hipCm: (map['hipCm'] as num?)?.toDouble(),
      measurements: Map<String, double>.from(map['measurements'] ?? {}),

      // Cardio
      bloodPressureSystolic: (map['bloodPressureSystolic'] as num?)?.toInt(),
      bloodPressureDiastolic: (map['bloodPressureDiastolic'] as num?)?.toInt(),
      heartRate: (map['heartRate'] as num?)?.toInt(),
      spO2Percentage: (map['spO2Percentage'] as num?)?.toDouble(),

      // Clinical
      labResults: Map<String, String>.from(map['labResults']?.map((k, v) => MapEntry(k, v.toString())) ?? {}),
      notes: map['notes'] as String?,
      labReportUrls: List<String>.from(map['labReportUrls'] ?? []),

      medicalHistory: List<String>.from(map['medicalHistory'] ?? []),
      medicalHistoryDurations: map['medicalHistoryDurations'],
      diagnosis: List<String>.from(map['diagnosis'] ?? []),
      complaints: map['complaints'],
      prescribedMedications: meds,
      existingMedication: map['existingMedication'],
      foodAllergies: map['foodAllergies'],
      restrictedDiet: map['restrictedDiet'],

      // Lifestyle
      foodHabit: map['foodHabit'],
      activityType: map['activityType'],
      otherLifestyleHabits: Map<String, String>.from(map['otherLifestyleHabits'] ?? {}),

      // Metadata
      assignedDietPlanIds: List<String>.from(map['assignedDietPlanIds'] ?? []),
      isFirstConsultation: map['isFirstConsultation'] ?? false,
    );
  }
}