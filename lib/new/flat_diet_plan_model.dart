import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

// ===========================================================================
// 1. NEW: ITEM TYPE ENUM
// This tells the UI how to display the item without needing nested lists.
// ===========================================================================
enum DietItemType {
  primary,      // Standard food or a "Combo Header" (e.g., Veg Thali)
  bundleChild,  // Items inside a Thali/Combo
  alternative   // An OR option for a primary item or a bundle child
}

// ===========================================================================
// 2. THE HYPER-FLAT ITEM (No more recursion!)
// ===========================================================================
class FlatDietPlanItem {
  final String id;

  // 🚀 NEW: The Adjacency Links
  final String? parentId;
  final DietItemType itemType;

  // Routing Info (Duplicated on every item so you can filter instantly)
  final String dayId;
  final String dayName;
  final String mealId;
  final String mealName;
  final int mealOrder;
  final String? mealTime;

  // Food Data
  final String foodItemId;
  final String foodItemName;
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String notes;

  // Container Flag
  final bool isBundle;


  const FlatDietPlanItem({
    required this.id,
    this.parentId,
    this.itemType = DietItemType.primary,
    required this.dayId, required this.dayName,
    required this.mealId, required this.mealName, required this.mealOrder,
    this.mealTime,
    required this.foodItemId, required this.foodItemName,
    required this.quantity, required this.unit, required this.calories,
    this.notes = '',
    this.protein = 0.0, this.carbs = 0.0, this.fat = 0.0,
    this.isBundle = false,
  });

  factory FlatDietPlanItem.createNew({
    String? parentId,
    DietItemType itemType = DietItemType.primary,
    required String dayId, required String dayName,
    required String mealId, required String mealName, required int mealOrder,
    String? mealTime,
    required String foodItemId, required String foodItemName,
    required double quantity, required String unit, required double calories,
    String notes = '',
    double protein = 0.0, double carbs = 0.0, double fat = 0.0,
    bool isBundle = false,
  }) {
    // 🛡️ SECURITY CHECK: Force primary items to have NO parent
    final safeParentId = (itemType == DietItemType.primary) ? null : parentId;

    return FlatDietPlanItem(
      id: const Uuid().v4(), // Automatically generates the unique Row ID
      parentId: safeParentId,
      itemType: itemType,
      dayId: dayId, dayName: dayName,
      mealId: mealId, mealName: mealName, mealOrder: mealOrder, mealTime: mealTime,
      foodItemId: foodItemId, foodItemName: foodItemName,
      quantity: quantity, unit: unit, calories: calories,
      notes: notes, protein: protein, carbs: carbs, fat: fat,
      isBundle: isBundle,
    );
  }

  FlatDietPlanItem copyWith({
    String? id,
    String? parentId,
    bool clearParentId = false, // 🚀 THE MAGIC FLAG
    DietItemType? itemType,
    String? dayId, String? dayName,
    String? mealId, String? mealName, int? mealOrder, String? mealTime,
    String? foodItemId, String? foodItemName,
    double? quantity, String? unit, double? calories,
    String? notes,
    double? protein, double? carbs, double? fat,
    bool? isBundle,
  }) => FlatDietPlanItem(
    id: id ?? this.id,
    // 🚀 If flag is true, force null. Otherwise, do normal fallback.
    parentId: clearParentId ? null : (parentId ?? this.parentId),
    itemType: itemType ?? this.itemType,
    dayId: dayId ?? this.dayId,
    dayName: dayName ?? this.dayName,
    mealId: mealId ?? this.mealId,
    mealName: mealName ?? this.mealName,
    mealOrder: mealOrder ?? this.mealOrder,
    mealTime: mealTime ?? this.mealTime,
    foodItemId: foodItemId ?? this.foodItemId,
    foodItemName: foodItemName ?? this.foodItemName,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    calories: calories ?? this.calories,
    notes: notes ?? this.notes,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    isBundle: isBundle ?? this.isBundle,
  );

  // 🚀 Look how clean and fast this is now! No recursive mapping.
  Map<String, dynamic> toMap() => {
    'id': id,
    'parentId': parentId,
    'itemType': itemType.name,
    'dayId': dayId, 'dayName': dayName,
    'mealId': mealId, 'mealName': mealName, 'mealOrder': mealOrder, 'mealTime': mealTime,
    'foodItemId': foodItemId, 'foodItemName': foodItemName,
    'quantity': quantity, 'unit': unit, 'calories': calories,
    'notes': notes,
    'protein': protein, 'carbs': carbs, 'fat': fat,
    'isBundle': isBundle,
  };

  // 🚀 Instantly parses from Firestore without freezing the CPU.
  factory FlatDietPlanItem.fromMap(Map<String, dynamic> map) {
    // Safely parse enum, fallback to primary if missing (for legacy data)
    final parsedType = DietItemType.values.asNameMap()[map['itemType']] ?? DietItemType.primary;

    return FlatDietPlanItem(
      id: map['id'] ?? '',
      parentId: map['parentId'],
      itemType: parsedType,
      dayId: map['dayId'] ?? '',
      dayName: map['dayName'] ?? '',
      mealId: map['mealId'] ?? '',
      mealName: map['mealName'] ?? '',
      mealOrder: (map['mealOrder'] as num?)?.toInt() ?? 99,
      mealTime: map['mealTime'] as String?,
      foodItemId: map['foodItemId'] ?? '',
      foodItemName: map['foodItemName'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
      isBundle: map['isBundle'] ?? false,
    );
  }
}

// ===========================================================================
// 3. THE MASTER PLAN (Unchanged structurally, just holds the flat list)
// ===========================================================================
class FlatMasterDietPlan {
  final String id;
  final String name;
  final String description;
  final List<String> categoryIds;
  final bool isActive;
  final bool isWeekly;
  final DateTime? updatedAt;
  final String? tenantId;
  final List<FlatDietPlanItem> allItems;

  const FlatMasterDietPlan({
    required this.id, required this.name, this.description = '',
    this.categoryIds = const [], this.isActive = true, this.isWeekly = false,
    this.updatedAt,
    this.tenantId,
    this.allItems = const [],
  });

  FlatMasterDietPlan copyWith({
    String? id, String? name, String? description,
    List<String>? categoryIds, bool? isActive, bool? isWeekly,
    DateTime? updatedAt, String? tenantId, List<FlatDietPlanItem>? allItems,
  }) => FlatMasterDietPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    categoryIds: categoryIds ?? this.categoryIds,
    isActive: isActive ?? this.isActive,
    isWeekly: isWeekly ?? this.isWeekly,
    updatedAt: updatedAt ?? this.updatedAt,
    tenantId: tenantId ?? this.tenantId,
    allItems: allItems ?? this.allItems,
  );

  Map<String, dynamic> toMetadataMap() => {
    'id': id,
    'name': name,
    'description': description,
    'categoryIds': categoryIds,
    'isActive': isActive,
    'isWeekly': isWeekly,
    'tenantId': tenantId,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'name': name,
    'description': description,
    'categoryIds': categoryIds,
    'isActive': isActive,
    'isWeekly': isWeekly,
    'tenantId': tenantId,
    'updatedAt': FieldValue.serverTimestamp(),
    'allItems': allItems.map((item) => item.toMap()).toList(),
  };

  factory FlatMasterDietPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return FlatMasterDietPlan(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      categoryIds: List<String>.from(data['categoryIds'] ?? []),
      isActive: data['isActive'] ?? true,
      isWeekly: data['isWeekly'] ?? false,
      tenantId: data['tenantId'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      allItems: (data['allItems'] as List?)?.map((x) => FlatDietPlanItem.fromMap(Map<String, dynamic>.from(x))).toList() ?? [],
    );
  }
}