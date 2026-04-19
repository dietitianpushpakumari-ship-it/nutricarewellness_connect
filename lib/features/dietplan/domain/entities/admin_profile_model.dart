import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminRole { superAdmin, clinicAdmin, dietitian, staff, doctor }

class AdminTitles {
  static const String doctor = 'Dr.';
  static const String dietitian = 'Dt.';
  static const String mr = 'Mr.';
  static const String ms = 'Ms.';
  static const String mrs = 'Mrs.';

  static const List<String> all = [doctor, dietitian, mr, ms, mrs];
}

class AdminProfileModel {
  final String id;
  final String email;
  final String tenantId;
  final String firstName;
  final String lastName;
  final String mobile;
  final String alternateMobile;
  final String gender;
  final DateTime? dob;
  final String? aadharNumber;
  final String? panNumber;
  final String? address;
  final String employeeId;
  final AdminRole role;
  final bool isActive;
  final String department;
  final String designation;
  final List<String> qualifications;
  final List<String> specializations;
  final List<String> permissions;
  final DateTime dateOfJoining;
  final String photoUrl;
  final String companyName;
  final String? regdNo;
  final String companyEmail;
  final String? tempPassword;

  final String? aboutMe;
  final String? visitingCardUrl;

  // 🚀 1. NEW FIELD: FCM TOKEN
  final String? fcmToken;

  // Metadata
  final bool isDeleted;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String createdBy;
  final String lastModifiedBy;
  final String? title;

  AdminProfileModel({
    required this.id,
    required this.email,
    required this.tenantId,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    this.alternateMobile = '',
    required this.gender,
    this.dob,
    this.aadharNumber,
    this.panNumber,
    this.address,
    required this.employeeId,
    required this.role,
    this.isActive = true,
    this.department = '',
    required this.designation,
    this.qualifications = const [],
    this.specializations = const [],
    this.permissions = const [],
    required this.dateOfJoining,
    this.photoUrl = '',
    this.companyName = '',
    this.regdNo,
    required this.companyEmail,
    this.tempPassword,
    this.aboutMe,
    this.visitingCardUrl,
    this.fcmToken, // 🚀 2. CONSTRUCTOR INITIALIZATION
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.lastModifiedBy,
    this.title,
  });

  String get fullName => "$firstName $lastName";

  // 🟢 FACTORY: FROM FIRESTORE
  factory AdminProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminProfileModel.fromMap(data..['id'] = doc.id);
  }

  // 🟢 FACTORY: FROM MAP
  factory AdminProfileModel.fromMap(Map<String, dynamic> map) {
    return AdminProfileModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      tenantId: map['tenantId'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      mobile: map['mobile'] ?? '',
      alternateMobile: map['alternateMobile'] ?? '',
      gender: map['gender'] ?? 'Female',
      dob: map['dob'] != null ? (map['dob'] is Timestamp ? (map['dob'] as Timestamp).toDate() : DateTime.tryParse(map['dob'].toString())) : null,
      aadharNumber: map['aadharNumber'],
      panNumber: map['panNumber'],
      address: map['address'],
      employeeId: map['employeeId'] ?? '',
      role: _parseRole(map['role']),
      isActive: map['isActive'] ?? true,
      department: map['department'] ?? '',
      designation: map['designation'] ?? '',
      qualifications: List<String>.from(map['qualifications'] ?? []),
      specializations: List<String>.from(map['specializations'] ?? []),
      permissions: List<String>.from(map['permissions'] ?? []),
      dateOfJoining: map['dateOfJoining'] != null
          ? (map['dateOfJoining'] is Timestamp ? (map['dateOfJoining'] as Timestamp).toDate() : DateTime.tryParse(map['dateOfJoining'].toString()) ?? DateTime.now())
          : DateTime.now(),
      photoUrl: map['photoUrl'] ?? '',
      companyName: map['companyName'] ?? '',
      regdNo: map['regdNo'],
      companyEmail: map['companyEmail'] ?? '',
      tempPassword: map['temp_password'],
      aboutMe: map['aboutMe'],
      visitingCardUrl: map['visitingCardUrl'],
      fcmToken: map['fcmToken'] ?? map['fcm_token'], // 🚀 3. READ FROM DB (Fallback added for safety)
      isDeleted: map['isDeleted'] ?? false,
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : Timestamp.now(),
      updatedAt: map['updatedAt'] is Timestamp ? map['updatedAt'] : Timestamp.now(),
      createdBy: map['createdBy'] ?? '',
      lastModifiedBy: map['lastModifiedBy'] ?? '',
      title: map['title'] as String?,
    );
  }

  // 🎯 STRICT ROLE PARSING
  static AdminRole _parseRole(dynamic roleData) {
    if (roleData == null) return AdminRole.dietitian;
    final String roleString = roleData.toString().trim();

    if (roleString == 'superAdmin' || roleString == 'super_admin') {
      return AdminRole.superAdmin;
    }

    if (roleString == 'owner' || roleString == 'admin' || roleString == 'clinicAdmin' || roleString == 'clinic_admin') {
      return AdminRole.clinicAdmin;
    }

    return AdminRole.values.firstWhere(
          (e) => e.name == roleString,
      orElse: () => AdminRole.dietitian,
    );
  }

  // 🎯 SMART PERMISSIONS
  bool hasAccess(String permission) {
    if (role == AdminRole.superAdmin) return true;

    if (role == AdminRole.clinicAdmin) {
      if (permission == 'manage_tenants' || permission == 'db_migration') return false;
      return true;
    }

    return permissions.contains(permission);
  }

  // 🟢 TO MAP
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'tenantId': tenantId,
      'firstName': firstName,
      'lastName': lastName,
      'mobile': mobile,
      'alternateMobile': alternateMobile,
      'gender': gender,
      'dob': dob,
      'aadharNumber': aadharNumber,
      'panNumber': panNumber,
      'address': address,
      'employeeId': employeeId,
      'role': role.name,
      'isActive': isActive,
      'department': department,
      'designation': designation,
      'qualifications': qualifications,
      'specializations': specializations,
      'permissions': permissions,
      'dateOfJoining': dateOfJoining,
      'photoUrl': photoUrl,
      'companyName': companyName,
      'regdNo': regdNo,
      'companyEmail': companyEmail,
      'temp_password': tempPassword,
      'aboutMe': aboutMe,
      'visitingCardUrl': visitingCardUrl,
      'fcmToken': fcmToken, // 🚀 4. WRITE TO DB
      'isDeleted': isDeleted,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'title': title
    };
  }

  // Helper for copying
  AdminProfileModel copyWith({
    String? firstName,
    String? lastName,
    String? mobile,
    String? alternateMobile,
    String? companyEmail,
    String? aadharNumber,
    String? panNumber,
    String? regdNo,
    String? department,
    String? designation,
    AdminRole? role,
    String? address,
    String? photoUrl,
    List<String>? qualifications,
    List<String>? specializations,
    String? title,
    String? aboutMe,
    String? visitingCardUrl,
    String? fcmToken, // 🚀 5. ADD TO COPY WITH PARAMS
  }) {
    return AdminProfileModel(
        id: id,
        email: email,
        tenantId: tenantId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        mobile: mobile ?? this.mobile,
        alternateMobile: alternateMobile ?? this.alternateMobile,
        gender: gender,
        dob: dob,
        aadharNumber: aadharNumber ?? this.aadharNumber,
        panNumber: panNumber ?? this.panNumber,
        address: address ?? this.address,
        employeeId: employeeId,
        role: role ?? this.role,
        isActive: isActive,
        department: department ?? this.department,
        designation: designation ?? this.designation,
        qualifications: qualifications ?? this.qualifications,
        specializations: specializations ?? this.specializations,
        permissions: permissions,
        dateOfJoining: dateOfJoining,
        photoUrl: photoUrl ?? this.photoUrl,
        companyName: companyName,
        regdNo: regdNo ?? this.regdNo,
        companyEmail: companyEmail ?? this.companyEmail,
        tempPassword: tempPassword,
        aboutMe: aboutMe ?? this.aboutMe,
        visitingCardUrl: visitingCardUrl ?? this.visitingCardUrl,
        fcmToken: fcmToken ?? this.fcmToken, // 🚀 6. COPY VALUE
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: Timestamp.now(), // Auto update
        createdBy: createdBy,
        lastModifiedBy: lastModifiedBy,
        title: title ?? this.title
    );
  }
}