// lib/models/package_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// 🎯 NEW: Enum for package categorization
enum PackageCategory {
  basic,
  standard,
  premium,
  custom; // Added 'custom' for flexibility

  // Helper to convert enum value to a readable string (e.g., 'basic' -> 'Basic')
  String get displayName => name[0].toUpperCase() + name.substring(1);
}

class PackageModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final List<String> inclusions;
  final bool isActive;

  // 🎯 UPDATE: Use the new enum for category
  final PackageCategory category;

  // 🎯 UPDATE: List of Program Feature IDs tagged to this package
  final List<String> programFeatureIds;

  PackageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    this.inclusions = const [],
    this.isActive = true,
    // Initialize new fields
    this.category = PackageCategory.basic,
    this.programFeatureIds = const [],
  });

  // Factory constructor for creating a PackageModel from a Firestore document
  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Helper to safely parse enum from a string (defaults to 'basic')
    final String categoryString = data['category'] ?? 'basic';
    final PackageCategory packageCategory = PackageCategory.values.firstWhere(
          (e) => e.name == categoryString.toLowerCase(),
      orElse: () => PackageCategory.basic,
    );

    return PackageModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 0,
      inclusions: List<String>.from(data['inclusions'] ?? []),
      isActive: data['isActive'] ?? true,
      // Read new fields
      category: packageCategory,
      programFeatureIds: List<String>.from(data['programFeatureIds'] ?? []),
    );
  }

  // Convert PackageModel to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'durationDays': durationDays,
      'inclusions': inclusions,
      'isActive': isActive,
      // Write new fields: use the enum name (string representation)
      'category': category.name,
      'programFeatureIds': programFeatureIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}