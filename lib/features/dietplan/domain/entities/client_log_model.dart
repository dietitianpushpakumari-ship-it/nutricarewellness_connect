import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// --- 🛡️ SAFE PARSERS ---
int safeInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double safeDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

enum LogStatus { followed, skipped, deviated, reviewed }

// 🎯 Represents a single meal within the Daily Master Record
class MealEntry {
  final LogStatus status;
  final List<String> actualFoodEaten;
  final List<String> mealPhotoUrls;
  final String? clientQuery;
  final String? adminComment;
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
    try {
      DateTime? parsedDate;
      if (map['loggedAt'] != null) {
        if (map['loggedAt'] is Timestamp) {
          parsedDate = (map['loggedAt'] as Timestamp).toDate();
        } else if (map['loggedAt'] is String) {
          parsedDate = DateTime.tryParse(map['loggedAt'].toString());
        }
      }

      List<String> safeList(dynamic item) {
        if (item is List) return item.map((e) => e.toString()).toList();
        return [];
      }

      LogStatus safeStatus(dynamic s) {
        if (s == null) return LogStatus.followed;
        final str = s.toString().toLowerCase().trim();
        return LogStatus.values.firstWhere(
              (e) => e.name.toLowerCase() == str,
          orElse: () => LogStatus.followed,
        );
      }

      return MealEntry(
        status: safeStatus(map['status']),
        actualFoodEaten: safeList(map['actualFoodEaten']),
        mealPhotoUrls: safeList(map['mealPhotoUrls']),
        clientQuery: map['clientQuery']?.toString(),
        adminComment: map['adminComment']?.toString(),
        adminReplied: map['adminReplied'] == true,
        loggedAt: parsedDate,
        caloriesEstimate: safeInt(map['caloriesEstimate']),
        isDeviation: map['isDeviation'] == true,
      );
    } catch (e, stacktrace) {
      print("🚨 CRITICAL ERROR parsing MealEntry: $e\n$stacktrace");
      // Fallback object to ensure UI doesn't completely crash
      return MealEntry(status: LogStatus.followed);
    }
  }
}

// 🎯 THE MASTER DAILY RECORD
class ClientLogModel extends Equatable {
  final String id;
  final String clientId;
  final String tenantId;
  final String dietPlanId;
  final DateTime date;

  final Map<String, MealEntry> mealLogs;

  final double hydrationLiters;
  final int stepCount;
  final int sensorStepsBaseline;
  final int stepGoal;
  final int caloriesBurned;
  final int activityScore;

  final double totalSleepDurationHours;
  final int sleepScore;
  final int? sleepQualityRating;
  final int? sleepInterruptions;
  final int? energyLevelRating;
  final int? moodLevelRating;
  final DateTime? sleepTime;
  final DateTime? wakeTime;
  final String? notesAndFeelings;

  final int breathingMinutes;
  final List<String> completedMandatoryTasks;
  final List<String> createdPersonalGoals;
  final List<String> completedPersonalGoals;
  final Map<String, bool> completedHabits;

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
      stepCount: stepCount ?? this.stepCount, // 🚀 Fixed
      sensorStepsBaseline: sensorStepsBaseline ?? this.sensorStepsBaseline, // 🚀 Fixed
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
    print("========== PARSING CLIENT LOG FOR: $docId ==========");

    Map<String, MealEntry> parsedMeals = {};

    if (data['mealLogs'] != null) {
      print("-> Found mealLogs in database.");
      if (data['mealLogs'] is Map) {
        final Map mealMap = data['mealLogs'] as Map;
        mealMap.forEach((key, value) {
          print("   -> Parsing meal key: '$key'");
          try {
            if (value is Map) {
              // Extremely safe map conversion
              final Map<String, dynamic> safeStringMap = {};
              value.forEach((k, v) => safeStringMap[k.toString()] = v);

              parsedMeals[key.toString().trim()] = MealEntry.fromMap(safeStringMap);
              print("   ✅ Successfully parsed meal: '$key'");
            } else {
              print("   ❌ Skipping: Value for '$key' is not a Map. It is: ${value.runtimeType}");
            }
          } catch (e) {
            print("   🚨 ERROR parsing specific meal '$key': $e");
          }
        });
      } else {
        print("❌ mealLogs is NOT a Map. It is: ${data['mealLogs'].runtimeType}");
      }
    } else {
      print("-> mealLogs is NULL or EMPTY in this Firestore document.");
    }

    DateTime date;
    final dateValue = data['date'];
    if (dateValue is Timestamp) date = dateValue.toDate();
    else if (dateValue is String) date = DateTime.tryParse(dateValue) ?? DateTime.now();
    else date = DateTime.now();

    return ClientLogModel(
      id: docId,
      clientId: data['clientId']?.toString() ?? '',
      tenantId: data['tenantId']?.toString() ?? 'guest',
      dietPlanId: data['dietPlanId']?.toString() ?? '',
      date: date,
      mealLogs: parsedMeals,
      hydrationLiters: safeDouble(data['hydrationLiters']),
      stepCount: safeInt(data['stepCount']),
      sensorStepsBaseline: safeInt(data['sensorStepsBaseline']),
      stepGoal: safeInt(data['stepGoal'], 8000),
      caloriesBurned: safeInt(data['caloriesBurned']),
      activityScore: safeInt(data['activityScore']),
      totalSleepDurationHours: safeDouble(data['totalSleepDurationHours']),
      sleepScore: safeInt(data['sleepScore']),
      breathingMinutes: safeInt(data['breathingMinutes']),
      energyLevelRating: data['energyLevelRating'] != null ? safeInt(data['energyLevelRating']) : null,
      moodLevelRating: data['moodLevelRating'] != null ? safeInt(data['moodLevelRating']) : null,
      sleepQualityRating: data['sleepQualityRating'] != null ? safeInt(data['sleepQualityRating']) : null,
      sleepInterruptions: data['sleepInterruptions'] != null ? safeInt(data['sleepInterruptions']) : null,
      weightKg: data['weightKg'] != null ? safeDouble(data['weightKg']) : null,
      bloodPressureSystolic: data['bloodPressureSystolic'] != null ? safeInt(data['bloodPressureSystolic']) : null,
      bloodPressureDiastolic: data['bloodPressureDiastolic'] != null ? safeInt(data['bloodPressureDiastolic']) : null,
      fbsMgDl: data['fbsMgDl'] != null ? safeDouble(data['fbsMgDl']) : null,
      ppbsMgDl: data['ppbsMgDl'] != null ? safeDouble(data['ppbsMgDl']) : null,
      heartRateBpm: data['heartRateBpm'] != null ? safeInt(data['heartRateBpm']) : null,
      spO2Percentage: data['spO2Percentage'] != null ? safeDouble(data['spO2Percentage']) : null,
      waistCm: data['waistCm'] != null ? safeDouble(data['waistCm']) : null,
      hipCm: data['hipCm'] != null ? safeDouble(data['hipCm']) : null,
      sleepTime: data['sleepTime'] != null ? DateTime.tryParse(data['sleepTime'].toString()) : null,
      wakeTime: data['wakeTime'] != null ? DateTime.tryParse(data['wakeTime'].toString()) : null,
      notesAndFeelings: data['notesAndFeelings']?.toString(),
      completedMandatoryTasks: (data['completedMandatoryTasks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdPersonalGoals: (data['createdPersonalGoals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      completedPersonalGoals: (data['completedPersonalGoals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      completedHabits: data['completedHabits'] is Map
          ? (data['completedHabits'] as Map).map((k, v) => MapEntry(k.toString(), v == true))
          : {},
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