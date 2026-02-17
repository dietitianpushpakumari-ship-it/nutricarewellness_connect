import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/new/models/prescription_model.dart';

class VitalsModel {
  final String id;
  final String clientId;
  final DateTime date;
  final String? sessionId;
  final String? tenantId;

  // --- Anthropometrics ---
  final double heightCm;
  final double bmi;
  final double idealBodyWeightKg;
  final double weightKg;
  final double bodyFatPercentage;
  final double? waistCm;
  final double? hipCm;
  final Map<String, double> measurements;

  // --- Cardio & Vitals ---
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRate;
  final double? spO2Percentage;

  // --- History & Profile ---
  final List<String> foodAllergies;
  final String? restrictedDiet;

  final Map<String, String>? giDetails;
  final Map<String, String>? waterIntake;
  final Map<String, double> labResults;

  final Map<String, String> medicalHistory;
  final Map<String, String> prescribedMedications;
  final Map<String, String>? caffeineIntake;
  final Map<String, String>? clinicalComplaints;
  final Map<String, String>? nutritionDiagnoses;
  final Map<String, String>? clinicalNotes;
  final Map<String, String>? clinicalGuidelines;

  // --- Assessment & Plans ---
  final List<PrescribedMedicine> medications;
  final List<String> labTestOrders;

  // --- Behavioral/Status ---
  final int? stressLevel;
  final String? sleepQuality;
  final String? menstrualStatus;

  // --- Lifestyle ---
  final String? foodHabit;
  final String? activityType;
  final Map<String, String>? otherLifestyleHabits;

  const VitalsModel({
    this.tenantId,
    required this.id,
    required this.clientId,
    required this.date,
    required this.heightCm,
    this.bmi = 0,
    this.idealBodyWeightKg = 0,
    required this.weightKg,
    required this.bodyFatPercentage,
    this.waistCm,
    this.hipCm,
    this.measurements = const {},
    this.sessionId,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
    this.spO2Percentage,
    this.prescribedMedications = const {},
    this.medications = const [],
    this.labTestOrders = const [],
    this.labResults = const {},
    this.medicalHistory = const {},
    this.foodAllergies = const [],
    this.restrictedDiet,
    this.clinicalGuidelines,
    this.giDetails,
    this.waterIntake,
    this.caffeineIntake,
    this.stressLevel,
    this.sleepQuality,
    this.menstrualStatus,
    this.foodHabit,
    this.activityType,
    this.otherLifestyleHabits,
    this.clinicalComplaints,
    this.nutritionDiagnoses,
    this.clinicalNotes,
  });

  factory VitalsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VitalsModel.fromMap(doc.id, data);
  }

  factory VitalsModel.fromMap(String id, Map<String, dynamic> map) {

    // 🛠️ ROBUST CASTER: Handles Maps, Lists, and Dynamic types safely
    Map<String, String> castToMap(dynamic data) {
      if (data == null) return {};
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      if (data is List) {
        // Fallback for legacy data stored as Lists
        return { for (var item in data) item.toString() : "Not specified" };
      }
      return {};
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
      labResults: Map<String, double>.from(
        (map['labResults'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      sessionId: map['sessionId'],
      foodAllergies: List<String>.from(map['foodAllergies'] ?? []),
      restrictedDiet: map['restrictedDiet'],
      tenantId: map['tenantId'] as String?,

      // Behavioral
      stressLevel: (map['stressLevel'] as num?)?.toInt(),
      sleepQuality: map['sleepQuality'],
      menstrualStatus: map['menstrualStatus'],

      // Lifestyle
      foodHabit: map['foodHabit'],
      activityType: map['activityType'],

      // 🎯 FIXED: Use castToMap for ALL generic map fields to prevent crashes/empty data
      medicalHistory: castToMap(map['medicalHistory']),
      prescribedMedications: castToMap(map['prescribedMedications']),
      giDetails: castToMap(map['giDetails']),
      caffeineIntake: castToMap(map['caffeineIntake']),
      otherLifestyleHabits: castToMap(map['otherLifestyleHabits']),
      waterIntake: castToMap(map['waterIntake']),

      // Clinical Text Maps
      clinicalComplaints: castToMap(map['clinicalComplaints']),
      nutritionDiagnoses: castToMap(map['nutritionDiagnoses']),
      clinicalNotes: castToMap(map['clinicalNotes']),
      clinicalGuidelines: map['clinicalGuidelines'] != null ? Map<String, String>.from(map['clinicalGuidelines']) : null,

      medications: (map['medications'] as List<dynamic>?)
          ?.map((x) => PrescribedMedicine.fromMap(x as Map<String, dynamic>))
          .toList() ?? [],
      labTestOrders: List<String>.from(map['labTests'] ?? []),
    );
  }

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
      'tenantId': tenantId,

      'labResults': labResults,

      'medicalHistory': medicalHistory,
      'foodAllergies': foodAllergies,
      'restrictedDiet': restrictedDiet,
      'prescribedMedications': prescribedMedications,
      'clinicalGuidelines': clinicalGuidelines,

      'giDetails': giDetails,
      'waterIntake': waterIntake,
      'caffeineIntake': caffeineIntake,

      'stressLevel': stressLevel,
      'sleepQuality': sleepQuality,
      'menstrualStatus': menstrualStatus,

      'foodHabit': foodHabit,
      'activityType': activityType,
      'otherLifestyleHabits': otherLifestyleHabits,
      'sessionId': sessionId,

      'clinicalComplaints': clinicalComplaints,
      'nutritionDiagnoses': nutritionDiagnoses,
      'clinicalNotes': clinicalNotes,

      'medications': medications.map((x) => x.toMap()).toList(),
      'labTests': labTestOrders,
    };
  }

  VitalsModel copyWith({
    String? id,
    String? clientId,
    String? sessionId,
    String? tenantId,
    DateTime? date,
    double? heightCm,
    double? bmi,
    double? idealBodyWeightKg,
    double? weightKg,
    double? bodyFatPercentage,
    double? waistCm,
    double? hipCm,
    Map<String, double>? measurements,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    int? heartRate,
    double? spO2Percentage,
    Map<String, double>? labResults,
    List<PrescribedMedicine>? medications,
    List<String>? labTestOrders,
    Map<String, String>? prescribedMedications,
    Map<String, String>? clinicalGuidelines,
    Map<String, String>? medicalHistory,
    List<String>? foodAllergies,
    String? restrictedDiet,
    Map<String, String>? giDetails,
    Map<String, String>? waterIntake,
    Map<String, String>? caffeineIntake,
    Map<String, String>? clinicalComplaints,
    Map<String, String>? nutritionDiagnoses,
    Map<String, String>? clinicalNotes,
    int? stressLevel,
    String? sleepQuality,
    String? menstrualStatus,
    String? foodHabit,
    String? activityType,
    Map<String, String>? otherLifestyleHabits,
  }) {
    return VitalsModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      sessionId: sessionId ?? this.sessionId,
      tenantId: tenantId ?? this.tenantId,
      date: date ?? this.date,
      heightCm: heightCm ?? this.heightCm,
      bmi: bmi ?? this.bmi,
      idealBodyWeightKg: idealBodyWeightKg ?? this.idealBodyWeightKg,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      waistCm: waistCm ?? this.waistCm,
      hipCm: hipCm ?? this.hipCm,
      measurements: measurements ?? this.measurements,
      bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic: bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      heartRate: heartRate ?? this.heartRate,
      spO2Percentage: spO2Percentage ?? this.spO2Percentage,
      labResults: labResults ?? this.labResults,
      medications: medications ?? this.medications,
      labTestOrders: labTestOrders ?? this.labTestOrders,
      prescribedMedications: prescribedMedications ?? this.prescribedMedications,
      clinicalGuidelines: clinicalGuidelines ?? this.clinicalGuidelines,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      foodAllergies: foodAllergies ?? this.foodAllergies,
      restrictedDiet: restrictedDiet ?? this.restrictedDiet,
      giDetails: giDetails ?? this.giDetails,
      waterIntake: waterIntake ?? this.waterIntake,
      caffeineIntake: caffeineIntake ?? this.caffeineIntake,
      clinicalComplaints: clinicalComplaints ?? this.clinicalComplaints,
      nutritionDiagnoses: nutritionDiagnoses ?? this.nutritionDiagnoses,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      stressLevel: stressLevel ?? this.stressLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      menstrualStatus: menstrualStatus ?? this.menstrualStatus,
      foodHabit: foodHabit ?? this.foodHabit,
      activityType: activityType ?? this.activityType,
      otherLifestyleHabits: otherLifestyleHabits ?? this.otherLifestyleHabits,
    );
  }
}