// lib/models/package_assignment_model.dart (UPDATED)
import 'package:cloud_firestore/cloud_firestore.dart';

class PackageAssignmentModel {
  final String id;
  final String packageId;
  final String packageName;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final bool isActive;
  final bool isLocked;
  final String clientId;

  // NEW FIELDS
  final String? diagnosis; // Reason for package availment
  final double discount; // Discount amount or percentage (captured as an absolute value for simplicity)
  final double bookedAmount;
  final String category; // The final amount client paid/booked for

  PackageAssignmentModel({
    required this.id,
    required this.packageId,
    required this.packageName,
    required this.purchaseDate,
    required this.expiryDate,
    required this.isActive,
    required this.clientId,
    // NEW FIELDS REQUIRED
    this.diagnosis,
    this.discount = 0.0,
    required this.bookedAmount,
    required this.category,
    required this.isLocked,
  });

  factory PackageAssignmentModel.fromMap(Map<String, dynamic> data) {
    return PackageAssignmentModel(
      id: '',
      packageId: data['packageId'] ?? '',
      packageName: data['packageName'] ?? 'Unknown Package',
      purchaseDate: (data['purchaseDate'] as Timestamp).toDate(),
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,

      // Parsing NEW FIELDS
      diagnosis: data['diagnosis'] ??  '',
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      bookedAmount: (data['bookedAmount'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? '',
      isLocked: data['isLocked'] ?? false,
      clientId: data['clientId'] ?? ''
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // The 'id' field is usually NOT stored inside the document,
      // but managed as the document key. Include it here just for completeness
      // if you sometimes need to convert to Map outside of a save context.
      'id': id,
      'packageId': packageId,
      'packageName': packageName,
      'purchaseDate': purchaseDate,
      'expiryDate': expiryDate,
      'isActive': isActive,

      // Mapping NEW FIELDS
      'diagnosis': diagnosis,
      'discount': discount,
      'bookedAmount': bookedAmount,
      'category': category,
      'isLocked': isLocked,
      'clientId': clientId
    };
  }

  // 🎯 FIX: ADD THIS FACTORY CONSTRUCTOR
  factory PackageAssignmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Cannot create PackageAssignmentModel from null data.');
    }

    // Safely cast Timestamps to DateTime
    DateTime parseDate(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
      // Assuming a standard DateTime if not a Timestamp (e.g., in tests)
      return timestamp is DateTime ? timestamp : DateTime.now();
    }

    // Determine isActive status
    final expiryDate = parseDate(data['expiryDate']);

    return PackageAssignmentModel(
      id: doc.id,
      // Always use the document ID for the models's ID
      packageId: data['packageId'] as String,
      packageName: data['packageName'] as String,
      diagnosis: data['diagnosis'] as String?,
      discount: (data['discount'] as num).toDouble(),
      // Safely handle int/double from Firestore
      bookedAmount: (data['bookedAmount'] as num).toDouble(),
      purchaseDate: parseDate(data['purchaseDate']),
      expiryDate: expiryDate,
      category: data['category'],
      isActive: data['isActive'] as bool? ?? expiryDate.isAfter(DateTime.now()),
      isLocked: data['isLocked']  as bool? ?? false,
      clientId: data['clientID'] as String? ?? ''
    );
  }

  PackageAssignmentModel copyWith({
    String? id,
    String? clientId,
    String? packageName,
    DateTime? purchaseDate,
    bool? isActive,
    bool? isLocked,
    DateTime? expiryDate,
    double? bookedAmount,
    String? category,
    // Include new field in copyWith
  }) {
    return PackageAssignmentModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      packageName: packageName ?? this.packageName,
      isActive: isActive ?? this.isActive,
      isLocked: isLocked ?? this.isLocked,
      packageId: '',
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      bookedAmount: bookedAmount ?? this.bookedAmount,
      category: category ?? this.category,

    );
  }

  // Add the toMap method for saving data back to Firestore (optional but recommended)
}
