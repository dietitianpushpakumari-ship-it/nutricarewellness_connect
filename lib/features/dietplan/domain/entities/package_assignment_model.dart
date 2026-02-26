import 'package:cloud_firestore/cloud_firestore.dart';

class PackageAssignmentModel {
  final String id;
  final String? tenantId; // 🟢 ADDED: Multi-Tenant ID
  final String packageId;
  final String packageName;
  final String? description;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final bool isActive;
  final bool isLocked;
  final String clientId;

  final String? diagnosis;
  final double discount;
  final double bookedAmount;
  final String? category;
  final String? type;

  // 🎯 UI & Logic Fields
  final String? colorCode;
  final int followUpIntervalDays;
  final bool isTaxInclusive;
  final double? originalPrice;

  final String? sessionId;
  final int sessionsTotal;
  final int sessionsRemaining;
  final int offerExtraDays;
  final int offerExtraSessions;
  final int freeSessionsTotal;
  final int freeSessionsRemaining;

  // 🎯 Content Lists
  final List<String> inclusions;
  final List<String> inclusionIds;
  final List<String> programFeatureIds;
  final List<String> targetConditions;

  PackageAssignmentModel({
    required this.id,
    this.tenantId, // 🟢 ADDED: Constructor
    required this.packageId,
    required this.packageName,
    this.description,
    required this.purchaseDate,
    required this.expiryDate,
    required this.isActive,
    required this.clientId,
    this.diagnosis,
    this.discount = 0.0,
    required this.bookedAmount,
    this.category,
    this.type,
    required this.isLocked,
    this.colorCode,
    this.followUpIntervalDays = 7,
    this.isTaxInclusive = true,
    this.originalPrice,
    this.sessionId,
    this.sessionsTotal = 0,
    this.sessionsRemaining = 0,
    this.offerExtraDays = 0,
    this.offerExtraSessions = 0,
    this.freeSessionsTotal = 0,
    this.freeSessionsRemaining = 0,
    this.inclusions = const [],
    this.inclusionIds = const [],
    this.programFeatureIds = const [],
    this.targetConditions = const [],
  });

  // 🎯 fromMap Factory
  factory PackageAssignmentModel.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic timestamp) {
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.now();
      return DateTime.now();
    }

    final startDate = parseDate(data['startDate'] ?? data['purchaseDate']);
    final endDate = parseDate(data['endDate'] ?? data['expiryDate']);

    final String status = (data['status'] ?? '').toString().toLowerCase();
    final bool isActive = (status == 'active' || data['isActive'] == true) && endDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));

    return PackageAssignmentModel(
      id: data['id'] as String? ?? '',
      tenantId: data['tenantId'] as String?, // 🟢 ADDED: Read from Map
      packageId: data['packageId'] as String? ?? '',
      packageName: data['packageName'] as String? ?? 'Unknown',
      description: data['description'] as String?,

      purchaseDate: startDate,
      expiryDate: endDate,
      isActive: isActive,

      clientId: data['clientId'] as String? ?? '',
      diagnosis: data['diagnosis'] as String?,
      type: data['type'] as String?,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,

      bookedAmount: (data['bookedAmount'] as num?)?.toDouble() ?? (data['price'] as num?)?.toDouble() ?? 0.0,

      category: data['category'] as String?,
      colorCode: data['colorCode'] as String?,
      followUpIntervalDays: (data['followUpIntervalDays'] as num?)?.toInt() ?? 7,
      isTaxInclusive: data['isTaxInclusive'] as bool? ?? true,
      originalPrice: (data['originalPrice'] as num?)?.toDouble(),

      isLocked: data['isLocked'] as bool? ?? false,
      sessionId: data['sessionId'] as String?,
      sessionsTotal: (data['sessionsTotal'] as num?)?.toInt() ?? 0,
      sessionsRemaining: (data['sessionsRemaining'] as num?)?.toInt() ?? 0,
      offerExtraDays: (data['offerExtraDays'] as num?)?.toInt() ?? 0,
      offerExtraSessions: (data['offerExtraSessions'] as num?)?.toInt() ?? 0,
      freeSessionsTotal: (data['freeSessionsTotal'] as num?)?.toInt() ?? 0,
      freeSessionsRemaining: (data['freeSessionsRemaining'] as num?)?.toInt() ?? 0,

      inclusions: List<String>.from(data['inclusions'] ?? []),
      inclusionIds: List<String>.from(data['inclusionIds'] ?? []),
      programFeatureIds: List<String>.from(data['programFeatureIds'] ?? []),
      targetConditions: List<String>.from(data['targetConditions'] ?? []),
    );
  }

  // 🎯 fromFirestore Factory
  factory PackageAssignmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Cannot create PackageAssignmentModel from null data.');
    }

    // Reuse fromMap logic
    final model = PackageAssignmentModel.fromMap(data);

    // Return copy with correct ID
    return model.copyWith(id: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId, // 🟢 ADDED: Write to Map
      'packageId': packageId,
      'packageName': packageName,
      'description': description,
      'startDate': Timestamp.fromDate(purchaseDate),
      'endDate': Timestamp.fromDate(expiryDate),
      'status': isActive ? 'active' : 'expired',
      'clientId': clientId,
      'diagnosis': diagnosis,
      'discount': discount,
      'price': bookedAmount,
      'type': type,
      'category': category,
      'colorCode': colorCode,
      'followUpIntervalDays': followUpIntervalDays,
      'isTaxInclusive': isTaxInclusive,
      'originalPrice': originalPrice,
      'isLocked': isLocked,
      'sessionId': sessionId,
      'sessionsTotal': sessionsTotal,
      'sessionsRemaining': sessionsRemaining,
      'offerExtraDays': offerExtraDays,
      'offerExtraSessions': offerExtraSessions,
      'freeSessionsTotal': freeSessionsTotal,
      'freeSessionsRemaining': freeSessionsRemaining,
      'inclusions': inclusions,
      'inclusionIds': inclusionIds,
      'programFeatureIds': programFeatureIds,
      'targetConditions': targetConditions,
    };
  }

  // 🎯 CopyWith Method
  PackageAssignmentModel copyWith({
    String? id,
    String? tenantId, // 🟢 ADDED: Param
    String? packageId,
    String? packageName,
    String? description,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    bool? isActive,
    bool? isLocked,
    String? clientId,
    String? diagnosis,
    double? discount,
    double? bookedAmount,
    String? category,
    String? type,
    String? colorCode,
    int? followUpIntervalDays,
    bool? isTaxInclusive,
    double? originalPrice,
    String? sessionId,
    int? sessionsTotal,
    int? sessionsRemaining,
    int? offerExtraDays,
    int? offerExtraSessions,
    int? freeSessionsTotal,
    int? freeSessionsRemaining,
    List<String>? inclusions,
    List<String>? inclusionIds,
    List<String>? programFeatureIds,
    List<String>? targetConditions,
  }) {
    return PackageAssignmentModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId, // 🟢 ADDED: Assign
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      description: description ?? this.description,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      isLocked: isLocked ?? this.isLocked,
      clientId: clientId ?? this.clientId,
      diagnosis: diagnosis ?? this.diagnosis,
      discount: discount ?? this.discount,
      bookedAmount: bookedAmount ?? this.bookedAmount,
      category: category ?? this.category,
      type: type ?? this.type,
      colorCode: colorCode ?? this.colorCode,
      followUpIntervalDays: followUpIntervalDays ?? this.followUpIntervalDays,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      originalPrice: originalPrice ?? this.originalPrice,
      sessionId: sessionId ?? this.sessionId,
      sessionsTotal: sessionsTotal ?? this.sessionsTotal,
      sessionsRemaining: sessionsRemaining ?? this.sessionsRemaining,
      offerExtraDays: offerExtraDays ?? this.offerExtraDays,
      offerExtraSessions: offerExtraSessions ?? this.offerExtraSessions,
      freeSessionsTotal: freeSessionsTotal ?? this.freeSessionsTotal,
      freeSessionsRemaining: freeSessionsRemaining ?? this.freeSessionsRemaining,
      inclusions: inclusions ?? this.inclusions,
      inclusionIds: inclusionIds ?? this.inclusionIds,
      programFeatureIds: programFeatureIds ?? this.programFeatureIds,
      targetConditions: targetConditions ?? this.targetConditions,
    );
  }
}