
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added for Provider

import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';


// --- CONCEPTUAL MODELS (Assumed to be defined elsewhere) ---

// 🎯 AppUserModel: For OTP-registered users (prospects)
class AppUserModel {
  final String id;
  final String mobile;
  final String email;
  final String status;

  const AppUserModel({required this.id, required this.mobile, this.email = '', this.status = 'Active'});

  Map<String, dynamic> toMap() {
    return {'mobile': mobile, 'email': email, 'status': status, 'createdAt': FieldValue.serverTimestamp()};
  }
}

// 🎯 ClientModel: For existing patients (from your previous context)
class ClientModel {
  final String id;
  final String mobile;
  final String loginId;
  final String patientId;
  final bool hasPasswordSet;
  final String status;
  final bool isSoftDeleted;
  final bool isArchived;
  final String? name;
  final int? age; //
  final String? whatsappNumber;
  ClientModel({
    required this.id, required this.mobile, required this.loginId,
    required this.patientId, this.hasPasswordSet = false,
    this.status = 'Inactive', this.isSoftDeleted = false, this.isArchived = false,required this.name,this.age,this.whatsappNumber
  });

  // Factory constructor for Cloud Function result (Map)
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
      whatsappNumber: data['whatsappNumber'] ?? ''
    );
  }

  // Original Factory constructor for Firestore DocumentSnapshot
  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ClientModel(
      id: doc.id ,
      mobile: data['mobile'] ?? '',
      loginId: data['loginId'] ?? data['mobile'] ?? '',
      patientId: data['patientId'] ?? '',
      hasPasswordSet: data['hasPasswordSet'] ?? false,
      status: data['status'] ?? 'Inactive',
      isSoftDeleted: data['isSoftDeleted'] ?? false,
      isArchived: data['isArchived'] ?? false,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      whatsappNumber: data['whatsappNumber'] ?? ''

    );
  }
}
// -----------------------------------------------------------

final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

// 🎯 ADDED Provider for Riverpod access (Assuming you use Riverpod based on client_auth_screen)
// NOTE: This requires adding 'package:flutter_riverpod/flutter_riverpod.dart' to the imports if missing.
// final clientServiceProvider = Provider((ref) => ClientService());

class ClientService {
  final CollectionReference _clientCollection = FirebaseFirestore.instance.collection('clients');
  final CollectionReference _appUserCollection = FirebaseFirestore.instance.collection('app_users');
  final CollectionReference _clientLogCollection = FirebaseFirestore.instance.collection('client_logs');
  // 🎯 NEW COLLECTION
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static const bool kBypassOtpVerification = true;


  // --- Helper Methods ---

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'pdf') return 'application/pdf';
    return 'application/octet-stream';
  }

  // --- NEW USER (MOBILE OTP) METHODS ---

  Future<User> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in was canceled.');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // This handles both linking and first-time creation in Firebase Auth
    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user == null) {
      throw Exception("Firebase sign-in failed with Google credentials.");
    }

    // 🎯 Ensure an AppUser record exists for all new Google sign-ins (Prospects)
    final docRef = _appUserCollection.doc(user.uid);
    if (!(await docRef.get()).exists) {
      final newAppUser = AppUserModel(
          id: user.uid,
          mobile: user.phoneNumber ?? '',
          email: user.email ?? '', // Verified Email!
          status: 'Active'
      );
      await docRef.set(newAppUser.toMap());
      _logger.i('New AppUser record created via Google: ${user.uid}');
    }

    return user;
  }

  /// 2. Completes registration by verifying OTP and creating the AppUser record.
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

    if (user == null) {
      throw Exception("Authentication failed. User is null.");
    }

    // Check if AppUser record already exists
    final docRef = _appUserCollection.doc(user.uid);
    if (!(await docRef.get()).exists) {
      // Create a new AppUser record in the separate collection
      final newAppUser = AppUserModel(id: user.uid, mobile: mobileNumber);
      await docRef.set(newAppUser.toMap());
      _logger.i('New AppUser record created for UID: ${user.uid}');
    }

    return user;
  }

  // --- EXISTING CLIENT/ADMIN METHODS ---

  // 🎯 FIX: Replaced direct Firestore read with a Cloud Function call to resolve PERMISSION_DENIED on login/forgot password.
  Future<ClientModel?> getClientByLoginId(String loginId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('fetchClientByLoginId');

      final result = await callable.call<Map<String, dynamic>>({
        'loginId': loginId,
      });

      final rawData = result.data;
      if (rawData == null || rawData.isEmpty || rawData['id'] == null) {
        return null;
      }

      final client = ClientModel.fromMap(rawData);

      // Still check local state flags for soft-deletion/archived status
      if (client.isSoftDeleted || client.isArchived) return null;

      return client;
    } on FirebaseFunctionsException catch (e) {
      // Log the error but throw a user-friendly message
      _logger.e('Cloud Function (fetchClientByLoginId) failed: ${e.code} - ${e.message}');
      throw Exception('Login ID check failed due to a server error.');
    } catch (e) {
      _logger.e('Error finding client by loginId: $e');
      // If the cloud function is not deployed or has a type error, we catch it here.
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

        return ClientModel(
          id: clientData['id'] ?? '',
          patientId: patientId,
          mobile: mobile,
          loginId: mobile,
          hasPasswordSet: false,
          status: clientData['status'] ?? 'Inactive',
          isArchived: clientData['isArchived'] ?? false,
          isSoftDeleted: clientData['isSoftDeleted'] ?? false,
          name: clientData['name'],
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

  // 🎯 FIX: Removed direct Firestore update to resolve PERMISSION_DENIED during registration
  Future<void> registerClientCredentials(String clientId, String mobileNumber, String password) async {
    // 🎯 Delegate all client document updates to the Admin Cloud Function
    await _callAdminSetPasswordFunction(
      clientId: clientId,
      mobileNumber: mobileNumber,
      password: password,
      // Send the fields that need updating to the Cloud Function
      updateData: {'hasPasswordSet': true, 'status': 'Active'},
    );
  }

  Future<User?> clientSignIn(String loginId, String password) async {
    final ClientModel? client = await getClientByLoginId(loginId); // Uses the secure Cloud Function call
    if (client == null) throw Exception('Invalid Login ID or account inactive.');
    if (!client.hasPasswordSet || client.status != 'Active') throw Exception('Account not fully active or registered.');

    final authEmail = '${client.mobile}@nutricarewellness.in'; // Internal Firebase Auth email

    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception("Invalid ID or Password.");
      }
      _logger.e("Firebase Auth Error: ${e.message}");
      throw Exception("Login Failed: ${e.message}");
    }
  }

  Future<void> clientForgotPassword(String loginId) async {
    final ClientModel? client = await getClientByLoginId(loginId); // Uses the secure Cloud Function call
    if (client == null) return;

    final authEmail = '${client.id}@nutricarewellness.in';

    try {
      await _auth.sendPasswordResetEmail(email: authEmail);
    } on FirebaseAuthException catch (e) {
      _logger.e("Firebase Auth Error: ${e.message}");
      throw Exception("Failed to send reset email: ${e.message}");
    }
  }

  // 🎯 MODIFIED: Now accepts a map of data to update on the Firestore document
  Future<void> _callAdminSetPasswordFunction({
    required String clientId,
    required String mobileNumber,
    required String password,
    Map<String, dynamic> updateData = const {}, // NEW PARAMETER: Data to update in Firestore
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('adminSetClientPassword');
    try {
      await callable.call<dynamic>({
        'clientId': clientId,
        'mobileNumber': mobileNumber,
        'password': password,
        'updateData': updateData, // Pass the document update to the Admin SDK
      });
    } on FirebaseFunctionsException catch (e) {
      _logger.e('Firebase Function Error (adminSetClientPassword): ${e.code} - ${e.message}');
      throw Exception('Failed to set password securely. Error: ${e.message}');
    }
  }

  // NOTE: uploadFile and the rest of the file were not directly affected by the fix but are included for completeness.

  Future<void> initiateClientOtpVerification({
    required String mobileNumber,
    required Function(String verificationId) codeSentCallback,
    required Function(String error) verificationFailedCallback,
  }) async {

    if (RegExp(r'^[0-9]+$').hasMatch(mobileNumber) && mobileNumber.length >= 10) {
      mobileNumber = '+91$mobileNumber';
    }
    // NOTE: mobileNumber is assumed to be in E.164 format (+CountryCode)
    if (!mobileNumber.startsWith('+')) {
      verificationFailedCallback('Mobile number must include country code (e.g., +91).');
      return;
    }

    // 🎯 Note: The actual OTP bypass logic is now fully managed in client_auth_screen.dart
    // This function only handles the real Firebase OTP flow if the screen doesn't bypass it.

    await _auth.verifyPhoneNumber(
      phoneNumber: mobileNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // We generally skip this in the multi-step flow
      },
      verificationFailed: (FirebaseAuthException e) {
        _logger.e('Client OTP verification failed: ${e.message}');
        verificationFailedCallback(e.message ?? 'Verification failed.');
      },
      codeSent: (String verificationId, int? resendToken) {
        _logger.i('OTP code sent successfully to $mobileNumber for existing client.');
        codeSentCallback(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _logger.w('Code auto-retrieval timeout.');
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // --- NEW: OTP VERIFICATION ---

  /// Verifies the OTP code for an existing client registration flow.
  /// NOTE: This only verifies the phone number, it does NOT create/update the Auth user.
  Future<PhoneAuthCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }


  /// Generates OTP and sends it via PUSH (preferred) or returns 'SMS_REQUIRED'.
  /// Returns the verificationId/session ID on success.
  Future<String> generateAndSendOtp({
    required String mobileNumber,
  }) async {
    // 1. Get the current FCM token
    final fcmToken = await _firebaseMessaging.getToken();

    // 2. Call Cloud Function to handle generation and PUSH delivery
    final HttpsCallable callable = _functions.httpsCallable('generateAndSendOtp');

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'mobileNumber': mobileNumber,
        'fcmToken': fcmToken, // Send token only if available
      });

      final status = result.data?['status'] as String?;
      final verificationId = result.data?['verificationId'] as String?;

      if (status == 'SENT_VIA_PUSH' && verificationId != null) {
        // PUSH Notification successfully sent
        return verificationId;
      }

      // Fallback: Function determined SMS was necessary or PUSH failed
      return 'SMS_REQUIRED';

    } on FirebaseFunctionsException catch (e) {
      _logger.e('OTP generation CF error: ${e.code} - ${e.message}');
      // If the function fails completely, assume SMS is necessary.
      return 'SMS_REQUIRED';
    }
  }


  Future<void> initiateMobileOtpRegistration({
    required String mobileNumber,
    required Function(String verificationId) codeSentCallback,
    required Function(String error) verificationFailedCallback,
  }) async {
    // 🎯 NOTE: This method now ONLY handles the native Firebase SMS flow.

    // Auto-prepend +91 if needed (logic repeated for safety in this fallback method)
    if (RegExp(r'^[0-9]+$').hasMatch(mobileNumber) && mobileNumber.length >= 10) {
      mobileNumber = '+91$mobileNumber';
    }
    if (!mobileNumber.startsWith('+')) {
      verificationFailedCallback('Mobile number must include country code (e.g., +91).');
      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: mobileNumber,
      verificationCompleted: (PhoneAuthCredential credential) async { /* ... */ },
      verificationFailed: (FirebaseAuthException e) {
        _logger.e('Phone verification failed: ${e.message}');
        verificationFailedCallback(e.message ?? 'Verification failed.');
      },
      codeSent: (String verificationId, int? resendToken) {
        _logger.i('OTP code sent successfully to $mobileNumber');
        codeSentCallback(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) { /* ... */ },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<Uint8List?> _compressImage(Uint8List originalBytes, {int maxSizeBytes = 20 * 1024}) async {
    int quality = 90;
    Uint8List? compressedBytes = originalBytes;

    // Binary search approach to find optimal quality quickly
    int low = 0;
    int high = 100;
    int attempts = 0;
    const maxAttempts = 10; // Safety break

    // First, check if original image is already small enough
    if (originalBytes.length <= maxSizeBytes) {
      return originalBytes;
    }

    // Attempt to compress until size target is met or we run out of attempts
    while (low <= high && attempts < maxAttempts) {
      quality = low + (high - low) ~/ 2;

      // Perform compression
      compressedBytes = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1000, // Maintain a decent width/resolution
        quality: quality,
      );

      if (compressedBytes.length > maxSizeBytes) {
        high = quality - 1; // Size too large, reduce quality
      } else {
        low = quality + 1; // Size okay, try slightly higher quality
      }
      attempts++;

      // If the low boundary is above 90, we can break and assume it's the best quality we can get
      if (low > 90) break;
    }

    // Final check to ensure we return a small file, even if quality is low
    // We use the last successfully compressed bytes
    return compressedBytes!.length < maxSizeBytes ? compressedBytes : null;
  }

  /// Creates a new ClientLog record, handling optional image upload.




  Future<void> reviewAndCommentOnLog({
    required String logId,
    required String clientId, // Required for collection path
    required String comment,
    required String reviewerUid, // UID of the dietitian
  }) async {
    final logRef = _clientLogCollection.doc(logId);

    await logRef.update({
      'adminComment': comment,
      'adminReplied': true,
      'logStatus': LogStatus.reviewed.name,
      'reviewerUid': reviewerUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 🎯 Note: The original _uploadFile helper must be modified to accept XFile
  Future<String?> _uploadFile(XFile? file, String path) async {
    if (file == null) return null;

    try {
      final fileBytes = await file.readAsBytes();
      final fileName = file.name;
      final mimeType = _getMimeType(fileName.split('.').last);

      final storageRef = _storage.ref().child('$path/$fileName');

      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: mimeType),
      );

      await uploadTask.whenComplete(() {});
      final downloadUrl = await storageRef.getDownloadURL();

      _logger.i('File uploaded successfully: $downloadUrl');
      return downloadUrl;

    } on FirebaseException catch (e) {
      _logger.e('Firebase Storage Error during upload: ${e.code} - ${e.message}');
      return null;
    }
  }
  /// Uploads a list of files and returns a list of download URLs.
  Future<List<String>> uploadFiles(List<XFile> files, String baseUploadPath) async {
    final List<Future<String?>> uploadFutures = [];

    for (var file in files) {
      // Create a unique path for each image
      final filePath = '$baseUploadPath/${file.name}';
      // Note: _uploadFile needs modification to accept XFile and handle compression
      uploadFutures.add(_uploadFileAndCompress(file, filePath));
    }

    // Wait for all uploads to complete and filter out any failed uploads (nulls)
    final results = await Future.wait(uploadFutures);
    return results.whereType<String>().toList();
  }

  /// Creates a new ClientLog record, handling multiple image uploads.
  Future<ClientLogModel> createLogEntry({
    required ClientLogModel log,
    required List<XFile> mealPhotoFiles, // 🎯 CRITICAL CHANGE 5: Expect a list of files
  }) async {
    List<String> photoUrls = [];

    // 1. Upload Photos if provided
    if (mealPhotoFiles.isNotEmpty) {
      photoUrls = await uploadFiles(
          mealPhotoFiles,
          'client_logs/${log.clientId}/${log.id}'
      );
    }

    // 2. Create the final log model with the URLs
    final logToSave = log.copyWith(mealPhotoUrls: photoUrls);

    // 3. Save to Firestore
    final docRef = await _clientLogCollection.add(logToSave.toMap());

    // 4. Return the complete, saved log model
    return ClientLogModel.fromJson({...logToSave.toMap(), 'id': docRef.id});
  }

  // NOTE: You must update the existing _uploadFile helper to accept XFile and handle compression
  Future<String?> _uploadFileAndCompress(XFile file, String path) async {
    // ... (The compression and single file upload logic from previous steps) ...
    // Placeholder implementation:
    return Future.value("mock_url/${file.name}"); // Replace with your real compression/upload logic
  }

  Future<void> createOrUpdateLog({
    required ClientLogModel log,
    required List<XFile> mealPhotoFiles,
  }) async {
    final isUpdate = log.id.isNotEmpty;
    List<String> photoUrls = log.mealPhotoUrls;

    // 1. Upload Photos if provided
    if (mealPhotoFiles.isNotEmpty) {
      // Assuming _uploadFiles is implemented to handle compression/storage
      photoUrls = await uploadFiles(
          mealPhotoFiles,
          'client_logs/${log.clientId}/${log.id.isNotEmpty ? log.id : 'new'}' // Path based on client ID and log ID
      );
    }

    // 2. Create the final log model with the URL
    final logToSave = log.copyWith(mealPhotoUrls: photoUrls);

    // 3. Save to Firestore (Admin SDK NOT required here, as it's client's own data)
    if (isUpdate) {
      // Update existing document
      await _clientLogCollection.doc(log.id).update(logToSave.toMap());
    } else {
      // Create new document
      await _clientLogCollection.add(logToSave.toMap());
    }
  }
  Future<ClientModel?> getClientById(String clientId) async {
    _logger.i('Fetching client record for ID: $clientId');
    try {
      final doc = await _clientCollection.doc(clientId).get();

      if (!doc.exists) {
        // Return null instead of throwing an exception for the provider handling
        return null;
      }

      // Assuming ClientModel.fromFirestore is defined in client_model.dart
      return ClientModel.fromFirestore(doc);

    } catch (e, stack) {
      _logger.e('Error fetching client by ID: ${e.toString()}', error: e, stackTrace: stack);
      // Return null on failure
      return null;
    }
  }
}