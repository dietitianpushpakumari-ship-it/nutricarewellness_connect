// lib/features/diet_plan/domain/entities/client_log_model.dart (FINAL MANUAL MAPPING)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// NOTE: Ensure this enum is defined at the global scope or imported
enum LogStatus { followed, skipped, deviated, reviewed }

class ClientLogModel extends Equatable {
  final String id;
  final String clientId;
  final String dietPlanId;
  final DateTime date;
  final String mealName; // e.g., "Breakfast" OR "DAILY_WELLNESS_CHECK"

  // 🎯 CRITICAL CHANGE 1: This is now a list for readability
  final List<String> actualFoodEaten;

  final int caloriesEstimate;
  final bool isDeviation;

  // 🎯 INTERACTIVE FIELDS
  final LogStatus logStatus;
  final List<String> mealPhotoUrls;
  final DateTime? deviationTime;
  final String? clientQuery;
  final String? adminComment;
  final bool adminReplied;

  // 🎯 WELLNESS FIELDS
  final int? sleepQualityRating;
  final double? hydrationLiters;
  final int? stepCount;
  final int? energyLevelRating;
  final int? moodLevelRating;
  final String? notesAndFeelings;

  ClientLogModel({
    this.id = '',
    required this.clientId,
    required this.dietPlanId,
    required this.date,
    required this.mealName,
    this.actualFoodEaten = const [], // 🎯 Default to empty list
    this.caloriesEstimate = 0,
    this.isDeviation = false,
    this.logStatus = LogStatus.followed,
    this.mealPhotoUrls = const [],
    this.deviationTime,
    this.clientQuery,
    this.adminComment,
    this.adminReplied = false,
    // Initialize new fields
    this.sleepQualityRating,
    this.hydrationLiters,
    this.stepCount,
    this.energyLevelRating,
    this.moodLevelRating,
    this.notesAndFeelings,
  });

  // Helper to parse LogStatus enum
  static LogStatus _statusFromString(String? status) {
    if (status == null) return LogStatus.followed;
    try {
      return LogStatus.values.firstWhere((e) => e.name == status);
    } catch (e) {
      return LogStatus.followed;
    }
  }

  // 🎯 FACTORY: Manual factory to replace fromJson
  factory ClientLogModel.fromJson(Map<String, dynamic> json) {
    DateTime date;
    final dateValue = json['date'];
    if (dateValue is Timestamp) date = dateValue.toDate();
    else if (dateValue is String) date = DateTime.parse(dateValue);
    else date = DateTime.now();

    final devTimeValue = json['deviationTime'];
    DateTime? deviationTime;
    if (devTimeValue is Timestamp) deviationTime = devTimeValue.toDate();

    // 🎯 CRITICAL CHANGE 2: Read actualFoodEaten as a List<String>
    List<String> foodEatenList = [];
    final foodData = json['actualFoodEaten'];
    if (foodData is String) {
      // Handle legacy data (if it was stored as a single string)
      foodEatenList = [foodData];
    } else if (foodData is List) {
      foodEatenList = List<String>.from(foodData.whereType<String>());
    }

    return ClientLogModel(
      id: json['id'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      dietPlanId: json['dietPlanId'] as String? ?? '',
      date: date,
      mealName: json['mealName'] as String? ?? '',
      actualFoodEaten: foodEatenList, // 🎯 Assign the list
      caloriesEstimate: (json['caloriesEstimate'] as num?)?.toInt() ?? 0,
      isDeviation: json['isDeviation'] as bool? ?? false,

      logStatus: _statusFromString(json['logStatus'] as String?),
      mealPhotoUrls: List<String>.from(json['mealPhotoUrls'] as List<dynamic>? ?? []),
      deviationTime: deviationTime,
      clientQuery: json['clientQuery'] as String?,
      adminComment: json['adminComment'] as String?,
      adminReplied: json['adminReplied'] as bool? ?? false,

      sleepQualityRating: (json['sleepQualityRating'] as num?)?.toInt(),
      hydrationLiters: (json['hydrationLiters'] as num?)?.toDouble(),
      stepCount: (json['stepCount'] as num?)?.toInt(),
      energyLevelRating: (json['energyLevelRating'] as num?)?.toInt(),
      moodLevelRating: (json['moodLevelRating'] as num?)?.toInt(),
      notesAndFeelings: json['notesAndFeelings'] as String?,
    );
  }


  // 🎯 METHOD FOR WRITING DATA TO FIRESTORE
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'dietPlanId': dietPlanId,
      'date': Timestamp.fromDate(date),
      'mealName': mealName,
      'actualFoodEaten': actualFoodEaten, // 🎯 CRITICAL CHANGE 3: Save as a list
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
      'stepCount': stepCount,
      'energyLevelRating': energyLevelRating,
      'moodLevelRating': moodLevelRating,
      'notesAndFeelings': notesAndFeelings,

      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // 🎯 CRITICAL CHANGE 4: copyWith implementation
  ClientLogModel copyWith({
    // ... (omitted id, clientId, etc.) ...
    List<String>? actualFoodEaten,
    // ... (omitted wellness fields) ...
    List<String>? mealPhotoUrls,
    DateTime? deviationTime,
    LogStatus? logStatus,
    bool? adminReplied,
    String? adminComment,
    String? clientQuery,
    int? caloriesEstimate,
    bool? isDeviation,
    int? sleepQualityRating,
    double? hydrationLiters,
    int? stepCount,
    int? energyLevelRating,
    int? moodLevelRating,
    String? notesAndFeelings,
  }) {
    return ClientLogModel(
      id: id,
      clientId: clientId,
      dietPlanId: dietPlanId,
      date: date,
      mealName: mealName,
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
      stepCount: stepCount ?? this.stepCount,
      energyLevelRating: energyLevelRating ?? this.energyLevelRating,
      moodLevelRating: moodLevelRating ?? this.moodLevelRating,
      notesAndFeelings: notesAndFeelings ?? this.notesAndFeelings,
    );
  }


  factory ClientLogModel.fromMap(Map<String, dynamic> data, String docId) {
    // Safely handle date conversion
    DateTime date;
    final dateValue = data['date'];

    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is String) {
      date = DateTime.parse(dateValue);
    } else {
      date = DateTime.now();
    }

    // Safely handle deviationTime conversion
    final devTimeValue = data['deviationTime'];
    DateTime? deviationTime;
    if (devTimeValue is Timestamp) {
      deviationTime = devTimeValue.toDate();
    }

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

      // Map NEW WELLNESS FIELDS
      sleepQualityRating: (data['sleepQualityRating'] as num?)?.toInt(),
      hydrationLiters: (data['hydrationLiters'] as num?)?.toDouble(),
      stepCount: (data['stepCount'] as num?)?.toInt(),
      energyLevelRating: (data['energyLevelRating'] as num?)?.toInt(),
      moodLevelRating: (data['moodLevelRating'] as num?)?.toInt(),
      notesAndFeelings: data['notesAndFeelings'] as String?,
    );
  }


  @override
  List<Object?> get props => [
    id, clientId, dietPlanId, date, mealName, actualFoodEaten, caloriesEstimate, isDeviation, logStatus, mealPhotoUrls, deviationTime, clientQuery, adminComment, adminReplied,
    sleepQualityRating, hydrationLiters, stepCount, energyLevelRating, moodLevelRating, notesAndFeelings
  ];
}