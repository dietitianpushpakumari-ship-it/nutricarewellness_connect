import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum LogStatus { followed, skipped, deviated, reviewed }

// 🎯 NEW: Represents a single meal within the Daily Master Record
class MealEntry {
  final LogStatus status;
  final List<String> actualFoodEaten;
  final List<String> mealPhotoUrls;
  final String? clientQuery;  // e.g., "I swapped the rice for quinoa"
  final String? adminComment; // Dietitian's feedback
  final bool adminReplied;
  final DateTime? loggedAt;
  final int caloriesEstimate;
  final bool isDeviation;

  MealEntry({
    this.status = LogStatus.followed,
    this.actualFoodEaten = const [],
    this.mealPhotoUrls = const [],
    this.clientQuery,
    this.adminComment,
    this.adminReplied = false,
    this.loggedAt,
    this.caloriesEstimate = 0,
    this.isDeviation = false,
  });

  MealEntry copyWith({
    LogStatus? status,
    List<String>? actualFoodEaten,
    List<String>? mealPhotoUrls,
    String? clientQuery,
    String? adminComment,
    bool? adminReplied,
    DateTime? loggedAt,
    int? caloriesEstimate,
    bool? isDeviation,
  }) {
    return MealEntry(
      status: status ?? this.status,
      actualFoodEaten: actualFoodEaten ?? this.actualFoodEaten,
      mealPhotoUrls: mealPhotoUrls ?? this.mealPhotoUrls,
      clientQuery: clientQuery ?? this.clientQuery,
      adminComment: adminComment ?? this.adminComment,
      adminReplied: adminReplied ?? this.adminReplied,
      loggedAt: loggedAt ?? this.loggedAt,
      caloriesEstimate: caloriesEstimate ?? this.caloriesEstimate,
      isDeviation: isDeviation ?? this.isDeviation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'actualFoodEaten': actualFoodEaten,
      'mealPhotoUrls': mealPhotoUrls,
      'clientQuery': clientQuery,
      'adminComment': adminComment,
      'adminReplied': adminReplied,
      'loggedAt': loggedAt != null ? Timestamp.fromDate(loggedAt!) : FieldValue.serverTimestamp(),
      'caloriesEstimate': caloriesEstimate,
      'isDeviation': isDeviation,
    };
  }

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      status: LogStatus.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => LogStatus.followed,
      ),
      actualFoodEaten: List<String>.from(map['actualFoodEaten'] ?? []),
      mealPhotoUrls: List<String>.from(map['mealPhotoUrls'] ?? []),
      clientQuery: map['clientQuery'],
      adminComment: map['adminComment'],
      adminReplied: map['adminReplied'] ?? false,
      loggedAt: map['loggedAt'] != null ? (map['loggedAt'] as Timestamp).toDate() : null,
      caloriesEstimate: (map['caloriesEstimate'] as num?)?.toInt() ?? 0,
      isDeviation: map['isDeviation'] ?? false,
    );
  }
}

// 🎯 THE MASTER DAILY RECORD
class ClientLogModel extends Equatable {
  final String id; // This is now the "dateId" (YYYY-MM-DD)
  final String clientId;
  final String tenantId;
  final String dietPlanId;
  final DateTime date;

  // 🥗 MEALS MAP (Key is Meal Name: e.g., 'Breakfast')
  final Map<String, MealEntry> mealLogs;

  // 💧 WELLNESS DATA
  final double hydrationLiters;
  final int stepCount;
  final int sensorStepsBaseline;
  final int stepGoal;
  final int caloriesBurned;
  final int activityScore;

  // 🌙 SLEEP DATA
  final double totalSleepDurationHours;
  final int sleepScore;
  final int? sleepQualityRating;
  final int? sleepInterruptions;
  final int? energyLevelRating;
  final int? moodLevelRating;
  final DateTime? sleepTime;
  final DateTime? wakeTime;
  final String? notesAndFeelings;

  // 🧘 MINDFULNESS & HABITS
  final int breathingMinutes;
  final List<String> completedMandatoryTasks;
  final List<String> createdPersonalGoals;
  final List<String> completedPersonalGoals;
  final Map<String, bool> completedHabits;

  // 📊 DAILY VITALS
  final double? weightKg;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRateBpm;
  final double? spO2Percentage;
  final double? fbsMgDl;
  final double? ppbsMgDl;
  final double? waistCm;
  final double? hipCm;

  const ClientLogModel({
    this.id = '',
    required this.clientId,
    this.tenantId = 'guest',
    required this.dietPlanId,
    required this.date,
    this.mealLogs = const {},
    this.hydrationLiters = 0.0,
    this.stepCount = 0,
    this.sensorStepsBaseline = 0,
    this.stepGoal = 0,
    this.caloriesBurned = 0,
    this.activityScore = 0,
    this.totalSleepDurationHours = 0.0,
    this.sleepScore = 0,
    this.sleepQualityRating,
    this.sleepInterruptions,
    this.energyLevelRating,
    this.moodLevelRating,
    this.sleepTime,
    this.wakeTime,
    this.notesAndFeelings,
    this.breathingMinutes = 0,
    this.completedMandatoryTasks = const [],
    this.createdPersonalGoals = const [],
    this.completedPersonalGoals = const [],
    this.completedHabits = const {},
    this.weightKg,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRateBpm,
    this.spO2Percentage,
    this.fbsMgDl,
    this.ppbsMgDl,
    this.waistCm,
    this.hipCm,
  });

  ClientLogModel copyWith({
    String? id,
    String? clientId,
    String? tenantId,
    String? dietPlanId,
    DateTime? date,
    Map<String, MealEntry>? mealLogs,
    double? hydrationLiters,
    int? stepCount,
    int? sensorStepsBaseline,
    int? stepGoal,
    int? caloriesBurned,
    int? activityScore,
    double? totalSleepDurationHours,
    int? sleepScore,
    int? sleepQualityRating,
    int? sleepInterruptions,
    int? energyLevelRating,
    int? moodLevelRating,
    DateTime? sleepTime,
    DateTime? wakeTime,
    String? notesAndFeelings,
    int? breathingMinutes,
    List<String>? completedMandatoryTasks,
    List<String>? createdPersonalGoals,
    List<String>? completedPersonalGoals,
    Map<String, bool>? completedHabits,
    double? weightKg,
    int? bloodPressureSystolic,
    int? bloodPressureDiastolic,
    int? heartRateBpm,
    double? spO2Percentage,
    double? fbsMgDl,
    double? ppbsMgDl,
    double? waistCm,
    double? hipCm,
  }) {
    return ClientLogModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      tenantId: tenantId ?? this.tenantId,
      dietPlanId: dietPlanId ?? this.dietPlanId,
      date: date ?? this.date,
      mealLogs: mealLogs ?? this.mealLogs,
      hydrationLiters: hydrationLiters ?? this.hydrationLiters,
      stepCount: stepCount ?? this.stepCount,
      sensorStepsBaseline: sensorStepsBaseline ?? this.sensorStepsBaseline,
      stepGoal: stepGoal ?? this.stepGoal,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      activityScore: activityScore ?? this.activityScore,
      totalSleepDurationHours: totalSleepDurationHours ?? this.totalSleepDurationHours,
      sleepScore: sleepScore ?? this.sleepScore,
      sleepQualityRating: sleepQualityRating ?? this.sleepQualityRating,
      sleepInterruptions: sleepInterruptions ?? this.sleepInterruptions,
      energyLevelRating: energyLevelRating ?? this.energyLevelRating,
      moodLevelRating: moodLevelRating ?? this.moodLevelRating,
      sleepTime: sleepTime ?? this.sleepTime,
      wakeTime: wakeTime ?? this.wakeTime,
      notesAndFeelings: notesAndFeelings ?? this.notesAndFeelings,
      breathingMinutes: breathingMinutes ?? this.breathingMinutes,
      completedMandatoryTasks: completedMandatoryTasks ?? this.completedMandatoryTasks,
      createdPersonalGoals: createdPersonalGoals ?? this.createdPersonalGoals,
      completedPersonalGoals: completedPersonalGoals ?? this.completedPersonalGoals,
      completedHabits: completedHabits ?? this.completedHabits,
      weightKg: weightKg ?? this.weightKg,
      bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic: bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      spO2Percentage: spO2Percentage ?? this.spO2Percentage,
      fbsMgDl: fbsMgDl ?? this.fbsMgDl,
      ppbsMgDl: ppbsMgDl ?? this.ppbsMgDl,
      waistCm: waistCm ?? this.waistCm,
      hipCm: hipCm ?? this.hipCm,
    );
  }

  factory ClientLogModel.fromMap(Map<String, dynamic> data, String docId) {
    Map<String, MealEntry> parsedMeals = {};
    if (data['mealLogs'] != null) {
      final mealMap = data['mealLogs'] as Map<String, dynamic>;
      mealMap.forEach((key, value) {
        parsedMeals[key] = MealEntry.fromMap(value as Map<String, dynamic>);
      });
    }

    DateTime date;
    final dateValue = data['date'];
    if (dateValue is Timestamp) date = dateValue.toDate();
    else if (dateValue is String) date = DateTime.parse(dateValue);
    else date = DateTime.now();

    return ClientLogModel(
      id: docId,
      clientId: data['clientId'] as String? ?? '',
      tenantId: data['tenantId'] as String? ?? 'guest',
      dietPlanId: data['dietPlanId'] as String? ?? '',
      date: date,
      mealLogs: parsedMeals,
      hydrationLiters: (data['hydrationLiters'] as num?)?.toDouble() ?? 0.0,
      stepCount: (data['stepCount'] as num?)?.toInt() ?? 0,
      sensorStepsBaseline: (data['sensorStepsBaseline'] as num?)?.toInt() ?? 0,
      stepGoal: (data['stepGoal'] as num?)?.toInt() ?? 0,
      caloriesBurned: (data['caloriesBurned'] as num?)?.toInt() ?? 0,
      activityScore: (data['activityScore'] as num?)?.toInt() ?? 0,
      totalSleepDurationHours: (data['totalSleepDurationHours'] as num?)?.toDouble() ?? 0.0,
      sleepScore: (data['sleepScore'] as num?)?.toInt() ?? 0,
      sleepQualityRating: (data['sleepQualityRating'] as num?)?.toInt(),
      sleepInterruptions: (data['sleepInterruptions'] as num?)?.toInt(),
      energyLevelRating: (data['energyLevelRating'] as num?)?.toInt(),
      moodLevelRating: (data['moodLevelRating'] as num?)?.toInt(),
      sleepTime: data['sleepTime'] != null ? DateTime.tryParse(data['sleepTime']) : null,
      wakeTime: data['wakeTime'] != null ? DateTime.tryParse(data['wakeTime']) : null,
      notesAndFeelings: data['notesAndFeelings'] as String?,
      breathingMinutes: (data['breathingMinutes'] as num?)?.toInt() ?? 0,
      completedMandatoryTasks: List<String>.from(data['completedMandatoryTasks'] ?? []),
      createdPersonalGoals: List<String>.from(data['createdPersonalGoals'] ?? []),
      completedPersonalGoals: List<String>.from(data['completedPersonalGoals'] ?? []),
      completedHabits: data['completedHabits'] != null ? Map<String, bool>.from(data['completedHabits']) : {},
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      bloodPressureSystolic: (data['bloodPressureSystolic'] as num?)?.toInt(),
      bloodPressureDiastolic: (data['bloodPressureDiastolic'] as num?)?.toInt(),
      fbsMgDl: (data['fbsMgDl'] as num?)?.toDouble(),
      ppbsMgDl: (data['ppbsMgDl'] as num?)?.toDouble(),
      heartRateBpm: (data['heartRateBpm'] as num?)?.toInt(),
      spO2Percentage: (data['spO2Percentage'] as num?)?.toDouble(),
      waistCm: (data['waistCm'] as num?)?.toDouble(),
      hipCm: (data['hipCm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'tenantId': tenantId,
      'dietPlanId': dietPlanId,
      'date': Timestamp.fromDate(date),
      'mealLogs': mealLogs.map((k, v) => MapEntry(k, v.toMap())),
      'hydrationLiters': hydrationLiters,
      'stepCount': stepCount,
      'sensorStepsBaseline': sensorStepsBaseline,
      'stepGoal': stepGoal,
      'caloriesBurned': caloriesBurned,
      'activityScore': activityScore,
      'totalSleepDurationHours': totalSleepDurationHours,
      'sleepScore': sleepScore,
      'sleepQualityRating': sleepQualityRating,
      'sleepInterruptions': sleepInterruptions,
      'energyLevelRating': energyLevelRating,
      'moodLevelRating': moodLevelRating,
      'sleepTime': sleepTime?.toIso8601String(),
      'wakeTime': wakeTime?.toIso8601String(),
      'notesAndFeelings': notesAndFeelings,
      'breathingMinutes': breathingMinutes,
      'completedMandatoryTasks': completedMandatoryTasks,
      'createdPersonalGoals': createdPersonalGoals,
      'completedPersonalGoals': completedPersonalGoals,
      'completedHabits': completedHabits,
      'weightKg': weightKg,
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'fbsMgDl': fbsMgDl,
      'ppbsMgDl': ppbsMgDl,
      'heartRateBpm': heartRateBpm,
      'spO2Percentage': spO2Percentage,
      'waistCm': waistCm,
      'hipCm': hipCm,
    };
  }

  @override
  List<Object?> get props => [id, clientId, tenantId, date, mealLogs.length, hydrationLiters, stepCount];
}