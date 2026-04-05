import 'package:cloud_firestore/cloud_firestore.dart';

class LabTestConfigModel {
  final String id;
  final String code; // Unique Key (e.g., 'hemoglobin')
  final String name; // Display Name (e.g. 'Hemoglobin')
  final String unit;

  // 🔗 Category Relation
  final String categoryId;
  final String categoryName;

  // 📊 Ranges & Logic
  final double? minRange;
  final double? maxRange;
  final bool isReverseLogic; // e.g., true for HDL (higher is better)

  // 🏗️ System Fields
  final int order;
  final bool isGlobal;
  final String? tenantId;
  final bool isActive;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LabTestConfigModel({
    this.id = '',
    this.code = '',
    required this.name,
    required this.unit,
    this.categoryId = '',
    this.categoryName = '',
    this.minRange,
    this.maxRange,
    this.isReverseLogic = false,
    this.order = 999,
    this.isGlobal = false,
    this.tenantId,
    this.isActive = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  // 🎯 FACTORY: Safe parsing from Firestore
  factory LabTestConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return const LabTestConfigModel(name: '', unit: '');

    return LabTestConfigModel(
      id: doc.id,
      code: data['code'] as String? ?? '',
      name: data['name'] as String? ?? data['displayName'] as String? ?? '', // Fallback for old data
      unit: data['unit'] as String? ?? '',

      categoryId: data['categoryId'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? data['category'] as String? ?? '',

      minRange: (data['minRange'] as num?)?.toDouble(),
      maxRange: (data['maxRange'] as num?)?.toDouble(),
      isReverseLogic: data['isReverseLogic'] as bool? ?? false,

      order: (data['order'] as num?)?.toInt() ?? 999,
      isGlobal: data['isGlobal'] ?? false,
      tenantId: data['tenantId'] as String?,
      isActive: data['isActive'] ?? true,
      isDeleted: data['isDeleted'] ?? false,

      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // 🎯 SERIALIZER: Preparing data for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'name': name,
      'searchKey': name.toLowerCase().trim(), // Helper for searching
      'unit': unit,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'minRange': minRange,
      'maxRange': maxRange,
      'isReverseLogic': isReverseLogic,
      'order': order,
      'isGlobal': isGlobal,
      'tenantId': tenantId,
      'isActive': isActive,
      'isDeleted': isDeleted,
      // Note: CreatedAt is usually handled by the Service layer on creation
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  LabTestConfigModel copyWith({
    String? id,
    String? code,
    String? name,
    String? unit,
    String? categoryId,
    String? categoryName,
    double? minRange,
    double? maxRange,
    bool? isReverseLogic,
    int? order,
    bool? isGlobal,
    String? tenantId,
    bool? isActive,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LabTestConfigModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      minRange: minRange ?? this.minRange,
      maxRange: maxRange ?? this.maxRange,
      isReverseLogic: isReverseLogic ?? this.isReverseLogic,
      order: order ?? this.order,
      isGlobal: isGlobal ?? this.isGlobal,
      tenantId: tenantId ?? this.tenantId,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}