import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_shift/core/utils/client_goal_model.dart';
import 'package:pure_shift/features/dietplan/domain/entities/reminder_config_model.dart';

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
  final Map<String, double>? geoLocation;
  final String? photoUrl;
  final bool hasJoinedSocials;
  final String? email;

  // 🎯 AUTH FIELDS
  final String? authEmail;
  final String? authUid;
  final String tenantId;
  final String? coachId;

  final DateTime? dob;
  final ClientGoalModel goals;
  final int? freeSessionsRemaining;
  final String clientType;

  // 🔔 NOTIFICATIONS & CHAT
  final String? fcmToken;
  final String? lastMessage;
  final Timestamp? lastMessageTime;
  final bool hasPendingRequest;
  final bool loginAllowed;
  final bool chatEnabled;

  // 🏋️ WORKOUT FIELDS (Added)
  final List<dynamic> assignedWorkouts;

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
    this.reminderConfig,
    this.address,
    this.geoLocation,
    this.coachId,
    this.photoUrl,
    this.hasJoinedSocials = false,
    this.email,

    // 🎯 Auth Params
    this.authEmail,
    this.authUid,
    this.tenantId = 'guest',

    this.dob,
    this.goals = const ClientGoalModel(),
    this.freeSessionsRemaining = 1,
    this.clientType = 'new',
    this.fcmToken,
    this.lastMessage,
    this.lastMessageTime,
    this.hasPendingRequest = false,
    this.loginAllowed = false,
    this.chatEnabled = false,

    // 🏋️ Workout Params
    this.assignedWorkouts = const [], // Default to empty list
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
      coachId: data['coachId'] as String?,
      gender: data['gender'] ?? '',
      reminderConfig: data['reminderConfig'] != null
          ? ClientReminderConfig.fromMap(Map<String, dynamic>.from(data['reminderConfig']))
          : ClientReminderConfig.defaultConfig(),
      address: data['address'] as String?,
      email: data['email'] ?? '',

      // 🎯 READ AUTH FIELDS
      authEmail: data['authEmail'],
      authUid: data['authUid'],
      tenantId: data['tenantId'] ?? 'guest',

      dob: (data['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasJoinedSocials: data['hasJoinedSocials'] ?? false,
      geoLocation: data['geoLocation'] != null
          ? Map<String, double>.from(data['geoLocation'].map((key, value) => MapEntry(key.toString(), (value as num).toDouble())))
          : null,
      photoUrl: data['photoUrl'],
      goals: data['goals'] != null
          ? ClientGoalModel.fromMap(Map<String, dynamic>.from(data['goals']))
          : ClientGoalModel.defaultGoals(),
      freeSessionsRemaining: data['freeSessionsRemaining'] ?? 0,
      fcmToken: data['fcmToken']?.toString(),
      lastMessage: data['lastMessage'] as String?,
      lastMessageTime: data['lastMessageTime'] as Timestamp?,
      hasPendingRequest: data['hasPendingRequest'] ?? false,
      loginAllowed: data['loginAllowed'] ?? false,
      chatEnabled: data['chatEnabled'] ?? false,

      // 🏋️ READ WORKOUT FIELDS
      assignedWorkouts: data['assignedWorkouts'] ?? [],
    );
  }

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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
      coachId: data['coachId'] as String?,
      whatsappNumber: data['whatsappNumber'] ?? '',
      gender: data['gender'] ?? '',
      reminderConfig: data['reminderConfig'] != null
          ? ClientReminderConfig.fromMap(Map<String, dynamic>.from(data['reminderConfig']))
          : ClientReminderConfig.defaultConfig(),
      address: data['address'] as String?,
      email: data['email'] ?? '',

      // 🎯 READ AUTH FIELDS
      authEmail: data['authEmail'],
      authUid: data['authUid'],
      tenantId: data['tenantId'] ?? 'guest',

      dob: (data['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasJoinedSocials: data['hasJoinedSocials'] ?? false,
      geoLocation: data['geoLocation'] != null
          ? Map<String, double>.from(data['geoLocation'].map((key, value) => MapEntry(key.toString(), (value as num).toDouble())))
          : null,
      photoUrl: data['photoUrl'],
      goals: data['goals'] != null
          ? ClientGoalModel.fromMap(Map<String, dynamic>.from(data['goals']))
          : ClientGoalModel.defaultGoals(),
      freeSessionsRemaining: data['freeSessionsRemaining'] ?? 0,
      fcmToken: data['fcmToken']?.toString(),
      lastMessage: data['lastMessage'] as String?,
      lastMessageTime: data['lastMessageTime'] as Timestamp?,
      hasPendingRequest: data['hasPendingRequest'] ?? false,
      loginAllowed: data['loginAllowed'] ?? false,
      chatEnabled: data['chatEnabled'] ?? false,

      // 🏋️ READ WORKOUT FIELDS
      assignedWorkouts: data['assignedWorkouts'] ?? [],
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

      // 🎯 SAVE AUTH FIELDS
      'authEmail': authEmail,
      'authUid': authUid,
      'tenantId': tenantId,

      'dob': dob,
      'hasJoinedSocials': hasJoinedSocials,
      'geoLocation': geoLocation,
      'photoUrl': photoUrl,
      'goals': goals.toMap(),
      'coachId': coachId,
      'freeSessionsRemaining': freeSessionsRemaining ?? 0,
      'fcmToken': fcmToken,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'hasPendingRequest': hasPendingRequest,
      'loginAllowed': loginAllowed,
      'chatEnabled': chatEnabled,

      // 🏋️ SAVE WORKOUT FIELDS
      'assignedWorkouts': assignedWorkouts,
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
    ClientReminderConfig? reminderConfig,
    String? address,
    Map<String, double>? geoLocation,
    String? photoUrl,
    bool? hasJoinedSocials,
    String? email,
    String? coachId,
    // 🎯 Auth Params
    String? authEmail,
    String? authUid,
    String? tenantId,

    DateTime? dob,
    ClientGoalModel? goals,
    int? freeSessionsRemaining,
    String? fcmToken,
    String? lastMessage,
    Timestamp? lastMessageTime,
    bool? hasPendingRequest,
    bool? loginAllowed,
    bool? chatEnabled,

    // 🏋️ Workout Params
    List<dynamic>? assignedWorkouts,
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
      coachId: coachId ?? this.coachId,

      // 🎯 Copy Auth Params
      authEmail: authEmail ?? this.authEmail,
      authUid: authUid ?? this.authUid,
      tenantId: tenantId ?? this.tenantId,

      dob: dob ?? this.dob,
      hasJoinedSocials: hasJoinedSocials ?? this.hasJoinedSocials,
      geoLocation: geoLocation ?? this.geoLocation,
      photoUrl: photoUrl ?? this.photoUrl,
      goals: goals ?? this.goals,
      freeSessionsRemaining: freeSessionsRemaining ?? this.freeSessionsRemaining,
      fcmToken: fcmToken ?? this.fcmToken,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      hasPendingRequest: hasPendingRequest ?? this.hasPendingRequest,
      loginAllowed: loginAllowed ?? this.loginAllowed,
      chatEnabled: chatEnabled ?? this.chatEnabled,

      // 🏋️ Copy Workout Params
      assignedWorkouts: assignedWorkouts ?? this.assignedWorkouts,
    );
  }
}