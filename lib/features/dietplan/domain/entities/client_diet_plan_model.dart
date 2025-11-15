// lib/models/client_diet_plan_model.dart (REVISED)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';


class ClientDietPlanModel {
  final String id;
  final String clientId;
  final String masterPlanId;
  final String name;
  final String description;
  final List<String> guidelineIds;
  final List<MasterDayPlanModel> days; // The plan content
  final DateTime? assignedDate;
  final bool isActive;
  final bool isArchived;
  final bool isDeleted;
  final String? revisedFromPlanId;
  final List<String> diagnosisIds; // List of IDs from the Diagnosis Master
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

  // 🎯 NEW: ADMIN-SET MOVEMENT GOALS
  final int dailyStepGoal;
  final List<String> mandatoryDailyTasks;

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
    this.dailyStepGoal = 8000, // Default goal
    this.mandatoryDailyTasks = const [],
  });

  // For creating an editable copy during assignment
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
      diagnosisIds: const [],
      linkedVitalsId: null,
      followUpDays: 0,
      clinicalNotes: '',
      complaints: '',
      instructions: '',
      investigationIds: const [],
      suplimentIds: const [],
      isProvisional: false,
      isFreezed: false,
      isReadyToDeliver: false,
      dailyStepGoal: 0,
      mandatoryDailyTasks: const[],
    );
  }

  // Used for editing/updating status
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
    int? dailyStepGoal,
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
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      mandatoryDailyTasks: mandatoryDailyTasks ?? this.mandatoryDailyTasks,

    );
  }

  // TO FIRESTORE
  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'masterPlanId': masterPlanId,
      'name': name,
      'description': description,
      'guidelineIds': guidelineIds,
      // Embedding the single day plan directly
      'dayPlan': days.isNotEmpty ? days.first.toFirestore() : null,
      'assignedDate': Timestamp.fromDate(assignedDate!),
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
      'dailyStepGoal': dailyStepGoal ,
      'mandatoryDailyTasks': mandatoryDailyTasks,
    };
  }

  // FROM FIRESTORE
  factory ClientDietPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final dayData = data['dayPlan'] as Map<String, dynamic>?;

    final guidelineIds = data['guidelineIds'] as List<dynamic>?;

    final diagnosisIds = data['diagnosisIds'] as List<dynamic>?;

    final investigationIds = data['investigationIds'] as List<dynamic>?;

    final suplimentIds = data['suplimentIds'] as List<dynamic>?;

    final mandatoryDailyTasks = data['mandatoryDailyTasks'] as List<dynamic>?;

    // 🎯 FIX: Correctly call MasterDayPlanModel.fromMap on the embedded 'dayPlan' map
    final MasterDayPlanModel? dayPlan = dayData != null
        ? MasterDayPlanModel.fromMap(data, 'd1')
        : null;

    return ClientDietPlanModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      masterPlanId: data['masterPlanId'] ?? '',
      name: data['name'] ?? 'Untitled Plan',
      description: data['description'] ?? '',
      guidelineIds: List<String>.from(guidelineIds ?? []),
      days: dayPlan != null ? [dayPlan] : [],
      assignedDate:
          (data['assignedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      isArchived: data['isArchived'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      revisedFromPlanId: data['revisedFromPlanId'] as String?,
      diagnosisIds: List<String>.from(diagnosisIds ?? []),
      linkedVitalsId: data['linkedVitalsId'] as String?,
      followUpDays: data['followUpDays'] ?? 0,
      clinicalNotes: data['clinicalNotes'] ?? '',
      complaints: data['complaints'] ?? '',
      instructions: data['instructions'] ?? '',
      investigationIds: List<String>.from(investigationIds ?? []),
      suplimentIds: List<String>.from(suplimentIds ?? []),
      isProvisional: data['isProvisional'] ?? false,
        isFreezed:data['isFreezed'] ?? false,
      isReadyToDeliver: data['isReadyToDeliver'] ?? false,
      dailyStepGoal: data['dailyStepGoal'] ?? 8000,
      mandatoryDailyTasks:  List<String>.from(mandatoryDailyTasks ?? []),

    );
  }

  ClientDietPlanModel clone() {
    return ClientDietPlanModel(
      id: '',
      // Crucial: Reset ID for a new Firestore document
      name: 'CLONE of ${this.name}',
      description: this.description,
      clientId: this.clientId,
      isActive: this.isActive,
      // Assuming all nested model lists/objects are immutable, a shallow copy
      // of the lists is sufficient for the structure to be identical but independent.
      days: List.from(
        this.days.map((day) => day.copyWith(meals: List.from(day.meals))),
      ),
      diagnosisIds: this.diagnosisIds,
      guidelineIds: this.guidelineIds,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      mandatoryDailyTasks: mandatoryDailyTasks ?? this.mandatoryDailyTasks,

      // linkedVitalsId: this.linkedVitalsId,
      //    followUpDays : this.followUpDays,
      //   planNotes : this.planNotes
    );
  }
}
