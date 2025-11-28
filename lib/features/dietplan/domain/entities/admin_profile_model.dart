import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProfileModel {
  final String id; // Firebase Auth UID (Document ID)
  final String email; // Login email
  //final UserRole role; // SuperAdmin or Admin

  // --- Profile Details ---
  final String firstName;
  final String lastName;

  // --- Soft-Delete & Auditing ---
  final bool isDeleted;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String createdBy; // UID of the user who created this account
  final String lastModifiedBy;




final String companyEmail;
  final String companyName;
  final String designation;
  final String regdNo;
  final String mobile;
  final String alternateMobile;
  final String website;
  final String address;
  final String photoUrl;// UID of the user who last updated this account

  final List<String> specializations;

  const AdminProfileModel( {
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    //required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.lastModifiedBy,
    this.isDeleted = false,
    required this.companyName,
    required this.designation,
    this.regdNo ='',
    required this.mobile,
    this.alternateMobile = '',
    this.website = '',
    required this.address ,
    this.photoUrl = '',
    this.companyEmail = '',
    this.specializations = const [],
  });

  // --- Firestore Conversion ---

  factory AdminProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AdminProfileModel(
      id: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
  //    role: stringToRole(data['role'] ?? UserRole.admin.name), // Use helper from service
      isDeleted: data['isDeleted'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? 'system',
      lastModifiedBy: data['lastModifiedBy'] ?? 'system',
      companyName: data['companyName'] ?? '',
      designation: data['designation'] ?? '',
      mobile: data['mobile'] ?? '',
      address: data['address'] ?? '',
      companyEmail: data['companyEmail'] ?? '',
      alternateMobile: data['alternateMobile'] ?? '',
      website: data['website'] ?? '',
      specializations: List<String>.from(data['specializations'] ?? []),

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
     // 'role': role.name, // Store the enum name as a string
      'isDeleted': isDeleted,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'companyName': companyName,
      'designation': designation,
      'mobile': mobile,
      'address' : address,
      'companyEmail' : companyEmail,
      'alternateMobile' : alternateMobile,
      'website' : website,
      'specializations' : specializations
    };
  }


  factory AdminProfileModel.fromMap(Map<String, dynamic> data) {
    return AdminProfileModel(
      id: data['id'] ?? '', // Must be set externally if not in map
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      //role: stringToRole(data['role'] ?? UserRole.admin.name), // Use helper from service
      isDeleted: data['isDeleted'] ?? false,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : Timestamp.now(),
      createdBy: data['createdBy'] ?? 'system',
      lastModifiedBy: data['lastModifiedBy'] ?? 'system',
      companyName: data['companyName'] ?? '',
      designation: data['designation'] ?? '',
      mobile: data['mobile'] ?? '',
      address: data['address'] ?? '',
      companyEmail: data['companyEmail'] ?? '',
      alternateMobile: data['alternateMobile'] ?? '',
      website: data['website'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      regdNo: data['regdNo'] ?? '',
      specializations: List<String>.from(data['specializations'] ?? []),
    );
  }

}