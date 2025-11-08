// lib/models/guideline.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a master guideline or principle (e.g., "Drink 8 Glasses of Water").
class Guideline {
  final String id;
  final String enTitle;
  final Map<String, String> titleLocalized;
  final bool isDeleted;
  final DateTime? createdDate;

  /// IDs of Diet Plan Categories this guideline applies to (e.g., 'weight-loss-id').
  final List<String> dietPlanCategoryIds;

  const Guideline({
    required this.id,
    required this.enTitle,
    this.titleLocalized = const {},
    this.isDeleted = false,
    this.createdDate,
    this.dietPlanCategoryIds = const [],
  });

  /// Factory constructor for creating from a Firestore document snapshot.
  factory Guideline.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    Map<String, String> localizedTitles = {};
    if (data['titleLocalized'] is Map) {
      localizedTitles = Map<String, String>.from(data['titleLocalized']);
    }

    return Guideline(
      id: doc.id,
      enTitle: data['enTitle'] ?? '',
      titleLocalized: localizedTitles,
      isDeleted: data['isDeleted'] ?? false,
      dietPlanCategoryIds: List<String>.from(data['dietPlanCategoryIds'] ?? []),
      createdDate: (data['createdDate'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert Guideline object to a Map for storage in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'enTitle': enTitle,
      'titleLocalized': titleLocalized,
      'isDeleted': isDeleted,
      'dietPlanCategoryIds': dietPlanCategoryIds,
      'createdDate': createdDate != null ? Timestamp.fromDate(createdDate!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}