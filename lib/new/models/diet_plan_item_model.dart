import 'package:cloud_firestore/cloud_firestore.dart';

// --- UTILITY EXTENSIONS ---
extension IterableExtensions<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// --- SAFE PARSERS ---
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

// --- CORE MODELS ---

class FoodItemAlternative {
  final String id;
  final String foodItemId;
  final String foodItemName;
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  @override bool operator ==(Object other) => other is FoodItemAlternative && other.id == id;
  @override int get hashCode => id.hashCode;
  String get displayQuantity => '${quantity.toStringAsFixed(1)} $unit';

  const FoodItemAlternative({
    required this.id, required this.foodItemId, required this.foodItemName,
    required this.quantity, required this.unit, required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toFirestore() => {
    'foodItemId': foodItemId,
    'foodItemName': foodItemName,
    'quantity': quantity,
    'unit': unit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat
  };

  factory FoodItemAlternative.fromFirestore(Map<String, dynamic> data, String altId) => FoodItemAlternative(
    id: altId,
    foodItemId: data['foodItemId']?.toString() ?? '',
    foodItemName: data['foodItemName']?.toString() ?? '',
    // 🎯 FIXED: Replaced strict num? casting with safeDouble
    quantity: safeDouble(data['quantity']),
    unit: data['unit']?.toString() ?? '',
    calories: safeDouble(data['calories']),
    protein: safeDouble(data['protein']),
    carbs: safeDouble(data['carbs']),
    fat: safeDouble(data['fat']),
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
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? alternativeGroupId;

  const DietPlanItemModel({
    required this.id, required this.foodItemId, required this.foodItemName,
    required this.quantity, required this.unit, this.notes = '',
    this.alternatives = const [], required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.alternativeGroupId,
  });

  DietPlanItemModel copyWith({
    String? id,
    String? foodItemId,
    String? foodItemName,
    double? quantity,
    String? unit,
    String? notes,
    List<FoodItemAlternative>? alternatives,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) => DietPlanItemModel(
      id: id ?? this.id,
      foodItemId: foodItemId ?? this.foodItemId,
      foodItemName: foodItemName ?? this.foodItemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      alternatives: alternatives ?? this.alternatives,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat
  );

  Map<String, dynamic> toFirestore() => {
    'foodItemId': foodItemId,
    'foodItemName': foodItemName,
    'quantity': quantity,
    'unit': unit,
    'notes': notes,
    'alternatives': {
      for (var alt in alternatives) alt.id: alt.toFirestore()
    },
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory DietPlanItemModel.fromFirestore(Map<String, dynamic> data, String itemId) {
    final alternativesData = data['alternatives'];
    List<FoodItemAlternative> alternativesList = [];

    // 🎯 FIXED: Safely handle Alternatives whether they are a Map or a List
    if (alternativesData is Map) {
      alternativesList = alternativesData.entries.map((e) {
        if (e.value is Map) {
          return FoodItemAlternative.fromFirestore(Map<String, dynamic>.from(e.value), e.key.toString());
        }
        return null;
      }).whereType<FoodItemAlternative>().toList();
    } else if (alternativesData is List) {
      alternativesList = alternativesData.map((e) {
        if (e is Map) {
          final map = Map<String, dynamic>.from(e);
          return FoodItemAlternative.fromFirestore(map, map['id']?.toString() ?? '');
        }
        return null;
      }).whereType<FoodItemAlternative>().toList();
    }

    return DietPlanItemModel(
      id: itemId,
      foodItemId: data['foodItemId']?.toString() ?? '',
      foodItemName: data['foodItemName']?.toString() ?? '',
      unit: data['unit']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      alternatives: alternativesList,
      quantity: safeDouble(data['quantity']),
      calories: safeDouble(data['calories']),
      protein: safeDouble(data['protein']),
      carbs: safeDouble(data['carbs']),
      fat: safeDouble(data['fat']),
    );
  }
}

class DietPlanMealModel {
  final String id;
  final String mealNameId;
  final String mealName;
  final List<DietPlanItemModel> items;
  final int order;
  final String? time;

  const DietPlanMealModel({
    required this.id, required this.mealNameId, required this.mealName, required this.order,
    this.items = const [],this.time,
  });

  DietPlanMealModel copyWith({String? id,List<DietPlanItemModel>? items, String? mealName, int? order,String? time}) => DietPlanMealModel(
    id: id ?? this.id,
    mealNameId: mealNameId,
    mealName: mealName ?? this.mealName,
    items: items ?? this.items,
    order: order ?? this.order,
    time: time ?? this.time,
  );

  Map<String, dynamic> toFirestore() => {
    'mealNameId': mealNameId,
    'mealName': mealName,
    'time': time,
    'items': {
      for (var item in items) item.id: item.toFirestore()
    },
    'order' : order
  };

  factory DietPlanMealModel.fromFirestore(Map<String, dynamic> data, String mealId) {
    final itemsData = data['items'];
    List<DietPlanItemModel> itemsList = [];

    // 🎯 FIXED: Safely handle Items whether they are a Map or a List
    if (itemsData is Map) {
      itemsList = itemsData.entries.map((e) {
        if (e.value is Map) {
          return DietPlanItemModel.fromFirestore(Map<String, dynamic>.from(e.value), e.key.toString());
        }
        return null;
      }).whereType<DietPlanItemModel>().toList();
    } else if (itemsData is List) {
      itemsList = itemsData.map((e) {
        if (e is Map) {
          final map = Map<String, dynamic>.from(e);
          return DietPlanItemModel.fromFirestore(map, map['id']?.toString() ?? '');
        }
        return null;
      }).whereType<DietPlanItemModel>().toList();
    }

    return DietPlanMealModel(
        id: mealId,
        mealNameId: data['mealNameId']?.toString() ?? '',
        mealName: data['mealName']?.toString() ?? 'Unknown Meal',
        items: itemsList,
        time: data['time']?.toString(),
        order: safeInt(data['order'], 99)
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

  MasterDayPlanModel copyWith({List<DietPlanMealModel>? meals, String? dayName}) => MasterDayPlanModel(
      id: id,
      dayName: dayName ?? this.dayName,
      meals: meals ?? this.meals
  );

  Map<String, dynamic> toFirestore() => {
    'dayName': dayName,
    'meals': {
      for (var meal in meals) meal.id: meal.toFirestore()
    },
  };

  factory MasterDayPlanModel.fromMap(Map<String, dynamic> data, String id) {
    final Map<String, dynamic> source = data.containsKey('dayPlan')
        ? (data['dayPlan'] as Map<String, dynamic>? ?? {})
        : data;

    final mealsData = source['meals'];
    List<DietPlanMealModel> mealsList = [];

    // 🎯 FIXED: Prevents dynamic array lookups that cause "String is not subtype of int" crashes
    if (mealsData is Map) {
      mealsList = mealsData.entries.map((e) {
        if (e.value is Map) {
          return DietPlanMealModel.fromFirestore(Map<String, dynamic>.from(e.value), e.key.toString());
        }
        return null;
      }).whereType<DietPlanMealModel>().toList();
    } else if (mealsData is List) {
      mealsList = mealsData.map((e) {
        if (e is Map) {
          final map = Map<String, dynamic>.from(e);
          return DietPlanMealModel.fromFirestore(map, map['id']?.toString() ?? map['mealNameId']?.toString() ?? '');
        }
        return null;
      }).whereType<DietPlanMealModel>().toList();
    }

    mealsList.sort((a, b) => a.order.compareTo(b.order));

    return MasterDayPlanModel(
      id: id,
      dayName: source['dayName']?.toString() ?? 'Fixed Day',
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? tenantId;
  final bool isGlobal;

  const MasterDietPlanModel({
    this.id = '',
    this.name = '',
    this.description = '',
    this.dietPlanCategoryIds = const [],
    this.days = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.tenantId,
    this.isGlobal = false,
  });

  MasterDietPlanModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? dietPlanCategoryIds,
    List<MasterDayPlanModel>? days,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tenantId,
    bool? isGlobal,
  }) => MasterDietPlanModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    dietPlanCategoryIds: dietPlanCategoryIds ?? this.dietPlanCategoryIds,
    days: days ?? this.days,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tenantId: tenantId ?? this.tenantId,
    isGlobal: isGlobal ?? this.isGlobal,
  );

  Map<String, dynamic> toFirestore() {
    final bool isMultiDay = days.length > 1;

    final Map<String, dynamic> data = {
      'id' : id,
      'name': name,
      'description': description,
      'dietPlanCategoryIds': dietPlanCategoryIds,
      'isActive' : isActive,
      'tenantId': tenantId,
      'isGlobal': isGlobal,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };

    if (isMultiDay) {
      data['dayPlanType'] = 'weekly';
      data['daysList'] = days.map((day) => {
        'id': day.id,
        'dayName': day.dayName,
        'meals': day.meals.map((meal) => meal.toFirestore()).toList(),
      }).toList();
    } else {
      data['dayPlanType'] = 'single';
      data['dayPlan'] = days.isNotEmpty
          ? days.first.toFirestore()
          : MasterDayPlanModel(id: 'd1', dayName: 'Fixed Day').toFirestore();
    }

    return data;
  }

  factory MasterDietPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw StateError('MasterDietPlan document data is null for ID: ${doc.id}');

    final dayPlanType = data['dayPlanType'] as String? ?? 'single';
    List<MasterDayPlanModel> loadedDays = [];

    if (dayPlanType == 'weekly' && data['daysList'] is List) {
      loadedDays = (data['daysList'] as List).map((dayMap) {
        if (dayMap is! Map) return null;
        final map = Map<String, dynamic>.from(dayMap);

        final mealsData = map['meals'];
        List<DietPlanMealModel> mealsList = [];

        // 🎯 FIXED: Safe Map/List parsing for Day Plans
        if (mealsData is List) {
          mealsList = mealsData.map((mealMap) {
            if (mealMap is! Map) return null;
            final m = Map<String, dynamic>.from(mealMap);
            return DietPlanMealModel.fromFirestore(m, m['id']?.toString() ?? m['mealNameId']?.toString() ?? '');
          }).whereType<DietPlanMealModel>().toList();
        } else if (mealsData is Map) {
          mealsList = mealsData.entries.map((e) {
            if (e.value is! Map) return null;
            return DietPlanMealModel.fromFirestore(Map<String, dynamic>.from(e.value), e.key.toString());
          }).whereType<DietPlanMealModel>().toList();
        }

        mealsList.sort((a, b) => a.order.compareTo(b.order));

        return MasterDayPlanModel(
          id: map['id']?.toString() ?? '',
          dayName: map['dayName']?.toString() ?? 'Unknown Day',
          meals: mealsList,
        );
      }).whereType<MasterDayPlanModel>().toList();
    } else {
      final dayPlan = MasterDayPlanModel.fromFirestore(doc);
      loadedDays = [dayPlan];
    }

    return MasterDietPlanModel(
      id: doc.id,
      name: data['name']?.toString() ?? 'Untitled Plan',
      description: data['description']?.toString() ?? '',
      dietPlanCategoryIds: (data['dietPlanCategoryIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      days: loadedDays,
      isActive: data['isActive'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      tenantId: data['tenantId']?.toString(),
      isGlobal: data['isGlobal'] == true,
    );
  }
}