import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:pure_shift/core/utils/CloudinaryService.dart';
import 'package:path_provider/path_provider.dart'; // 🚀 Added for temp directory

import 'package:pure_shift/core/utils/database_provider.dart';
import '../../core/utils/client_model.dart' show ClientModel;


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

  // 🎯 TENANT CONFIGURATION (V4)
  static const String kAuthDomain = "@nutricare-v4.com";
  static const String kDefaultTenant = "guest";

  // ---------------------------------------------------------------------------
  // 🔐 CORE SECURITY HELPERS & ACTIVATION
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // 🔐 CORE SECURITY HELPERS & ACTIVATION
  // ---------------------------------------------------------------------------

  Future<void> activateClientAccess({
    required String patientId,
    required String mobile,
    required String activationCode,
    required String pin,
    bool isResetting = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('secureClientActivation');

      final result = await callable.call({
        'patientId': patientId,
        'mobile': mobile,
        'activationCode': activationCode,
        'pin': pin,
        'isResetting': isResetting, // 🚀 THE FIX: Send the flag to the backend!
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
  // 🛡️ GUEST REGISTRATION FUNCTION
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

  // ---------------------------------------------------------------------------
  // 🚀 MULTI-TENANT PROFILE FETCHING
  // ---------------------------------------------------------------------------

  Future<ClientModel?> getSpecificProfile(String uid, String patientId, String tenantId) async {
    try {
      final snapshot = await _clientCollection
          .where('tenantId', isEqualTo: tenantId)
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ClientModel.fromFirestore(snapshot.docs.first);
      }

      return null;
    } catch (e) {
      debugPrint("❌ Error fetching specific profile: $e");
      return null;
    }
  }

  Future<List<ClientModel>> getProfilesForAuthenticatedUser(String mobile) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');

    final snap = await _clientCollection
        .where('mobile', isEqualTo: cleanMobile)
        .where('isSoftDeleted', isEqualTo: false)
        .where('isArchived', isEqualTo: false)
        .get();

    return snap.docs.map((doc) => ClientModel.fromFirestore(doc)).toList();
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

  Future<ClientModel?> getClientById(String uid) async {
    try {
      try {
        final cachedDoc = await _clientCollection.doc(uid).get(const GetOptions(source: Source.cache));
        if (cachedDoc.exists) return ClientModel.fromFirestore(cachedDoc);
      } catch (_) {}

      final doc = await _clientCollection.doc(uid).get();
      if (doc.exists) return ClientModel.fromFirestore(doc);

      final query = await _clientCollection.where('authUid', isEqualTo: uid).limit(1).get();
      if (query.docs.isNotEmpty) return ClientModel.fromFirestore(query.docs.first);

      return null;
    } catch (e) {
      _logger.e("Error fetching client profile: $e");
      return null;
    }
  }

  Future<void> clientForgotPassword(String loginId) async {
    throw Exception("Please contact your clinic admin to reset your PIN via Activation Code.");
  }

  // ---------------------------------------------------------------------------
  // 📱 OTP HELPERS
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // 🖼️ CLOUDINARY FILE UPLOAD (WITH WEBP COMPRESSION)
  // ---------------------------------------------------------------------------

  Future<List<String>> uploadFiles(List<XFile> files, String folderName) async {
    final List<Future<String?>> uploadFutures = [];
    for (var file in files) {
      uploadFutures.add(_uploadFile(file, folderName));
    }
    final results = await Future.wait(uploadFutures);
    return results.whereType<String>().toList();
  }

  Future<String?> _uploadFile(XFile? file, String folderName) async {
    if (file == null) return null;
    try {
      // 1. Create a temporary path for the compressed file
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.webp';

      // 2. 🎯 COMPRESS & CONVERT TO WEBP
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        minHeight: 1080,
        minWidth: 1080,
        quality: 75,
        format: CompressFormat.webp,
      );

      if (compressedXFile == null) return null;

      // 3. 🚀 UPLOAD TO CLOUDINARY
      final cloudinaryService = _ref.read(cloudinaryServiceProvider);
      final String? secureUrl = await cloudinaryService.uploadFile(
        file: File(compressedXFile.path),
        folderName: folderName,
      );

      // 4. Cleanup temporary file to save device storage
      File(compressedXFile.path).delete().ignore();

      return secureUrl;
    } catch (e) {
      debugPrint("Cloudinary Upload/Compression failed: $e");
      return null;
    }
  }

  Future<String?> uploadMealPhoto(XFile? file, String folderName) async {
    if (file == null) return null;

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = '${tempDir.path}/meal_${DateTime.now().millisecondsSinceEpoch}.webp';

      // 🎯 COMPRESS & CONVERT TO WEBP
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        minHeight: 1080,
        minWidth: 1080,
        quality: 80,
        format: CompressFormat.webp,
      );

      if (compressedXFile == null) return null;

      // 🚀 UPLOAD TO CLOUDINARY
      final String? secureUrl = await _ref.read(cloudinaryServiceProvider).uploadFile(
        file: File(compressedXFile.path),
        folderName: folderName,
      );

      // Cleanup
      File(compressedXFile.path).delete().ignore();

      return secureUrl;
    } catch (e) {
      debugPrint("Error uploading meal photo to Cloudinary: $e");
      return null;
    }
  }
}