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
import 'package:firebase_core/firebase_core.dart'; // Required for Firebase.app()

import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/core/utils/client_goal_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:nutricare_connect/core/utils/database_provider.dart';

import '../../core/utils/client_model.dart' show ClientModel, AppUserModel; // 🎯 Import Database Provider

// 🎯 UPDATE PROVIDER TO PASS REF
final clientServiceProvider = Provider((ref) => ClientService(ref));

final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

class ClientService {
  final Ref _ref; // 🎯 Store Ref

  ClientService(this._ref);

  // 🎯 DYNAMIC GETTERS (Read from the current active provider)
  FirebaseFirestore get _firestore => _ref.read(firestoreProvider);
  FirebaseAuth get _auth => _ref.read(authProvider);

  // Helper Getters
  CollectionReference get _clientCollection => _firestore.collection('clients');
  CollectionReference get _appUserCollection => _firestore.collection('app_users');
  CollectionReference get _clientLogCollection => _firestore.collection('client_logs');

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static const bool kBypassOtpVerification = true;

  // --- 🎯 NEW: REGISTER NEW USER (Guest Mode) ---
  Future<void> registerNewUser({
    required String name,
    required String mobile,
    required String password,
  }) async {
    final cleanMobile = mobile.trim();

    // Check if mobile already exists in the CURRENT db (Guest or Live)
    final existingQuery = await _clientCollection
        .where('mobile', isEqualTo: cleanMobile)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw Exception("This mobile number is already registered. Please login.");
    }

    final shadowEmail = "$cleanMobile@nutricarewellness.in";

    try {
      // Create Auth User in CURRENT Auth instance
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: shadowEmail,
        password: password,
      );

      final User? user = cred.user;
      if (user == null) throw Exception("Auth creation failed.");

      final newClient = ClientModel(
        id: user.uid,
        name: name,
        mobile: cleanMobile,
        loginId: cleanMobile,
        gender: 'Unknown',
        // Generate a temp patient ID for guests
        patientId: 'GUEST-${cleanMobile.substring(cleanMobile.length - 4)}',
        hasPasswordSet: true,
        status: 'Active',
        isArchived: false,
        isSoftDeleted: false,
        reminderConfig: ClientReminderConfig.defaultConfig(),
        clientType: 'new', // Mark as new/guest
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

  // --- 🎯 SPECIAL: Verify Patient ID in LIVE DB ---
  // This method ALWAYS checks the production database, regardless of current mode
  Future<bool> verifyPatientInLiveDb(String patientId) async {
    try {
      // Always get the default (Live) app instance
      final liveDb = FirebaseFirestore.instanceFor(app: Firebase.app());

      final query = await liveDb.collection('clients')
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      _logger.e("Error verifying patient in live DB: $e");
      return false;
    }
  }

  // --- EXISTING METHODS (Updated to use dynamic getters) ---

  Future<User> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in was canceled.');

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Use dynamic _auth
    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user == null) throw Exception("Firebase sign-in failed.");

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
      // Note: Cloud functions typically run on the Live project environment.
      // If you need guest mode support here, you might need direct Firestore queries
      // instead of Cloud Functions for the Guest DB.
      // For now, assuming Cloud Function works or we use a direct query fallback:

      final query = await _clientCollection
          .where('loginId', isEqualTo: loginId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      final client = ClientModel.fromFirestore(doc);

      if (client.isSoftDeleted || client.isArchived) return null;

      return client;
    } catch (e) {
      _logger.e('Error finding client by loginId: $e');
      return null;
    }
  }

  // Only used in Live mode typically
  Future<ClientModel?> getClientByPatientIdAndMobile(String patientId, String mobile) async {
    // This usually calls a Cloud Function.
    // If you are in Guest mode, this might fail if the function isn't deployed there.
    // For Hybrid logic, we usually rely on _validateRegistration in AuthScreen to switch to Live first.

    final HttpsCallable callable = _functions.httpsCallable('verifyClientData');

    try {
      final result = await callable.call({
        'patientId': patientId,
        'mobile': mobile,
      });

      final rawData = result.data;
      if (rawData == null) return null;

      final data = Map<String, dynamic>.from(rawData as Map);

      if (data['found'] == true) {
        final rawClientData = data['client'] as Map;
        final clientData = Map<String, dynamic>.from(rawClientData);

        // ... mapping logic ...
        String docId = clientData['id'] ?? '';
        if (docId.isEmpty && clientData['uid'] != null) docId = clientData['uid'];

        return ClientModel(
          id: docId,
          patientId: patientId,
          mobile: mobile,
          loginId: mobile,
          hasPasswordSet: false, // Typically check logic here
          status: clientData['status'] ?? 'Inactive',
          isArchived: clientData['isArchived'] ?? false,
          isSoftDeleted: clientData['isSoftDeleted'] ?? false,
          name: clientData['name'],
          gender: clientData['gender'] ?? '',
          reminderConfig: ClientReminderConfig.fromMap(clientData['reminderConfig'] as Map<String, dynamic>?),
        );
      }
      return null;
    } catch (e) {
      // Fallback to direct DB query if function fails (e.g. in testing)
      // This is useful for Guest Mode where functions might not exist
      final query = await _clientCollection
          .where('patientId', isEqualTo: patientId)
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return ClientModel.fromFirestore(query.docs.first);
      }
      throw Exception('Verification failed.');
    }
  }

  Future<void> registerClientCredentials(String clientId, String mobileNumber, String password) async {
    // Cloud function call - usually on Live env
    final HttpsCallable callable = _functions.httpsCallable('adminSetClientPassword');
    await callable.call<dynamic>({
      'clientId': clientId,
      'mobileNumber': mobileNumber,
      'password': password,
      'updateData': {'hasPasswordSet': true, 'status': 'Active'},
    });
  }

  Future<User?> clientSignIn(String loginId, String password) async {
    final ClientModel? client = await getClientByLoginId(loginId);
    if (client == null) throw Exception('Invalid Login ID or account inactive.');

    final cleanMobile = client.mobile.trim();
    final authEmail = '$cleanMobile@nutricarewellness.in';

    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: authEmail, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
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

  // --- OTP HELPERS (Unchanged) ---
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

  // --- FILE UPLOAD (Unchanged) ---
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

  Future<ClientModel?> getClientById(String clientId) async {
    try {
      final doc = await _clientCollection.doc(clientId).get();
      if (!doc.exists) return null;
      return ClientModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }
}