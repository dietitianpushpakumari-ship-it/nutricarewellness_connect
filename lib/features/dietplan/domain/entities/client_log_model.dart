import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum LogStatus { followed, skipped, deviated, reviewed }

class ClientLogModel extends Equatable {
  final String id;
  final String clientId;
  final String dietPlanId;
  final DateTime date;
  final String mealName;

  final List<String> actualFoodEaten;
  final int caloriesEstimate;
  final bool isDeviation;

  final LogStatus logStatus;
  final List<String> mealPhotoUrls;
  final DateTime? deviationTime;
  final String? clientQuery;
  final String? adminComment;
  final bool adminReplied;

  // Wellness
  final int? sleepQualityRating;
  final double? hydrationLiters;
  final int? energyLevelRating;
  final int? moodLevelRating;
  final String? notesAndFeelings;

  // Sleep
  final DateTime? sleepTime;
  final DateTime? wakeTime;
  final int? sleepInterruptions;
  final double? totalSleepDurationHours;
  final int? sleepScore;

  // Vitals
  final double? weightKg;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final double? fbsMgDl;
  final double? ppbsMgDl;

  // Cardio & Body
  final int? heartRateBpm;
  final double? spO2Percentage;
  final double? waistCm;
  final double? hipCm;

  // Goals
  final int? stepGoal;
  final int? stepCount;
  final List<String> completedMandatoryTasks;
  final List<String> createdPersonalGoals;
  final List<String> completedPersonalGoals;
  final int? activityScore;
  final int? caloriesBurned;
  final int? breathingMinutes;
  final int? sensorStepsBaseline;

  // 🎯 HABITS MAP
  final Map<String, bool> completedHabits;

  ClientLogModel({
    this.id = '',
    required this.clientId,
    required this.dietPlanId,
    required this.date,
    required this.mealName,
    this.actualFoodEaten = const [],
    this.caloriesEstimate = 0,
    this.isDeviation = false,
    this.logStatus = LogStatus.followed,
    this.mealPhotoUrls = const [],
    this.deviationTime,
    this.clientQuery,
    this.adminComment,
    this.adminReplied = false,
    this.sleepQualityRating,
    this.hydrationLiters,
    this.energyLevelRating,
    this.moodLevelRating,
    this.notesAndFeelings,
    this.sleepTime,
    this.wakeTime,
    this.sleepInterruptions,
    this.totalSleepDurationHours,
    this.sleepScore,
    this.weightKg,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.fbsMgDl,
    this.ppbsMgDl,
    this.heartRateBpm,
    this.spO2Percentage,
    this.waistCm,
    this.hipCm,
    this.stepGoal,
    this.stepCount,
    this.completedMandatoryTasks = const [],
    this.createdPersonalGoals = const [],
    this.completedPersonalGoals = const [],
    this.activityScore,
    this.caloriesBurned,
    this.breathingMinutes,
    this.sensorStepsBaseline,
    // 🎯 FIX: Default to empty map if null
    this.completedHabits = const {},
  });

  static LogStatus _statusFromString(String? status) {
    if (status == null) return LogStatus.followed;
    try {
      return LogStatus.values.firstWhere((e) => e.name == status);
    } catch (e) {
      return LogStatus.followed;
    }
  }

  factory ClientLogModel.fromMap(Map<String, dynamic> data, String docId) {
    DateTime date;
    final dateValue = data['date'];
    if (dateValue is Timestamp) date = dateValue.toDate();
    else if (dateValue is String) date = DateTime.parse(dateValue);
    else date = DateTime.now();

    final devTimeValue = data['deviationTime'];
    DateTime? deviationTime;
    if (devTimeValue is Timestamp) deviationTime = devTimeValue.toDate();

    final sleepTimeValue = data['sleepTime'];
    DateTime? sleepTime;
    if (sleepTimeValue is Timestamp) sleepTime = sleepTimeValue.toDate();

    final wakeTimeValue = data['wakeTime'];
    DateTime? wakeTime;
    if (wakeTimeValue is Timestamp) wakeTime = wakeTimeValue.toDate();

    return ClientLogModel(
      id: docId,
      clientId: data['clientId'] as String? ?? '',
      dietPlanId: data['dietPlanId'] as String? ?? '',
      date: date,
      mealName: data['mealName'] as String? ?? '',
      actualFoodEaten: List<String>.from(data['actualFoodEaten'] as List<dynamic>? ?? []),
      caloriesEstimate: (data['caloriesEstimate'] as num?)?.toInt() ?? 0,
      isDeviation: data['isDeviation'] as bool? ?? false,
      logStatus: _statusFromString(data['logStatus'] as String?),
      mealPhotoUrls: List<String>.from(data['mealPhotoUrls'] as List<dynamic>? ?? []),
      deviationTime: deviationTime,
      clientQuery: data['clientQuery'] as String?,
      adminComment: data['adminComment'] as String?,
      adminReplied: data['adminReplied'] as bool? ?? false,
      sleepQualityRating: (data['sleepQualityRating'] as num?)?.toInt(),
      hydrationLiters: (data['hydrationLiters'] as num?)?.toDouble(),
      energyLevelRating: (data['energyLevelRating'] as num?)?.toInt(),
      moodLevelRating: (data['moodLevelRating'] as num?)?.toInt(),
      notesAndFeelings: data['notesAndFeelings'] as String?,
      sleepTime: sleepTime,
      wakeTime: wakeTime,
      sleepInterruptions: (data['sleepInterruptions'] as num?)?.toInt(),
      totalSleepDurationHours: (data['totalSleepDurationHours'] as num?)?.toDouble(),
      sleepScore: (data['sleepScore'] as num?)?.toInt(),
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      bloodPressureSystolic: (data['bloodPressureSystolic'] as num?)?.toInt(),
      bloodPressureDiastolic: (data['bloodPressureDiastolic'] as num?)?.toInt(),
      fbsMgDl: (data['fbsMgDl'] as num?)?.toDouble(),
      ppbsMgDl: (data['ppbsMgDl'] as num?)?.toDouble(),
      heartRateBpm: (data['heartRateBpm'] as num?)?.toInt(),
      spO2Percentage: (data['spO2Percentage'] as num?)?.toDouble(),
      waistCm: (data['waistCm'] as num?)?.toDouble(),
      hipCm: (data['hipCm'] as num?)?.toDouble(),
      stepGoal: (data['stepGoal'] as num?)?.toInt(),
      stepCount: (data['stepCount'] as num?)?.toInt(),
      completedMandatoryTasks: List<String>.from(data['completedMandatoryTasks'] as List<dynamic>? ?? []),
      createdPersonalGoals: List<String>.from(data['createdPersonalGoals'] as List<dynamic>? ?? []),
      completedPersonalGoals: List<String>.from(data['completedPersonalGoals'] as List<dynamic>? ?? []),
      activityScore: (data['activityScore'] as num?)?.toInt(),
      caloriesBurned: (data['caloriesBurned'] as num?)?.toInt(),
      breathingMinutes: (data['breathingMinutes'] as num?)?.toInt(),
      sensorStepsBaseline: (data['sensorStepsBaseline'] as num?)?.toInt(),


      // 🎯 FIX: Robust Parsing for Map
      completedHabits: data['completedHabits'] != null
          ? Map<String, bool>.from(data['completedHabits'])
          : {},
    );
  }

  factory ClientLogModel.fromJson(Map<String, dynamic> json) {
    return ClientLogModel.fromMap(json, json['id'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'dietPlanId': dietPlanId,
      'date': Timestamp.fromDate(date),
      'mealName': mealName,
      'actualFoodEaten': actualFoodEaten,
      'caloriesEstimate': caloriesEstimate,
      'isDeviation': isDeviation,
      'logStatus': logStatus.name,
      'mealPhotoUrls': mealPhotoUrls,
      'deviationTime': deviationTime != null ? Timestamp.fromDate(deviationTime!) : null,
      'clientQuery': clientQuery,
      'adminComment': adminComment,
      'adminReplied': adminReplied,
      'sleepQualityRating': sleepQualityRating,
      'hydrationLiters': hydrationLiters,
      'energyLevelRating': energyLevelRating,
      'moodLevelRating': moodLevelRating,
      'notesAndFeelings': notesAndFeelings,
      'createdAt': FieldValue.serverTimestamp(),
      'sleepTime': sleepTime != null ? Timestamp.fromDate(sleepTime!) : null,
      'wakeTime': wakeTime != null ? Timestamp.fromDate(wakeTime!) : null,
      'sleepInterruptions': sleepInterruptions,
      'totalSleepDurationHours': totalSleepDurationHours,
      'sleepScore': sleepScore,
      'weightKg': weightKg,
      'bloodPressureSystolic': bloodPressureSystolic,
      'bloodPressureDiastolic': bloodPressureDiastolic,
      'fbsMgDl': fbsMgDl,
      'ppbsMgDl': ppbsMgDl,
      'heartRateBpm': heartRateBpm,
      'spO2Percentage': spO2Percentage,
      'waistCm': waistCm,
      'hipCm': hipCm,
      'stepGoal': stepGoal,
      'stepCount': stepCount,
      'completedMandatoryTasks': completedMandatoryTasks,
      'createdPersonalGoals': createdPersonalGoals,
      'completedPersonalGoals': completedPersonalGoals,
      'activityScore': activityScore,
      'caloriesBurned': caloriesBurned,
      'breathingMinutes': breathingMinutes,
      'sensorStepsBaseline': sensorStepsBaseline,
      'completedHabits': completedHabits, // 🎯 Writes Map directly
    };
  }

  ClientLogModel copyWith({
    String? id, String? clientId, String? dietPlanId, DateTime? date, String? mealName,
    List<String>? actualFoodEaten, int? caloriesEstimate, bool? isDeviation, LogStatus? logStatus,
    List<String>? mealPhotoUrls, DateTime? deviationTime, String? clientQuery, String? adminComment, bool? adminReplied,
    int? sleepQualityRating, double? hydrationLiters, int? energyLevelRating, int? moodLevelRating, String? notesAndFeelings,
    DateTime? sleepTime, DateTime? wakeTime, int? sleepInterruptions, double? totalSleepDurationHours, int? sleepScore,
    double? weightKg, int? bloodPressureSystolic, int? bloodPressureDiastolic, double? fbsMgDl, double? ppbsMgDl,
    int? heartRateBpm, double? spO2Percentage, double? waistCm, double? hipCm,
    int? stepGoal, int? stepCount, List<String>? completedMandatoryTasks, List<String>? createdPersonalGoals, List<String>? completedPersonalGoals,
    int? activityScore, int? caloriesBurned, int? breathingMinutes, int? sensorStepsBaseline,
    Map<String, bool>? completedHabits, // 🎯 Ensure param allows Map
  }) {
    return ClientLogModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      dietPlanId: dietPlanId ?? this.dietPlanId,
      date: date ?? this.date,
      mealName: mealName ?? this.mealName,
      actualFoodEaten: actualFoodEaten ?? this.actualFoodEaten,
      caloriesEstimate: caloriesEstimate ?? this.caloriesEstimate,
      isDeviation: isDeviation ?? this.isDeviation,
      logStatus: logStatus ?? this.logStatus,
      mealPhotoUrls: mealPhotoUrls ?? this.mealPhotoUrls,
      deviationTime: deviationTime ?? this.deviationTime,
      clientQuery: clientQuery ?? this.clientQuery,
      adminComment: adminComment ?? this.adminComment,
      adminReplied: adminReplied ?? this.adminReplied,
      sleepQualityRating: sleepQualityRating ?? this.sleepQualityRating,
      hydrationLiters: hydrationLiters ?? this.hydrationLiters,
      energyLevelRating: energyLevelRating ?? this.energyLevelRating,
      moodLevelRating: moodLevelRating ?? this.moodLevelRating,
      notesAndFeelings: notesAndFeelings ?? this.notesAndFeelings,
      sleepTime: sleepTime ?? this.sleepTime,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepInterruptions: sleepInterruptions ?? this.sleepInterruptions,
      totalSleepDurationHours: totalSleepDurationHours ?? this.totalSleepDurationHours,
      sleepScore: sleepScore ?? this.sleepScore,
      weightKg: weightKg ?? this.weightKg,
      bloodPressureSystolic: bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic: bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      fbsMgDl: fbsMgDl ?? this.fbsMgDl,
      ppbsMgDl: ppbsMgDl ?? this.ppbsMgDl,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      spO2Percentage: spO2Percentage ?? this.spO2Percentage,
      waistCm: waistCm ?? this.waistCm,
      hipCm: hipCm ?? this.hipCm,
      stepGoal: stepGoal ?? this.stepGoal,
      stepCount: stepCount ?? this.stepCount,
      completedMandatoryTasks: completedMandatoryTasks ?? this.completedMandatoryTasks,
      createdPersonalGoals: createdPersonalGoals ?? this.createdPersonalGoals,
      completedPersonalGoals: completedPersonalGoals ?? this.completedPersonalGoals,
      activityScore: activityScore ?? this.activityScore,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      breathingMinutes: breathingMinutes ?? this.breathingMinutes,
      sensorStepsBaseline: sensorStepsBaseline ?? this.sensorStepsBaseline,
      // 🎯 FIX: Handle null map
      completedHabits: completedHabits ?? this.completedHabits,
    );
  }

  @override
  List<Object?> get props => [id, clientId, date, mealName, completedHabits];
}