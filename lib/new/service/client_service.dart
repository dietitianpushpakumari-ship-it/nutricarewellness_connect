import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/core/utils/client_goal_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:nutricare_connect/core/utils/database_provider.dart';

import '../../core/utils/client_model.dart' show ClientModel, AppUserModel;

final clientServiceProvider = Provider((ref) => ClientService(ref));

final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

class ClientService {
  final Ref _ref;

  ClientService(this._ref);

  // 🎯 DYNAMIC GETTERS
  FirebaseFirestore get _firestore => _ref.read(firestoreProvider);
  FirebaseAuth get _auth => _ref.read(authProvider);
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  CollectionReference get _clientCollection => _firestore.collection('clients');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 🎯 TENANT CONFIGURATION (V4)
  static const String kAuthDomain = "@nutricare-v4.com";
  static const String kDefaultTenant = "guest";

  // ---------------------------------------------------------------------------
  // 🔐 CORE SECURITY HELPERS
  // ---------------------------------------------------------------------------

  Future<void> activateClientAccess({
    required String patientId,
    required String mobile,
    required String activationCode,
    required String pin
  }) async {
    try {
      final callable = _functions.httpsCallable('secureClientActivation');

      final result = await callable.call({
        'patientId': patientId,
        'mobile': mobile,
        'activationCode': activationCode,
        'pin': pin,
      });

      if (result.data['success'] != true) {
        throw Exception("Server rejected activation.");
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? "Activation failed.");
    } catch (e) {
      throw Exception("Network error. Please try again.");
    }
  }

  // 🛡️ 2. CALL GUEST REGISTRATION FUNCTION
  Future<void> registerNewUser({
    required String name,
    required String mobile,
    required String password,
  }) async {
    try {
      final callable = _functions.httpsCallable('secureGuestRegistration');

      final result = await callable.call({
        'name': name,
        'mobile': mobile,
        'pin': password,
      });

      if (result.data['success'] != true) {
        throw Exception("Server rejected registration.");
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? "Registration failed.");
    } catch (e) {
      throw Exception("Network error. Please try again.");
    }
  }


  Future<void> updateClient(ClientModel client) async {
    try {
      await _clientCollection.doc(client.id).update(client.toMap());
    } catch (e) {
      throw Exception('Failed to update client record: $e');
    }
  }

  String _generateVirtualEmail(String mobile, String tenantId) {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final cleanTenant = tenantId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

    final effectiveTenant = cleanTenant.isEmpty ? kDefaultTenant : cleanTenant;

    return "${effectiveTenant}_$cleanMobile$kAuthDomain";
  }

  // ---------------------------------------------------------------------------
  // 🚀 AUTHENTICATION FLOWS
  // ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
  // 🚀 AUTHENTICATION FLOWS (UPDATED FOR MULTI-PROFILE)
  // ---------------------------------------------------------------------------

  Future<List<ClientModel>> clientSignIn(String mobile, String pin, {String tenantId = kDefaultTenant}) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final virtualEmail = _generateVirtualEmail(cleanMobile, tenantId);

    // 1. Authenticate with Firebase FIRST
    try {
      await _auth.signInWithEmailAndPassword(email: virtualEmail, password: pin);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception("Invalid PIN or Login Credentials.");
      }
      rethrow;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Authentication failed.");

    // 2. Fetch ALL profiles linked to this mobile number & tenant
    final query = await _clientCollection
        .where('mobile', isEqualTo: cleanMobile)
        .where('tenantId', isEqualTo: tenantId)
        .get();

    if (query.docs.isEmpty) {
      throw Exception("Access denied. No account found for this number at this clinic.");
    }

    List<ClientModel> activeProfiles = [];
    for (var doc in query.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final client = ClientModel.fromFirestore(doc);

      // Filter out deactivated or non-activated
      if (!client.isSoftDeleted && !client.isArchived && data['isActivated'] == true) {
        activeProfiles.add(client);

        // 🎯 SELF-HEALING: If the authUid isn't linked yet, link it now.
        if (client.authUid != currentUser.uid) {
          _logger.i("Self-healing authUid link for ${client.name}...");
          await doc.reference.update({
            'authUid': currentUser.uid,
            'authEmail': virtualEmail
          });
        }
      }
    }

    if (activeProfiles.isEmpty) {
      throw Exception("No active profiles found for this account.");
    }

    return activeProfiles;
  }

  // 🛡️ 1. CALL CLINIC ACTIVATION FUNCTION

  // ---------------------------------------------------------------------------
  // 🔍 VERIFICATION & UTILS
  // ---------------------------------------------------------------------------

  Future<bool> verifyPatientInLiveDb(String patientId) async {
    try {
      final liveDb = FirebaseFirestore.instanceFor(app: Firebase.app());
      final query = await liveDb.collection('clients')
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      _logger.e("Error verifying patient: $e");
      return false;
    }
  }

  Future<ClientModel?> getClientByLoginId(String loginId) async {
    try {
      final query = await _clientCollection
          .where('loginId', isEqualTo: loginId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return ClientModel.fromFirestore(query.docs.first);
    } catch (e) {
      return null;
    }
  }

  // 🎯 ROBUST GETTER WITH AGGRESSIVE CACHING
  Future<ClientModel?> getClientById(String uid) async {
    try {
      // 1. Check local device cache first (Saves Firebase Billing!)
      try {
        final cachedDoc = await _clientCollection.doc(uid).get(const GetOptions(source: Source.cache));
        if (cachedDoc.exists) return ClientModel.fromFirestore(cachedDoc);
      } catch (_) {
        // Silently ignore cache miss and proceed to server
      }

      // 2. Fetch from Server
      final doc = await _clientCollection.doc(uid).get();
      if (doc.exists) return ClientModel.fromFirestore(doc);

      // 3. Try AuthUid Lookup (Fallback)
      final query = await _clientCollection.where('authUid', isEqualTo: uid).limit(1).get();
      if (query.docs.isNotEmpty) return ClientModel.fromFirestore(query.docs.first);

      // 4. 🚑 SELF-HEALING: Try to find by Mobile from Auth Email
      final user = _auth.currentUser;
      if (user != null && user.uid == uid && user.email != null) {
        final email = user.email!;
        if (email.contains('@') && email.contains('_')) {
          final parts = email.split('@')[0].split('_');
          final mobile = parts.last;

          final mobileQuery = await _clientCollection.where('mobile', isEqualTo: mobile).limit(1).get();
          if (mobileQuery.docs.isNotEmpty) {
            final clientDoc = mobileQuery.docs.first;
            await clientDoc.reference.update({'authUid': uid});
            return ClientModel.fromFirestore(clientDoc);
          }
        }
      }
      return null;
    } catch (e) {
      _logger.e("Error fetching client profile: $e");
      return null;
    }
  }

  Future<void> registerClientCredentials(String clientId, String mobileNumber, String password) async {}

  Future<void> clientForgotPassword(String loginId) async {
    throw Exception("Please contact your clinic admin to reset your PIN via Activation Code.");
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
      final Uint8List originalBytes = await file.readAsBytes();

      // 🎯 COMPRESS & CONVERT TO WEBP
      final Uint8List? webpBytes = await FlutterImageCompress.compressWithList(
        originalBytes,
        minHeight: 1080, // Clinical standard height
        minWidth: 1080,
        quality: 75,     // Optimal balance for dietitians
        format: CompressFormat.webp,
      );

      if (webpBytes == null) return null;

      final fileName = "${DateTime.now().millisecondsSinceEpoch}.webp";
      final storageRef = _storage.ref().child('$path/$fileName');

      // 🚀 PUSH TO SERVER
      await storageRef.putData(
          webpBytes,
          SettableMetadata(contentType: 'image/webp')
      );

      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint("WebP Compression failed: $e");
      return null;
    }
  }
  Future<String?> uploadMealPhoto(XFile? file, String path) async {
    if (file == null) return null;

    try {
      final Uint8List fileBytes = await file.readAsBytes();

      // 🎯 COMPRESS & CONVERT TO WEBP
      final Uint8List? webpBytes = await FlutterImageCompress.compressWithList(
        fileBytes,
        minHeight: 1080, // Clinical standard resolution
        minWidth: 1080,
        quality: 80,     // 80% retains detail while dropping file size
        format: CompressFormat.webp,
      );

      if (webpBytes == null) return null;

      final fileName = "${DateTime.now().millisecondsSinceEpoch}.webp";
      final storageRef = _storage.ref().child('$path/$fileName');

      // Upload with WebP metadata
      await storageRef.putData(
          webpBytes,
          SettableMetadata(contentType: 'image/webp')
      );

      return await storageRef.getDownloadURL();
    } catch (e) {
      print("Error uploading meal photo: $e");
      return null;
    }
  }
  Future<List<ClientModel>> getProfilesForAuthenticatedUser(String mobile) async {
    // 🚀 THE FIX: Changed _db to _firestore
    final snap = await _firestore.collection('clients')
        .where('mobile', isEqualTo: mobile)
        .where('isSoftDeleted', isEqualTo: false)
        .where('isArchived', isEqualTo: false)
        .get();

    return snap.docs.map((doc) => ClientModel.fromFirestore(doc)).toList();
  }

}