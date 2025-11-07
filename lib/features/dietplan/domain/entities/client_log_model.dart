// lib/features/diet_plan/domain/entities/client_log_model.dart (FINAL MANUAL MAPPING)

import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// NOTE: Ensure this enum is defined at the global scope or imported
enum LogStatus { followed, skipped, deviated, reviewed }

class ClientLogModel extends Equatable {
  final String id;
  final String clientId;
  final String dietPlanId;
  final DateTime date;
  final String mealName;
  final String actualFoodEaten;
  final int caloriesEstimate;
  final bool isDeviation;

  // 🎯 INTERACTIVE FIELDS
  final LogStatus logStatus;
  final List<String> mealPhotoUrls;
  final DateTime? deviationTime;
  final String? clientQuery;
  final String? adminComment;
  final bool adminReplied;

  ClientLogModel({
    this.id = '',
    required this.clientId,
    required this.dietPlanId,
    required this.date,
    required this.mealName,
    required this.actualFoodEaten,
    this.caloriesEstimate = 0,
    this.isDeviation = false,
    this.logStatus = LogStatus.followed,
    this.mealPhotoUrls = const [],
    this.deviationTime,
    this.clientQuery,
    this.adminComment,
    this.adminReplied = false,
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

  // Factory to read from Firestore (for the repository)
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
      actualFoodEaten: data['actualFoodFoodEaten'] as String? ?? '',
      caloriesEstimate: (data['caloriesEstimate'] as num?)?.toInt() ?? 0,
      isDeviation: data['isDeviation'] as bool? ?? false,

      logStatus: _statusFromString(data['logStatus'] as String?),
      mealPhotoUrls: List<String>.from(data['mealPhotoUrls'] as List<dynamic>? ?? []),
      deviationTime: deviationTime,
      clientQuery: data['clientQuery'] as String?,
      adminComment: data['adminComment'] as String?,
      adminReplied: data['adminReplied'] as bool? ?? false,
    );
  }

  // Alias for compatibility with repository structure
  factory ClientLogModel.fromJson(Map<String, dynamic> json) => ClientLogModel.fromMap(json, json['id'] ?? '');


  // Method for writing data to Firestore
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
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // 🎯 CRITICAL FIX: Complete and correct copyWith implementation
  ClientLogModel copyWith({
    List<String>? mealPhotoUrls,
    DateTime? deviationTime,
    LogStatus? logStatus,
    bool? adminReplied,
    String? adminComment,
    String? clientQuery,
    String? actualFoodEaten,
    int? caloriesEstimate,
    bool? isDeviation,
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
      mealPhotoUrls: mealPhotoUrls ?? this.mealPhotoUrls, // 🎯 FIXED PARAMETER
      deviationTime: deviationTime ?? this.deviationTime,
      clientQuery: clientQuery ?? this.clientQuery,
      adminComment: adminComment ?? this.adminComment,
      adminReplied: adminReplied ?? this.adminReplied,
    );
  }

  @override
  List<Object?> get props => [id, clientId, dietPlanId, date, mealName, actualFoodEaten, caloriesEstimate, isDeviation, logStatus, mealPhotoUrls, deviationTime, clientQuery, adminComment, adminReplied];
}