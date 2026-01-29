import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/utils/client_goal_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';

class AppUserModel {
  final String id;
  final String mobile;
  final String email;
  final String status;

  const AppUserModel({
    required this.id,
    required this.mobile,
    this.email = '',
    this.status = 'Active',
  });

  Map<String, dynamic> toMap() {
    return {
      'mobile': mobile,
      'email': email,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class ClientModel {
  final String id;
  final String mobile;
  final String gender;
  final String loginId;
  final String patientId;
  final bool hasPasswordSet;
  final String status;
  final bool isSoftDeleted;
  final bool isArchived;
  final String? name;
  final int? age;
  final String? whatsappNumber;
  final ClientReminderConfig? reminderConfig;
  final String? address;
  final Map<String, double>? geoLocation; // {lat: 0.0, lng: 0.0}
  final String? photoUrl;
  final bool hasJoinedSocials;
  final String? email;
  final DateTime? dob;
  final ClientGoalModel goals;
  final int? freeSessionsRemaining;
  final String clientType;

  ClientModel({
    required this.id,
    required this.mobile,
    required this.loginId,
    required this.patientId,
    this.hasPasswordSet = false,
    this.status = 'Inactive',
    this.isSoftDeleted = false,
    this.isArchived = false,
    required this.name,
    this.age,
    this.whatsappNumber,
    required this.gender,
    required this.reminderConfig,
    this.address,
    this.geoLocation,
    this.photoUrl,
    this.hasJoinedSocials = false,
    this.email,
    this.dob,
    this.goals = const ClientGoalModel(),
    this.freeSessionsRemaining = 1,
    this.clientType = 'new',
  });

  factory ClientModel.fromMap(Map<String, dynamic> data) {
    return ClientModel(
      id: data['id'] ?? '',
      mobile: data['mobile'] ?? '',
      loginId: data['loginId'] ?? data['mobile'] ?? '',
      patientId: data['patientId'] ?? '',
      hasPasswordSet: data['hasPasswordSet'] ?? false,
      status: data['status'] ?? 'Inactive',
      isSoftDeleted: data['isSoftDeleted'] ?? false,
      isArchived: data['isArchived'] ?? false,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      whatsappNumber: data['whatsappNumber'] ?? '',
      gender: data['gender'] ?? '',
      // 🎯 FIX: Robust Map Casting
      reminderConfig: data['reminderConfig'] != null
          ? ClientReminderConfig.fromMap(Map<String, dynamic>.from(data['reminderConfig']))
          : ClientReminderConfig.defaultConfig(),
      address: data['address'] as String?,
      email: data['email'] ?? '',
      dob: (data['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasJoinedSocials: data['hasJoinedSocials'] ?? false,
      // 🎯 FIX: Robust Map Casting
      geoLocation: (data['geoLocation'] as Map?)?.cast<String, double>(),
      photoUrl: data['photoUrl'],
      goals: data['goals'] != null
          ? ClientGoalModel.fromMap(Map<String, dynamic>.from(data['goals']))
          : ClientGoalModel.defaultGoals(),
      freeSessionsRemaining: data['freeSessionsRemaining'] ?? 0,
    );
  }

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ClientModel(
      id: doc.id,
      mobile: data['mobile'] ?? '',
      loginId: data['loginId'] ?? data['mobile'] ?? '',
      patientId: data['patientId'] ?? '',
      hasPasswordSet: data['hasPasswordSet'] ?? false,
      status: data['status'] ?? 'Inactive',
      isSoftDeleted: data['isSoftDeleted'] ?? false,
      isArchived: data['isArchived'] ?? false,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      whatsappNumber: data['whatsappNumber'] ?? '',
      gender: data['gender'] ?? '',
      // 🎯 FIX: Robust Map Casting for Firestore data
      reminderConfig: data['reminderConfig'] != null
          ? ClientReminderConfig.fromMap(Map<String, dynamic>.from(data['reminderConfig']))
          : ClientReminderConfig.defaultConfig(),
      address: data['address'] as String?,
      email: data['email'] ?? '',
      dob: (data['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasJoinedSocials: data['hasJoinedSocials'] ?? false,
      // 🎯 FIX: Robust Map Casting
      geoLocation: (data['geoLocation'] as Map?)?.cast<String, double>(),
      photoUrl: data['photoUrl'],
      goals: data['goals'] != null ? ClientGoalModel.fromMap(Map<String, dynamic>.from(data['goals']))
          : ClientGoalModel.defaultGoals(),
      freeSessionsRemaining: data['freeSessionsRemaining'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'gender': gender,
      'loginId': loginId,
      'age': age,
      'status': status,
      'isSoftDeleted': isSoftDeleted,
      'hasPasswordSet': hasPasswordSet,
      'updatedAt': FieldValue.serverTimestamp(),
      'patientId': patientId,
      'isArchived': isArchived,
      'whatsappNumber': whatsappNumber,
      'reminderConfig': reminderConfig?.toMap(),
      'address': address,
      'email': email,
      'dob': dob,
      'hasJoinedSocials': hasJoinedSocials,
      'geoLocation': geoLocation,
      'photoUrl': photoUrl,
      'goals': goals.toMap(),
      'freeSessionsRemaining': freeSessionsRemaining ?? 0,
    };
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? mobile,
    String? gender,
    String? loginId,
    int? age,
    bool? hasPasswordSet,
    String? patientId,
    bool? isArchived,
    String? whatsappNumber,
    String? status,
    bool? isSoftDeleted,
    ClientReminderConfig? reminderConfig, String? address,
    Map<String, double>? geoLocation,// {lat: 0.0, lng: 0.0}
    String? photoUrl,
    bool? hasJoinedSocials,
    String? email,
    DateTime? dob,
    ClientGoalModel? goals,int? freeSessionsRemaining,

  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      gender: gender ?? this.gender,
      loginId: loginId ?? this.loginId,
      age: age ?? this.age,
      hasPasswordSet: hasPasswordSet ?? this.hasPasswordSet,
      patientId: patientId ?? this.patientId,
      isArchived: isArchived ?? this.isArchived,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      status: status ?? this.status,
      isSoftDeleted: isSoftDeleted ?? this.isSoftDeleted,
      reminderConfig: reminderConfig ?? this.reminderConfig,
      address: address ?? this.address,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      hasJoinedSocials: hasJoinedSocials ?? this.hasJoinedSocials,
      geoLocation: geoLocation ?? this.geoLocation,
      photoUrl: photoUrl ?? this.photoUrl,
      goals: goals ?? this.goals,
      freeSessionsRemaining: freeSessionsRemaining ?? this.freeSessionsRemaining,
    );
  }
}
