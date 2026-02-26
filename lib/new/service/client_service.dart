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

  CollectionReference get _clientCollection => _firestore.collection('clients');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 🎯 TENANT CONFIGURATION (V4)
  static const String kAuthDomain = "@nutricare-v4.com";
  static const String kDefaultTenant = "guest";

  // ---------------------------------------------------------------------------
  // 🔐 CORE SECURITY HELPERS
  // ---------------------------------------------------------------------------

  String _generateVirtualEmail(String mobile, String tenantId) {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final cleanTenant = tenantId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

    final effectiveTenant = cleanTenant.isEmpty ? kDefaultTenant : cleanTenant;

    return "${effectiveTenant}_$cleanMobile$kAuthDomain";
  }

  // ---------------------------------------------------------------------------
  // 🚀 AUTHENTICATION FLOWS
  // ---------------------------------------------------------------------------

  Future<ClientModel> clientSignIn(String mobile, String pin, {String tenantId = kDefaultTenant}) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');

    // 🎯 STRICT TENANT CHECK: Ensure they belong to this exact clinic
    final query = await _clientCollection
        .where('mobile', isEqualTo: cleanMobile)
        .where('tenantId', isEqualTo: tenantId) // 🔒 Prevents cross-tenant leaks
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception("Access denied. No account found for this number at this clinic.");
    }

    // 2. Get Data
    final doc = query.docs.first;
    final data = doc.data() as Map<String, dynamic>;
    final client = ClientModel.fromFirestore(doc);

    // 3. Security Checks
    if (client.isSoftDeleted || client.isArchived) {
      throw Exception("This account has been deactivated.");
    }
    if (!data.containsKey('isActivated') || data['isActivated'] != true) {
      throw Exception("Account exists but is not activated.");
    }

    // 4. Determine Email
    final String storedEmail = client.authEmail ?? '';
    final String clientTenantId = client.tenantId.isEmpty ? kDefaultTenant : client.tenantId;

    final String emailToUse = storedEmail.isNotEmpty
        ? storedEmail
        : _generateVirtualEmail(cleanMobile, clientTenantId);

    // 5. Authenticate
    try {
      await _auth.signInWithEmailAndPassword(email: emailToUse, password: pin);

      // 6. 🎯 CRITICAL FIX: Wrap the "Link Fix" in try-catch
      try {
        final currentUser = _auth.currentUser;
        if (currentUser != null && client.authUid != currentUser.uid) {
          _logger.i("Attempting to self-heal authUid link...");
          await _clientCollection.doc(client.id).update({
            'authUid': currentUser.uid,
            'authEmail': emailToUse
          });
          _logger.i("Link repaired successfully.");
        }
      } catch (linkError) {
        _logger.w("Non-fatal error repairing auth link: $linkError");
      }

      return client;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        throw Exception("Invalid PIN or Login Credentials.");
      }
      rethrow;
    }
  }

  Future<void> registerNewUser({
    required String name,
    required String mobile,
    required String password,
  }) async {
    final cleanMobile = mobile.trim();

    // 🎯 STRICT TENANT CHECK for Registration
    final existingQuery = await _clientCollection
        .where('mobile', isEqualTo: cleanMobile)
        .where('tenantId', isEqualTo: kDefaultTenant)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw Exception("This mobile number is already registered. Please login.");
    }

    final virtualEmail = _generateVirtualEmail(cleanMobile, kDefaultTenant);

    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: virtualEmail,
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
        patientId: 'GUEST-${cleanMobile.substring(cleanMobile.length - 4)}',
        hasPasswordSet: true,
        status: 'Active',
        isArchived: false,
        isSoftDeleted: false,
        reminderConfig: ClientReminderConfig.defaultConfig(),
        clientType: 'new',
        authEmail: virtualEmail,
        tenantId: kDefaultTenant,
      );

      await _clientCollection.doc(user.uid).set(newClient.toMap());
      _logger.i("New guest registered: $cleanMobile (Tenant: $kDefaultTenant)");

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception("User already exists (Auth conflict).");
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Registration failed: $e");
    }
  }

  Future<void> activateClientAccess({
    required ClientModel client,
    required String pin,
  }) async {
    final String tenantId = client.tenantId.isNotEmpty ? client.tenantId : kDefaultTenant;
    final virtualEmail = _generateVirtualEmail(client.mobile, tenantId);

    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
          email: virtualEmail,
          password: pin
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        cred = await _auth.signInWithEmailAndPassword(
            email: virtualEmail,
            password: pin
        );
      } else {
        rethrow;
      }
    }

    if (cred.user == null) throw Exception("Activation failed: No user created.");

    await _clientCollection.doc(client.id).update({
      'authUid': cred.user!.uid,
      'authEmail': virtualEmail,
      'isActivated': true,
      'hasPasswordSet': true,
      'password': pin,
      'activatedAt': FieldValue.serverTimestamp(),
      'status': 'Active',
    });
  }

  Future<void> updateClient(ClientModel client) async {
    try {
      await _clientCollection.doc(client.id).update(client.toMap());
    } catch (e) {
      throw Exception('Failed to update client record: $e');
    }
  }

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



}