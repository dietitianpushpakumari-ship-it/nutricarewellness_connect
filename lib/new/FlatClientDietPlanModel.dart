import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:pure_shift/new/flat_diet_plan_model.dart';
import 'package:uuid/uuid.dart';

class FlatClientDietPlanModel {
  final String id;
  final String clientId;
  final String? tenantId;
  final String masterPlanId;
  final String name;
  final String description;
  final bool isActive;
  final bool isArchived;
  final bool isDeleted;
  final String? revisedFromPlanId;
  final bool isProvisional;
  final bool isFreezed;
  final bool isReadyToDeliver;

  // 🎯 GOAL FIELDS
  final double dailyWaterGoal;
  final double dailySleepGoal;
  final int dailyStepGoal;
  final int dailyMindfulnessMinutes;
  final List<String> assignedHabits;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? assignedDate;
  final double? targetWeightKg;
  final String? sessionId;
  final double? targetCalories;
  final String? dietType;

  // 🚀 THE FLAT LIST
  final List<FlatDietPlanItem> allItems;

  const FlatClientDietPlanModel({
    this.id = '',
    this.clientId = '',
    this.tenantId,
    this.masterPlanId = '',
    this.name = '',
    this.description = '',
    this.isActive = true,
    this.isArchived = false,
    this.isDeleted = false,
    this.revisedFromPlanId,
    this.isProvisional = false,
    this.isFreezed = false,
    this.isReadyToDeliver = false,
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
    this.allItems = const [],
  });

  // 🌉 BRIDGE: Create Client Plan from Flat Master Plan
  factory FlatClientDietPlanModel.fromMaster(
      FlatMasterDietPlan masterPlan,
      String clientId, {
        String? tenantId,
        String? sessionId,
      }) {
    final now = Timestamp.now();
    const uuid = Uuid();

    // =========================================================================
    // 🚀 THE FIX: HYPER-FLAT ID RE-MAPPING WITH SANITIZATION
    // =========================================================================
    // 1. Create a dictionary to remember which old Master ID becomes which new Client ID
    final Map<String, String> idMap = {};
    for (var item in masterPlan.allItems) {
      idMap[item.id] = uuid.v4();
    }

    // 2. Clone the items, assigning fresh IDs AND sanitizing bad links
    final List<FlatDietPlanItem> deepClonedItems = masterPlan.allItems.map((item) {
      final newId = idMap[item.id]!;
      String? newParentId = item.parentId != null ? idMap[item.parentId] : null;
      DietItemType newType = item.itemType;

      // 🛡️ SECURITY RULE 1: Primary items CANNOT have parents.
      if (newType == DietItemType.primary && newParentId != null) {
        newParentId = null;
      }

      // 🛡️ SECURITY RULE 2: Prevent self-parenting loops.
      if (newParentId != null && newId == newParentId) {
        newParentId = null;
        newType = DietItemType.primary;
      }

      // 🚀 USE clearParentId FLAG TO OVERRIDE DART'S NULL HANDLING BUG
      return item.copyWith(
        id: newId,
        parentId: newParentId,
        itemType: newType,
        clearParentId: newParentId == null,
      );
    }).toList();

    return FlatClientDietPlanModel(
      id: '',
      clientId: clientId,
      tenantId: tenantId,
      masterPlanId: masterPlan.id,
      name: masterPlan.name,
      description: masterPlan.description,
      allItems: deepClonedItems, // 🚀 Uses the safely cloned, scrubbed flat list

      assignedDate: now,
      createdAt: now,
      updatedAt: now,
      sessionId: sessionId,

      isProvisional: true,
      isActive: true,
    );
  }

  // =========================================================================
  // 🚀 METADATA MAP FOR DAY-SHARDING ARCHITECTURE
  // =========================================================================
  Map<String, dynamic> toMetadataMap() {
    return {
      'clientId': clientId,
      'tenantId': tenantId,
      'masterPlanId': masterPlanId,
      'name': name,
      'description': description,
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
      'dailyWaterGoal': dailyWaterGoal,
      'dailySleepGoal': dailySleepGoal,
      'dailyStepGoal': dailyStepGoal,
      'targetWeightKg': targetWeightKg,
      'dailyMindfulnessMinutes': dailyMindfulnessMinutes,
      'assignedHabits': assignedHabits,
      'sessionId': sessionId,
      'targetCalories': targetCalories,
      'dietType': dietType,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'tenantId': tenantId,
      'masterPlanId': masterPlanId,
      'name': name,
      'description': description,
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
      'dailyWaterGoal': dailyWaterGoal,
      'dailySleepGoal': dailySleepGoal,
      'dailyStepGoal': dailyStepGoal,
      'targetWeightKg': targetWeightKg,
      'dailyMindfulnessMinutes': dailyMindfulnessMinutes,
      'assignedHabits': assignedHabits,
      'sessionId': sessionId,
      'targetCalories': targetCalories,
      'dietType': dietType,
      'allItems': allItems.map((e) => e.toMap()).toList(),
    };
  }

  factory FlatClientDietPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // =========================================================================
    // 🚀 THE FIX: BULLETPROOF ARRAY PARSING
    // =========================================================================
    List<FlatDietPlanItem> parsedItems = [];

    if (data['allItems'] != null && data['allItems'] is List) {
      final rawList = data['allItems'] as List;
      for (var item in rawList) {
        try {
          // Safely cast and parse each item individually
          if (item is Map) {
            parsedItems.add(FlatDietPlanItem.fromMap(Map<String, dynamic>.from(item)));
          }
        } catch (e) {
          debugPrint("⚠️ Skipped corrupt food item in plan ${doc.id}: $e");
        }
      }
    } else {
      debugPrint("🚨 WARNING: 'allItems' field is completely missing in Firestore document ${doc.id}!");
    }

    return FlatClientDietPlanModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      tenantId: data['tenantId'] as String?,
      masterPlanId: data['masterPlanId'] ?? '',
      name: data['name'] ?? 'Untitled Plan',
      description: data['description'] ?? '',
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
      targetWeightKg: (data['targetWeightKg'] as num?)?.toDouble(),
      dailyWaterGoal: (data['dailyWaterGoal'] as num?)?.toDouble() ?? 3.0,
      dailySleepGoal: (data['dailySleepGoal'] as num?)?.toDouble() ?? 7.0,
      dailyStepGoal: (data['dailyStepGoal'] as num?)?.toInt() ?? 5000,
      dailyMindfulnessMinutes: (data['dailyMindfulnessMinutes'] as num?)?.toInt() ?? 10,
      assignedHabits: List<String>.from(data['assignedHabits'] ?? []),
      sessionId: data['sessionId'],
      targetCalories: (data['targetCalories'] as num?)?.toDouble(),
      dietType: data['dietType'],

      // 🚀 Inject our safely parsed list here!
      allItems: parsedItems,
    );
  }
  FlatClientDietPlanModel copyWith({
    String? id,
    String? clientId,
    String? tenantId,
    String? masterPlanId,
    String? name,
    String? description,
    Timestamp? assignedDate,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    List<FlatDietPlanItem>? allItems,
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
    String? sessionId,
    double? targetCalories,
    String? dietType,
  }) {
    return FlatClientDietPlanModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      tenantId: tenantId ?? this.tenantId,
      masterPlanId: masterPlanId ?? this.masterPlanId,
      name: name ?? this.name,
      description: description ?? this.description,
      assignedDate: assignedDate ?? this.assignedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      allItems: allItems ?? this.allItems,
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