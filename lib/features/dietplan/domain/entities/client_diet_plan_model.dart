import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';

class ClientDietPlanModel {
  final String id;
  final String clientId;
  final String masterPlanId;
  final String name;
  final String description;

  final List<String> guidelineIds;
  final List<MasterDayPlanModel> days;

  final DateTime? assignedDate;
  final bool isActive;
  final bool isArchived;
  final bool isDeleted;
  final String? revisedFromPlanId;

  final List<String> diagnosisIds;
  final String? linkedVitalsId;
  final int? followUpDays;
  final String clinicalNotes;
  final String complaints;
  final String instructions;
  final List<String> investigationIds;
  final List<String> suplimentIds;

  final bool isProvisional;
  final bool isFreezed;
  final bool isReadyToDeliver;

  // 🎯 1. CORE NUMERIC GOALS
  final int dailyStepGoal;
  final double dailyWaterGoal;
  final double dailySleepGoal;
  final int dailyMindfulnessMinutes; // 🎯 NEW

  // 🎯 2. HABIT GOALS (Boolean Checks)
  final List<String> mandatoryDailyTasks; // e.g. ["Morning Sunlight", "Digital Detox"]

  const ClientDietPlanModel({
    this.id = '',
    this.clientId = '',
    this.masterPlanId = '',
    this.name = '',
    this.description = '',
    this.guidelineIds = const [],
    this.days = const [],
    this.assignedDate,
    this.isActive = true,
    this.isArchived = false,
    this.isDeleted = false,
    this.revisedFromPlanId,
    this.diagnosisIds = const [],
    this.linkedVitalsId = '',
    this.followUpDays = 0,
    this.clinicalNotes = '',
    this.complaints = '',
    this.instructions = '',
    this.investigationIds = const [],
    this.suplimentIds = const [],
    this.isProvisional = false,
    this.isFreezed = false,
    this.isReadyToDeliver = false,

    // Goals Defaults
    this.dailyStepGoal = 8000,
    this.dailyWaterGoal = 3.0,
    this.dailySleepGoal = 7.0,
    this.dailyMindfulnessMinutes = 15, // Default 15 min
    this.mandatoryDailyTasks = const [],
  });

  factory ClientDietPlanModel.fromMaster(
      MasterDietPlanModel masterPlan,
      String clientId,
      List<String> guidelineIds,
      ) {
    return ClientDietPlanModel(
      id: '',
      clientId: clientId,
      masterPlanId: masterPlan.id,
      name: masterPlan.name,
      description: masterPlan.description,
      guidelineIds: guidelineIds,
      days: masterPlan.days,
      assignedDate: DateTime.now(),
      isActive: true,
      // Defaults
      dailyStepGoal: 8000,
      dailyWaterGoal: 3.0,
      dailySleepGoal: 7.0,
      dailyMindfulnessMinutes: 15,
      mandatoryDailyTasks: const ["Morning Sunlight (15m)", "No Screens 1hr before bed"],
    );
  }

  ClientDietPlanModel copyWith({
    String? id,
    String? clientId,
    String? masterPlanId,
    String? name,
    String? description,
    List<String>? guidelineIds,
    List<MasterDayPlanModel>? days,
    DateTime? assignedDate,
    bool? isActive,
    bool? isArchived,
    bool? isDeleted,
    String? revisedFromPlanId,
    String? linkedVitalsId,
    List<String>? diagnosisIds,
    int? followUpDays,
    String? clinicalNotes,
    String? complaints,
    String? instruction,
    List<String>? investigationIds,
    List<String>? suplimentIds,
    bool? isProvisionals,
    bool? isFreezed,
    bool? isReadyToDeliver,

    // Goals
    int? dailyStepGoal,
    double? dailyWaterGoal,
    double? dailySleepGoal,
    int? dailyMindfulnessMinutes,
    List<String>? mandatoryDailyTasks,
  }) {
    return ClientDietPlanModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      masterPlanId: masterPlanId ?? this.masterPlanId,
      name: name ?? this.name,
      description: description ?? this.description,
      guidelineIds: guidelineIds ?? this.guidelineIds,
      days: days ?? this.days,
      assignedDate: assignedDate ?? this.assignedDate,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      revisedFromPlanId: revisedFromPlanId ?? this.revisedFromPlanId,
      linkedVitalsId: linkedVitalsId ?? this.linkedVitalsId,
      diagnosisIds: diagnosisIds ?? this.diagnosisIds,
      followUpDays: followUpDays ?? this.followUpDays,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      complaints: complaints ?? this.complaints,
      instructions: instruction ?? this.instructions,
      investigationIds: investigationIds ?? this.investigationIds,
      suplimentIds: suplimentIds ?? this.suplimentIds,
      isProvisional: isProvisionals ?? this.isProvisional,
      isFreezed: isFreezed ?? this.isFreezed,
      isReadyToDeliver: isReadyToDeliver ?? this.isReadyToDeliver,

      // Goals
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      dailyWaterGoal: dailyWaterGoal ?? this.dailyWaterGoal,
      dailySleepGoal: dailySleepGoal ?? this.dailySleepGoal,
      dailyMindfulnessMinutes: dailyMindfulnessMinutes ?? this.dailyMindfulnessMinutes,
      mandatoryDailyTasks: mandatoryDailyTasks ?? this.mandatoryDailyTasks,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'masterPlanId': masterPlanId,
      'name': name,
      'description': description,
      'guidelineIds': guidelineIds,
      'dayPlan': days.isNotEmpty ? days.first.toFirestore() : null,
      'assignedDate': assignedDate != null ? Timestamp.fromDate(assignedDate!) : null,
      'isActive': isActive,
      'isArchived': isArchived,
      'isDeleted': isDeleted,
      'revisedFromPlanId': revisedFromPlanId,
      'updatedAt': FieldValue.serverTimestamp(),
      'linkedVitalsId': linkedVitalsId,
      'diagnosisIds': diagnosisIds,
      'followUpDays': followUpDays,
      'clinicalNotes': clinicalNotes,
      'complaints': complaints,
      'instructions': instructions,
      'investigationIds': investigationIds,
      'suplimentIds': suplimentIds,
      'isProvisional': isProvisional,
      'isFreezed': isFreezed,
      'isReadyToDeliver' : isReadyToDeliver,

      // 🎯 Write All Goals
      'dailyStepGoal': dailyStepGoal,
      'dailyWaterGoal': dailyWaterGoal,
      'dailySleepGoal': dailySleepGoal,
      'dailyMindfulnessMinutes': dailyMindfulnessMinutes,
      'mandatoryDailyTasks': mandatoryDailyTasks,
    };
  }

  factory ClientDietPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final dayData = data['dayPlan'] as Map<String, dynamic>?;
    final MasterDayPlanModel? dayPlan = dayData != null
        ? MasterDayPlanModel.fromMap(data, 'd1')
        : null;

    return ClientDietPlanModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      masterPlanId: data['masterPlanId'] ?? '',
      name: data['name'] ?? 'Untitled Plan',
      description: data['description'] ?? '',
      guidelineIds: List<String>.from(data['guidelineIds'] ?? []),
      days: dayPlan != null ? [dayPlan] : [],
      assignedDate: (data['assignedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      isArchived: data['isArchived'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      revisedFromPlanId: data['revisedFromPlanId'] as String?,
      diagnosisIds: List<String>.from(data['diagnosisIds'] ?? []),
      linkedVitalsId: data['linkedVitalsId'] as String?,
      followUpDays: data['followUpDays'] ?? 0,
      clinicalNotes: data['clinicalNotes'] ?? '',
      complaints: data['complaints'] ?? '',
      instructions: data['instructions'] ?? '',
      investigationIds: List<String>.from(data['investigationIds'] ?? []),
      suplimentIds: List<String>.from(data['suplimentIds'] ?? []),
      isProvisional: data['isProvisional'] ?? false,
      isFreezed: data['isFreezed'] ?? false,
      isReadyToDeliver: data['isReadyToDeliver'] ?? false,

      // 🎯 Read All Goals (With Defaults)
      dailyStepGoal: (data['dailyStepGoal'] as num?)?.toInt() ?? 8000,
      dailyWaterGoal: (data['dailyWaterGoal'] as num?)?.toDouble() ?? 3.0,
      dailySleepGoal: (data['dailySleepGoal'] as num?)?.toDouble() ?? 7.0,
      dailyMindfulnessMinutes: (data['dailyMindfulnessMinutes'] as num?)?.toInt() ?? 15,
      mandatoryDailyTasks: List<String>.from(data['mandatoryDailyTasks'] ?? []),
    );
  }

  ClientDietPlanModel clone() {
    return ClientDietPlanModel(
      id: '',
      name: 'CLONE of ${this.name}',
      description: this.description,
      clientId: this.clientId,
      isActive: this.isActive,
      days: List.from(this.days.map((day) => day.copyWith(meals: List.from(day.meals)))),
      diagnosisIds: this.diagnosisIds,
      guidelineIds: this.guidelineIds,

      // Clone Goals
      dailyStepGoal: dailyStepGoal,
      dailyWaterGoal: dailyWaterGoal,
      dailySleepGoal: dailySleepGoal,
      dailyMindfulnessMinutes: dailyMindfulnessMinutes,
      mandatoryDailyTasks: List.from(mandatoryDailyTasks),
    );
  }
}