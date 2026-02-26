import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/new/models/diet_plan_item_model.dart';


class ClientDietPlanModel {
  final String id;
  final String clientId;
  final String? tenantId; // 🔒 Multi-Tenant ID
  final String masterPlanId;
  final String name;
  final String description;
  final List<MasterDayPlanModel> days;
  final bool isActive;
  final bool isArchived;
  final bool isDeleted;
  final String? revisedFromPlanId;
  final bool isProvisional;
  final bool isFreezed;
  final bool isReadyToDeliver;

  // 🎯 NEW GOAL FIELDS
  final double dailyWaterGoal;       // Liters (e.g., 3.0)
  final double dailySleepGoal;       // Hours (e.g., 7.5)
  final int dailyStepGoal;           // Steps (e.g., 8000)
  final int dailyMindfulnessMinutes; // Minutes (e.g., 15)
  final List<String> assignedHabits; // IDs from Habit Master
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? assignedDate;
  final double? targetWeightKg;
  final String? sessionId;
  final double? targetCalories;
  final String? dietType;

  final List<String> mandatoryDailyTasks;

  const ClientDietPlanModel({
    this.id = '',
    this.clientId = '',
    this.tenantId, // 🔒 Init
    this.masterPlanId = '',
    this.name = '',
    this.description = '',
    this.days = const [],
    this.isActive = true,
    this.isArchived = false,
    this.isDeleted = false,
    this.revisedFromPlanId,
    this.isProvisional = false,
    this.isFreezed = false,
    this.isReadyToDeliver = false,
    // 🎯 Defaults
    this.dailyWaterGoal = 3.0,
    this.dailySleepGoal = 7.0,
    this.dailyStepGoal = 5000,
    this.dailyMindfulnessMinutes = 10,
    this.assignedHabits = const [],
    this.createdAt,
    this.updatedAt,
    this.assignedDate,
    this.targetWeightKg,
    this.sessionId,
    this.targetCalories,
    this.dietType,
    this.mandatoryDailyTasks = const [],
  });

  // For creating an editable copy
  factory ClientDietPlanModel.fromMaster(
      MasterDietPlanModel masterPlan,
      String clientId,
      List<String> guidelineIds, {
        String? tenantId, // 🔒 Optional tenant injection
      }) {
    final now = Timestamp.now();

    return ClientDietPlanModel(
      id: '',
      clientId: clientId,
      tenantId: tenantId, // 🔒
      masterPlanId: masterPlan.id,
      name: masterPlan.name,
      description: masterPlan.description,
      days: masterPlan.days,

      assignedDate: now,
      createdAt: now,
      updatedAt: now,

      isProvisional: true,
      isActive: true,
      mandatoryDailyTasks: const ["Morning Sunlight (15m)", "No Screens 1hr before bed"],

    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'tenantId': tenantId, // 🔒 Save
      'masterPlanId': masterPlanId,
      'name': name,
      'description': description,

      // 🎯 If days is a list of objects with their own toFirestore
      'dayPlan': days.isNotEmpty ? (days.first is Map ? days.first : days.first.toFirestore()) : null,
      'days': days.map((e) => e is Map ? e : e.toFirestore()).toList(),

      'assignedDate': assignedDate ?? FieldValue.serverTimestamp(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      'isActive': isActive,
      'isArchived': isArchived,
      'isDeleted': isDeleted,
      'isProvisional': isProvisional,
      'isFreezed': isFreezed,
      'isReadyToDeliver': isReadyToDeliver,
      'revisedFromPlanId': revisedFromPlanId,
      // 🎯 Goals & Metrics
      'dailyWaterGoal': dailyWaterGoal,
      'dailySleepGoal': dailySleepGoal,
      'dailyStepGoal': dailyStepGoal,
      'targetWeightKg': targetWeightKg,
      'dailyMindfulnessMinutes': dailyMindfulnessMinutes,
      'assignedHabits': assignedHabits,
      'sessionId': sessionId,
      'targetCalories': targetCalories,
      'dietType': dietType
    };
  }

  factory ClientDietPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // 🎯 Handle the 'days' list or 'dayPlan' fallback
    List<MasterDayPlanModel> parsedDays = [];
    if (data['days'] != null) {
      parsedDays = (data['days'] as List)
          .map((d) => MasterDayPlanModel.fromMap(d as Map<String, dynamic>, ''))
          .toList();
    } else if (data['dayPlan'] != null) {
      // Fallback if only single dayPlan exists
      parsedDays = [MasterDayPlanModel.fromMap(data['dayPlan'], 'd1')];
    }

    return ClientDietPlanModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      tenantId: data['tenantId'] as String?, // 🔒 Read
      masterPlanId: data['masterPlanId'] ?? '',
      name: data['name'] ?? 'Untitled Plan',
      description: data['description'] ?? '',
      days: parsedDays,

      assignedDate: data['assignedDate'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,

      isActive: data['isActive'] ?? true,
      isArchived: data['isArchived'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      isProvisional: data['isProvisional'] ?? false,
      isFreezed: data['isFreezed'] ?? false,
      isReadyToDeliver: data['isReadyToDeliver'] ?? false,

      revisedFromPlanId: data['revisedFromPlanId'],

      // 🎯 Goals & Metrics
      targetWeightKg: (data['targetWeightKg'] as num?)?.toDouble(),
      dailyWaterGoal: (data['dailyWaterGoal'] as num?)?.toDouble() ?? 3.0,
      dailySleepGoal: (data['dailySleepGoal'] as num?)?.toDouble() ?? 7.0,
      dailyStepGoal: (data['dailyStepGoal'] as num?)?.toInt() ?? 5000,
      dailyMindfulnessMinutes: (data['dailyMindfulnessMinutes'] as num?)?.toInt() ?? 10,
      assignedHabits: List<String>.from(data['assignedHabits'] ?? []),
      sessionId: data['sessionId'],
      targetCalories: (data['targetCalories'] as num?)?.toDouble(),
      dietType: data['dietType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'tenantId': tenantId, // 🔒 Save
      'name': name,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'assignedDate': assignedDate ?? FieldValue.serverTimestamp(),
      'dailyWaterGoal': dailyWaterGoal,
      'dailyStepGoal': dailyStepGoal,
      'dailySleepGoal': dailySleepGoal,
      'targetWeightKg': targetWeightKg,
      'isProvisional': isProvisional,
      'isDeleted': isDeleted,
      'sessionId': sessionId,
      'days': days.map((day) => day.toFirestore()).toList(),
      'targetCalories': targetCalories,
      'dietType': dietType
    };
  }

  factory ClientDietPlanModel.fromMap(Map<String, dynamic> map, String id) {
    // 🎯 Parse days safely
    List<MasterDayPlanModel> parsedDays = [];
    if (map['days'] != null && map['days'] is List) {
      parsedDays = (map['days'] as List)
          .map((d) => MasterDayPlanModel.fromMap(d as Map<String, dynamic>, ''))
          .toList();
    }

    return ClientDietPlanModel(
      id: id,
      clientId: map['clientId'] ?? '',
      tenantId: map['tenantId'] as String?, // 🔒 Read
      name: map['name'] ?? '',
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
      assignedDate: map['assignedDate'] as Timestamp?,
      dailyWaterGoal: (map['dailyWaterGoal'] as num?)?.toDouble() ?? 3.0,
      dailyStepGoal: (map['dailyStepGoal'] as num?)?.toInt() ?? 5000,
      dailySleepGoal: (map['dailySleepGoal'] as num?)?.toDouble() ?? 7.0,
      targetWeightKg: (map['targetWeightKg'] as num?)?.toDouble(),
      isProvisional: map['isProvisional'] ?? true,
      days: parsedDays,
      sessionId: map['sessionId'],
      targetCalories: (map['targetCalories'] as num?)?.toDouble(),
      dietType: map['dietType'] ?? '',
    );
  }

  ClientDietPlanModel copyWith({
    String? id,
    String? clientId,
    String? tenantId, // 🔒 Param
    String? masterPlanId,
    String? name,
    String? description,
    Timestamp? assignedDate,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    List<MasterDayPlanModel>? days,
    List<String>? assignedHabits,
    double? targetWeightKg,
    double? dailyWaterGoal,
    double? dailySleepGoal,
    int? dailyStepGoal,
    int? dailyMindfulnessMinutes,
    bool? isProvisional,
    bool? isActive,
    bool? isArchived,
    bool? isDeleted,
    bool? isFreezed,
    bool? isReadyToDeliver,
    String? revisedFromPlanId,
    int? followUpDays,
    String? sessionId,
    double? targetCalories,
    String? dietType,
  }) {
    return ClientDietPlanModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      tenantId: tenantId ?? this.tenantId, // 🔒 Assign
      masterPlanId: masterPlanId ?? this.masterPlanId,
      name: name ?? this.name,
      description: description ?? this.description,
      assignedDate: assignedDate ?? this.assignedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      days: days ?? this.days,
      assignedHabits: assignedHabits ?? this.assignedHabits,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      dailyWaterGoal: dailyWaterGoal ?? this.dailyWaterGoal,
      dailySleepGoal: dailySleepGoal ?? this.dailySleepGoal,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      dailyMindfulnessMinutes: dailyMindfulnessMinutes ?? this.dailyMindfulnessMinutes,
      isProvisional: isProvisional ?? this.isProvisional,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isFreezed: isFreezed ?? this.isFreezed,
      isReadyToDeliver: isReadyToDeliver ?? this.isReadyToDeliver,
      revisedFromPlanId: revisedFromPlanId ?? this.revisedFromPlanId,
      sessionId: sessionId ?? this.sessionId,
      targetCalories: targetCalories ?? this.targetCalories,
      dietType: dietType ?? this.dietType,
    );
  }
}