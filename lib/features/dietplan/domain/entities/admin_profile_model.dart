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
  final String department; // 🚀 1. NEW DEPARTMENT FIELD
  final String designation;
  final List<String> qualifications;
  final List<String> specializations;
  final List<String> permissions;
  final DateTime dateOfJoining;
  final String photoUrl;
  final String companyName;
  final String? regdNo;
  final String companyEmail;
  final String? tempPassword; // Only used during onboarding

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
    this.department = '', // 🚀 2. DEFAULT EMPTY STRING PREVENTS CRASHES ON OLD RECORDS
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
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.lastModifiedBy,
    this.title,
  });

  String get fullName => "$firstName $lastName";

  // 🟢 1. FACTORY: FROM FIRESTORE
  factory AdminProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminProfileModel.fromMap(data..['id'] = doc.id);
  }

  // 🟢 2. FACTORY: FROM MAP (Required for SharedPreferences Session)
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
      role: _parseRole(map['role']), // Safely parse the role
      isActive: map['isActive'] ?? true,
      department: map['department'] ?? '', // 🚀 3. PARSE FROM DB
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
      tempPassword: map['temp_password'], // Note snake_case from DB
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

    // 1. Super Admin (Only explicitly 'superAdmin')
    if (roleString == 'superAdmin' || roleString == 'super_admin') {
      return AdminRole.superAdmin;
    }

    // 2. Clinic Admin (Previously 'owner', 'admin')
    if (roleString == 'owner' || roleString == 'admin' || roleString == 'clinicAdmin' || roleString == 'clinic_admin') {
      return AdminRole.clinicAdmin;
    }

    // 3. Default Mapping
    return AdminRole.values.firstWhere(
          (e) => e.name == roleString,
      orElse: () => AdminRole.dietitian,
    );
  }

  // 🎯 SMART PERMISSIONS
  bool hasAccess(String permission) {
    // Super Admin has infinite access
    if (role == AdminRole.superAdmin) return true;

    // Clinic Admin has access to almost everything EXCEPT global tenant management
    if (role == AdminRole.clinicAdmin) {
      // Deny specific Super Admin actions explicitly if checked via permission string
      if (permission == 'manage_tenants' || permission == 'db_migration') return false;
      return true;
    }

    // Others rely on specific permission flags
    return permissions.contains(permission);
  }

  // 🟢 3. TO MAP (For Firestore & SharedPreferences)
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
      'dob': dob, // Firestore handles DateTime, but JSON encoding might need .toIso8601String() for SharedPrefs
      'aadharNumber': aadharNumber,
      'panNumber': panNumber,
      'address': address,
      'employeeId': employeeId,
      'role': role.name,
      'isActive': isActive,
      'department': department, // 🚀 4. SAVE TO DB
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
    String? department, // 🚀 5. ADD TO COPY WITH
    String? designation,
    AdminRole? role,
    String? address,
    String? photoUrl,
    List<String>? qualifications,
    List<String>? specializations,
    String? title
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
        department: department ?? this.department, // 🚀 6. COPY VALUE
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
        isDeleted: isDeleted,
        createdAt: createdAt,
        updatedAt: Timestamp.now(), // Auto update
        createdBy: createdBy,
        lastModifiedBy: lastModifiedBy,
        title: title ?? this.title
    );
  }
}