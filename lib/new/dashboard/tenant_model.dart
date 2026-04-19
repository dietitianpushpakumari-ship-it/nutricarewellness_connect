import 'package:cloud_firestore/cloud_firestore.dart';

class TenantModel {
  final String id;
  final String name;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String status;
  final String? logoUrl;
  final String? address;
  final String? website;
  final DateTime? createdAt;
  final DateTime? invitedAt;
  final String? patientIdPrefix;
  final String? gstin;
  final String? city;
  final String? state;
  final String? pincode;
  final String? contactPhone;
  final String? alternatePhone; // 🚀 ADDED ALTERNATE PHONE
  final String? contactEmail;
  final String? bankName;
  final String? bankAccNo;
  final String? bankIfsc;
  final Timestamp? updatedAt;

  TenantModel({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    this.status = 'active',
    this.logoUrl,
    this.address,
    this.website,
    this.createdAt,
    this.invitedAt,
    this.patientIdPrefix,
    this.gstin,
    this.city,
    this.state,
    this.pincode,
    this.contactPhone,
    this.alternatePhone, // 🚀 ADDED HERE
    this.contactEmail,
    this.bankName,
    this.bankAccNo,
    this.bankIfsc,
    this.updatedAt,
  });

  factory TenantModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? toDateTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TenantModel(
      id: doc.id,
      name: data['name'] ?? '',
      ownerName: data['ownerName'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      ownerPhone: data['ownerPhone'] ?? '',
      status: data['status'] ?? 'active',
      logoUrl: data['logoUrl'],
      address: data['address'],
      website: data['website'],
      createdAt: toDateTime(data['createdAt']),
      invitedAt: toDateTime(data['invitedAt']),
      patientIdPrefix: data['patientIdPrefix'] as String?,
      gstin: data['gstin'] as String?,
      city: data['city'] as String?,
      state: data['state'] as String?,
      pincode: data['pincode'] as String?,
      contactPhone: data['contactPhone'] as String?,
      alternatePhone: data['alternatePhone'] as String?, // 🚀 ADDED HERE
      contactEmail: data['contactEmail'] as String?,
      bankName: data['bankName'] as String?,
      bankAccNo: data['bankAccNo'] as String?,
      bankIfsc: data['bankIfsc'] as String?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'ownerPhone': ownerPhone,
      'status': status,
      'logoUrl': logoUrl,
      'address': address,
      'website': website,
      'patientIdPrefix': patientIdPrefix,
      'gstin': gstin,
      'city': city,
      'state': state,
      'pincode': pincode,
      'contactPhone': contactPhone,
      'alternatePhone': alternatePhone, // 🚀 ADDED HERE
      'contactEmail': contactEmail,
      'bankName': bankName,
      'bankAccNo': bankAccNo,
      'bankIfsc': bankIfsc,
      'updatedAt': updatedAt,
    };
  }
}