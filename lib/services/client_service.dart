import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/core/utils/client_goal_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';

// --- CONCEPTUAL MODELS ---

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
      goals: data['goals'] != null
          ? ClientGoalModel.fromMap(Map<String, dynamic>.from(data['goals']))
          : ClientGoalModel.defaultGoals(),
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
    ClientGoalModel? goals,

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
    );
  }
}

// -----------------------------------------------------------

final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));
final clientServiceProvider = Provider((ref) => ClientService());

class ClientService {
  final CollectionReference _clientCollection = FirebaseFirestore.instance.collection('clients');
  final CollectionReference _appUserCollection = FirebaseFirestore.instance.collection('app_users');
  final CollectionReference _clientLogCollection = FirebaseFirestore.instance.collection('client_logs');

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static const bool kBypassOtpVerification = true;

  // --- 🎯 NEW: REGISTER NEW USER (No OTP, Shadow Email) ---
  Future<void> registerNewUser({
    required String name,
    required String mobile,
    required String password,
  }) async {
    // 1. Sanitize Input
    final cleanMobile = mobile.trim();

    // 2. Check if mobile already exists
    final existingQuery = await _clientCollection
        .where('mobile', isEqualTo: cleanMobile)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw Exception("This mobile number is already registered. Please login.");
    }

    // 3. Create Shadow Email
    final shadowEmail = "$cleanMobile@nutricarewellness.in";

    try {
      // 4. Create Auth User
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: shadowEmail,
        password: password,
      );

      final User? user = cred.user;
      if (user == null) throw Exception("Auth creation failed.");

      // 5. Create Client Record in Firestore
      final newClient = ClientModel(
        id: user.uid,
        name: name,
        mobile: cleanMobile,
        loginId: cleanMobile,
        gender: 'Unknown',
        patientId: 'NEW-${cleanMobile.substring(cleanMobile.length - 4)}',
        hasPasswordSet: true,
        status: 'Active',
        isArchived: false,
        isSoftDeleted: false,
        reminderConfig: ClientReminderConfig.defaultConfig(),
      );

      await _clientCollection.doc(user.uid).set(newClient.toMap());
      _logger.i("New user registered: $cleanMobile");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception("This mobile number is already registered.");
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Registration failed: $e");
    }
  }

  // --- EXISTING METHODS ---

  Future<User> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in was canceled.');

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user == null) throw Exception("Firebase sign-in failed.");

    // Ensure AppUser record
    final docRef = _appUserCollection.doc(user.uid);
    if (!(await docRef.get()).exists) {
      final newAppUser = AppUserModel(
        id: user.uid,
        mobile: user.phoneNumber ?? '',
        email: user.email ?? '',
        status: 'Active',
      );
      await docRef.set(newAppUser.toMap());
    }

    return user;
  }

  Future<User> registerNewAppUser({
    required String verificationId,
    required String smsCode,
    required String mobileNumber,
  }) async {
    final AuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user == null) throw Exception("Authentication failed.");

    final docRef = _appUserCollection.doc(user.uid);
    if (!(await docRef.get()).exists) {
      final newAppUser = AppUserModel(id: user.uid, mobile: mobileNumber);
      await docRef.set(newAppUser.toMap());
    }

    return user;
  }

  Future<void> updateClient(ClientModel client) async {
    _logger.i('Updating client record for: ${client.id}');
    try {
      await _clientCollection.doc(client.id).update(client.toMap());
    } catch (e) {
      _logger.e('Error updating client: $e');
      throw Exception('Failed to update client record.');
    }
  }

  Future<ClientModel?> getClientByLoginId(String loginId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('fetchClientByLoginId');
      final result = await callable.call<Map<String, dynamic>>({'loginId': loginId});

      final rawData = result.data;
      if (rawData == null || rawData.isEmpty || rawData['id'] == null) return null;

      // 🎯 FIX: Use robust parsing logic (reusing internal safe factory if possible, or just be careful)
      // We use fromMap here which we just secured.
      final client = ClientModel.fromMap(Map<String, dynamic>.from(rawData));

      if (client.isSoftDeleted || client.isArchived) return null;

      return client;
    } catch (e) {
      _logger.e('Error finding client by loginId: $e');
      return null;
    }
  }

  Future<ClientModel?> getClientByPatientIdAndMobile(String patientId, String mobile) async {
    _logger.i('Client App: Calling Cloud Function to verify Patient ID: $patientId and mobile: $mobile');

    final HttpsCallable callable = _functions.httpsCallable('verifyClientData');

    try {
      final result = await callable.call({
        'patientId': patientId,
        'mobile': mobile,
      });

      final rawData = result.data;

      if (rawData == null) {
        _logger.w('Cloud Function returned null data.');
        return null;
      }

      final data = Map<String, dynamic>.from(rawData as Map);

      if (data['found'] == true) {
        final rawClientData = data['client'] as Map;
        final clientData = Map<String, dynamic>.from(rawClientData);

        if (clientData['hasPasswordSet'] == true) {
          throw Exception('Account already registered. Please login or use "Forgot Password".');
        }

        String docId = clientData['id'] ?? '';
        if (docId.isEmpty && clientData['uid'] != null) docId = clientData['uid'];

        return ClientModel(
          id: docId,
          patientId: patientId,
          mobile: mobile,
          loginId: mobile,
          hasPasswordSet: false,
          status: clientData['status'] ?? 'Inactive',
          isArchived: clientData['isArchived'] ?? false,
          isSoftDeleted: clientData['isSoftDeleted'] ?? false,
          name: clientData['name'],
          gender: clientData['gender'] ?? '',
          reminderConfig: ClientReminderConfig.fromMap(clientData['reminderConfig'] as Map<String, dynamic>?),
        );
      }

      _logger.w('No client found matching verification data via Cloud Function.');
      return null;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw Exception(e.message);
      }
      _logger.e('Cloud Function verification error: ${e.code} - ${e.message}');
      throw Exception('Verification failed due to a server error.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> registerClientCredentials(String clientId, String mobileNumber, String password) async {
    if (clientId.isEmpty || mobileNumber.isEmpty || password.isEmpty) {
      throw Exception("Internal Error: Missing registration data (ID: $clientId, Mobile: $mobileNumber)");
    }

    await _callAdminSetPasswordFunction(
      clientId: clientId,
      mobileNumber: mobileNumber,
      password: password,
      updateData: {'hasPasswordSet': true, 'status': 'Active'},
    );
  }

  Future<User?> clientSignIn(String loginId, String password) async {
    // 1. Resolve Login ID to Client Model
    final ClientModel? client = await getClientByLoginId(loginId);
    if (client == null) throw Exception('Invalid Login ID or account inactive.');

    // 2. Construct Shadow Email (Sanitized)
    final cleanMobile = client.mobile.trim();
    final authEmail = '$cleanMobile@nutricarewellness.in';

    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: authEmail, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Fallback: Try with 'id@nutricarewellness.in' for legacy users
      try {
        final authEmailLegacy = '${client.id}@nutricarewellness.in';
        final UserCredential legacyCred = await _auth.signInWithEmailAndPassword(email: authEmailLegacy, password: password);
        return legacyCred.user;
      } catch (_) {
        throw Exception("Invalid Password.");
      }
    }
  }

  Future<void> clientForgotPassword(String loginId) async {
    final ClientModel? client = await getClientByLoginId(loginId);
    if (client == null) throw Exception("User not found.");

    final authEmail = '${client.mobile}@nutricarewellness.in';
    try {
      await _auth.sendPasswordResetEmail(email: authEmail);
    } catch (e) {
      throw Exception("Failed to send reset email.");
    }
  }

  Future<void> _callAdminSetPasswordFunction({
    required String clientId,
    required String mobileNumber,
    required String password,
    Map<String, dynamic> updateData = const {},
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('adminSetClientPassword');
    await callable.call<dynamic>({
      'clientId': clientId,
      'mobileNumber': mobileNumber,
      'password': password,
      'updateData': updateData,
    });
  }

  // --- OTP HELPERS ---

  Future<void> initiateClientOtpVerification({
    required String mobileNumber,
    required Function(String verificationId) codeSentCallback,
    required Function(String error) verificationFailedCallback,
  }) async {
    if (RegExp(r'^[0-9]+$').hasMatch(mobileNumber) && mobileNumber.length >= 10) {
      mobileNumber = '+91$mobileNumber';
    }
    await _auth.verifyPhoneNumber(
      phoneNumber: mobileNumber,
      verificationCompleted: (_) {},
      verificationFailed: (e) => verificationFailedCallback(e.message ?? 'Failed'),
      codeSent: (vid, token) => codeSentCallback(vid),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<PhoneAuthCredential> verifyOtpCode({required String verificationId, required String smsCode}) async {
    return PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
  }

  Future<String> generateAndSendOtp({required String mobileNumber}) async {
    // Placeholder for your Cloud Function PUSH OTP logic
    return 'SMS_REQUIRED';
  }

  Future<void> initiateMobileOtpRegistration({
    required String mobileNumber,
    required Function(String verificationId) codeSentCallback,
    required Function(String error) verificationFailedCallback,
  }) async {
    await initiateClientOtpVerification(
      mobileNumber: mobileNumber,
      codeSentCallback: codeSentCallback,
      verificationFailedCallback: verificationFailedCallback,
    );
  }

  // --- FILE UPLOAD ---

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'pdf') return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<List<String>> uploadFiles(List<XFile> files, String baseUploadPath,) async {
    final List<Future<String?>> uploadFutures = [];
    for (var file in files) {
      uploadFutures.add(_uploadFile(file, baseUploadPath));
    }
    final results = await Future.wait(uploadFutures);
    return results.whereType<String>().toList();
  }

  Future<String?> _uploadFile(XFile? file, String path) async {
    if (file == null) return null;
    try {
      final fileBytes = await file.readAsBytes();
      final fileName = file.name;
      final storageRef = _storage.ref().child('$path/$fileName');
      await storageRef.putData(fileBytes, SettableMetadata(contentType: _getMimeType(fileName)));
      return await storageRef.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // 🎯 DEBUGGED: getClientById
  Future<ClientModel?> getClientById(String clientId) async {
    try {
      print("🔍 Fetching Profile for UID: $clientId");
      final doc = await _clientCollection.doc(clientId).get();

      if (!doc.exists) {
        print("❌ Profile Document does not exist: $clientId");
        return null;
      }

      print("✅ Profile Found. Parsing data...");
      return ClientModel.fromFirestore(doc);
    } catch (e, stack) {
      print("❌ Error in getClientById: $e");
      print(stack);
      return null;
    }
  }
}