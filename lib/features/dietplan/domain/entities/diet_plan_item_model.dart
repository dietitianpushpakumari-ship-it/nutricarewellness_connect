import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // 🎯 Use standard package instead

// 🎯 REMOVED: Custom 'extension IterableExtensions' block to avoid conflicts.

// --- CORE MODELS ---

class FoodItemAlternative {
  final String id;
  final String foodItemId;
  final String foodItemName;
  final double quantity;
  final String unit;

  @override bool operator ==(Object other) => other is FoodItemAlternative && other.id == id;
  @override int get hashCode => id.hashCode;
  String get displayQuantity => '${quantity.toStringAsFixed(1)} $unit';

  const FoodItemAlternative({
    required this.id, required this.foodItemId, required this.foodItemName,
    required this.quantity, required this.unit
  });

  // TO FIREBASE
  Map<String, dynamic> toFirestore() => {
    'foodItemId': foodItemId,
    'foodItemName': foodItemName,
    'quantity': quantity,
    'unit': unit,
  };
  // FROM FIREBASE
  factory FoodItemAlternative.fromFirestore(Map<String, dynamic> data, String altId) => FoodItemAlternative(
    id: altId,
    foodItemId: data['foodItemId'] as String? ?? '',
    foodItemName: data['foodItemName'] as String? ?? '',
    quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
    unit: data['unit'] as String? ?? '',
  );
}

class DietPlanItemModel {
  final String id;
  final String foodItemId;
  final String foodItemName;
  final double quantity;
  final String unit;
  final String notes;
  final List<FoodItemAlternative> alternatives;

  const DietPlanItemModel({
    required this.id, required this.foodItemId, required this.foodItemName,
    required this.quantity, required this.unit, this.notes = '',
    this.alternatives = const []
  });

  DietPlanItemModel copyWith({List<FoodItemAlternative>? alternatives, double? quantity}) => DietPlanItemModel(
      id: id, foodItemId: foodItemId, foodItemName: foodItemName,
      quantity: quantity ?? this.quantity, unit: unit, notes: notes,
      alternatives: alternatives ?? this.alternatives
  );

  // TO FIREBASE
  Map<String, dynamic> toFirestore() => {
    'foodItemId': foodItemId,
    'foodItemName': foodItemName,
    'quantity': quantity,
    'unit': unit,
    'notes': notes,
    'alternatives': {
      for (var alt in alternatives) alt.id: alt.toFirestore()
    },
  };
  // FROM FIREBASE
  factory DietPlanItemModel.fromFirestore(Map<String, dynamic> data, String itemId) {
    final alternativesData = data['alternatives'] as Map<String, dynamic>? ?? {};
    final alternativesList = alternativesData.entries.map((e) =>
        FoodItemAlternative.fromFirestore(e.value as Map<String, dynamic>, e.key)
    ).toList();

    return DietPlanItemModel(
      id: itemId,
      foodItemId: data['foodItemId'] as String? ?? '',
      foodItemName: data['foodItemName'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      alternatives: alternativesList,
    );
  }
}

class DietPlanMealModel {
  final String id;
  final String mealNameId;
  final String mealName;
  final List<DietPlanItemModel> items;
  final int order;

  const DietPlanMealModel({
    required this.id, required this.mealNameId, required this.mealName, required this.order,
    this.items = const []
  });

  DietPlanMealModel copyWith({List<DietPlanItemModel>? items}) => DietPlanMealModel(
      id: id, mealNameId: mealNameId, mealName: mealName, items: items ?? this.items, order: this.order
  );
  // TO FIREBASE
  Map<String, dynamic> toFirestore() => {
    'mealNameId': mealNameId,
    'mealName': mealName,
    'items': {
      for (var item in items) item.id: item.toFirestore()
    },
    'order' : order
  };
  // FROM FIREBASE
  factory DietPlanMealModel.fromFirestore(Map<String, dynamic> data, String mealId) {
    final itemsData = data['items'] as Map<String, dynamic>? ?? {};
    final itemsList = itemsData.entries.map((e) =>
        DietPlanItemModel.fromFirestore(e.value as Map<String, dynamic>, e.key)
    ).toList();

    return DietPlanMealModel(
        id: mealId,
        mealNameId: data['mealNameId'] as String? ?? '',
        mealName: data['mealName'] as String? ?? 'Unknown Meal',
        items: itemsList,
        order: data['order'] ?? 99
    );
  }
}

class MasterDayPlanModel {
  final String id;
  final String dayName;
  final List<DietPlanMealModel> meals;

  const MasterDayPlanModel({
    required this.id, required this.dayName, this.meals = const []
  });

  MasterDayPlanModel copyWith({List<DietPlanMealModel>? meals}) => MasterDayPlanModel(
      id: id, dayName: dayName, meals: meals ?? this.meals
  );

  // TO FIREBASE (Used for embedding or root)
  Map<String, dynamic> toFirestore() => {
    'dayName': dayName,
    'meals': {
      for (var meal in meals) meal.id: meal.toFirestore()
    },
  };

  factory MasterDayPlanModel.fromMap(Map<String, dynamic> data, String id) {
    final mealsData = data['dayPlan'] != null && data['dayPlan']['meals'] != null
        ? data['dayPlan']['meals'] as Map<String, dynamic>
        : <String, dynamic>{};

    final mealsList = mealsData.entries.map((e) =>
        DietPlanMealModel.fromFirestore(e.value as Map<String, dynamic>, e.key)
    ).toList();

    return MasterDayPlanModel(
      id: id,
      dayName: data['dayPlan'] != null ? data['dayPlan']['dayName'] as String? ?? 'Fixed Day' : 'Fixed Day',
      meals: mealsList,
    );
  }

  factory MasterDayPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MasterDayPlanModel.fromMap(data, doc.id);
  }
}

class MasterDietPlanModel {
  final String id;
  final String name;
  final String description;
  final List<String> dietPlanCategoryIds;
  final List<MasterDayPlanModel> days;
  final bool isActive;

  const MasterDietPlanModel({
    this.id = '',
    this.name = '',
    this.description = '',
    this.dietPlanCategoryIds = const [],
    this.days = const [],
    this.isActive = true,
  });

  MasterDietPlanModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? dietPlanCategoryIds,
    List<MasterDayPlanModel>? days,
    bool? isActive,
  }) => MasterDietPlanModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    dietPlanCategoryIds: dietPlanCategoryIds ?? this.dietPlanCategoryIds,
    days: days ?? this.days,
    isActive: isActive ?? this.isActive ,
  );

  MasterDietPlanModel clone() {
    return MasterDietPlanModel(
      id: '',
      name: 'CLONE of ${this.name}',
      description: this.description,
      dietPlanCategoryIds: this.dietPlanCategoryIds,
      isActive: this.isActive,
      days: List.from(this.days.map((day) => day.copyWith(meals: List.from(day.meals)))),
    );
  }

  Map<String, dynamic> toFirestore() {
    final dayData = days.isNotEmpty
        ? days.first.toFirestore()
        : MasterDayPlanModel(id: 'd1', dayName: 'Fixed Day').toFirestore();

    return {
      'id' : id,
      'name': name,
      'description': description,
      'dietPlanCategoryIds': dietPlanCategoryIds,
      'dayPlan': dayData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive' : isActive
    };
  }

  factory MasterDietPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw StateError('MasterDietPlan document data is null for ID: ${doc.id}');

    final dayPlan = MasterDayPlanModel.fromFirestore(doc);

    return MasterDietPlanModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Untitled Plan',
      description: data['description'] as String? ?? '',
      dietPlanCategoryIds: List<String>.from(data['dietPlanCategoryIds'] as List? ?? []),
      days: [dayPlan],
      isActive: data['isActive'] ?? true,
    );
  }
}