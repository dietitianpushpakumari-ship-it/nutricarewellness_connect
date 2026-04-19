import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_shift/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:pure_shift/features/dietplan/domain/entities/package_model.dart';
import 'package:pure_shift/features/dietplan/domain/entities/payment_model.dart';
import 'package:pure_shift/features/dietplan/domain/entities/programme_feature_model.dart';

/// Service class for managing Guideline/Package data in Firestore.
class PackageService {
  final CollectionReference _packageCollection = FirebaseFirestore.instance.collection('patient_subscription');
  final CollectionReference _paymentCollection = FirebaseFirestore.instance.collection('patient_payment');
  final CollectionReference _featureCollection = FirebaseFirestore.instance.collection('master_packageFeature');

  // 🐛 FIX: Added a dedicated collection reference for packages.
  // (Your original code was accidentally querying the clients collection for packages!)
  final CollectionReference _masterPackageCollection = FirebaseFirestore.instance.collection('master_package');

  // ===========================================================================
  // 🚀 1. REAL-TIME STREAMS (Using .snapshots())
  // ===========================================================================

  /// Returns a real-time stream of package assignments for a specific client & tenant
  Stream<List<PackageAssignmentModel>> streamPackageAssignments(String clientId, String tenantId) {
    print('📡 Fetching packages -> Client: "$clientId" | Tenant: "$tenantId"');

    return _packageCollection
     //   .where('clientId', isEqualTo: clientId)
      //  .where('tenantId', isEqualTo: tenantId)
      //  .orderBy('startDate', descending: true)
        .snapshots()
        .handleError((error) {
      // 🚨 IF IT'S AN INDEX ISSUE, FIRESTORE WILL SPIT A URL HERE
      print('🔥 FIRESTORE STREAM ERROR: $error');
      // If the console prints a link, CTRL+CLICK the link to auto-create the index!
    })
        .map((snapshot) {
      print('✅ Snapshot fetched successfully! Found ${snapshot.docs.length} documents.');

      return snapshot.docs.map((doc) {
        try {
          // Test the mapping
          final model = PackageAssignmentModel.fromFirestore(doc);
          return model;
        } catch (e, stack) {
          // 🚨 IF IT'S A MAPPING ISSUE, IT WILL PRINT HERE
          print('💥 MODEL MAPPING ERROR on Document ID [${doc.id}]: $e');
          rethrow;
        }
      }).toList();
    });
  }

  /// Returns a real-time stream of payments for a specific assignment
  Stream<List<PaymentModel>> streamPaymentsForAssignment(String assignmentId, String tenantId) {
    return _paymentCollection
        .where('packageAssignmentId', isEqualTo: assignmentId)
        .where('tenantId', isEqualTo: tenantId) // 🔐 Strict Multi-Tenant Check
        .orderBy('paymentDate', descending: true)
        .snapshots() // 🚀 USING SNAPSHOTS
        .map((snapshot) => snapshot.docs
        .map((doc) => PaymentModel.fromFirestore(doc))
        .toList());
  }

  // ===========================================================================
  // 📦 2. ONE-TIME FETCHES (Using .get())
  // ===========================================================================

  /// Fetches package features belonging to this tenant
  Future<List<ProgramFeatureModel>> getFeaturesByIds(List<String> ids, String tenantId) async {
    try {
      if (ids.isEmpty) return [];

      final snapshot = await _featureCollection
          .where('tenantId', isEqualTo: tenantId) // 🔐 Strict Multi-Tenant Check
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      return snapshot.docs
          .map((doc) => ProgramFeatureModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to load features: $e');
    }
  }

  /// Fetches a specific package by ID (Fixed bug where it queried clients)
  Future<PackageModel> getPackageById(String packageId, String tenantId) async {
    try {
      final doc = await _masterPackageCollection.doc(packageId).get();

      if (!doc.exists) {
        throw Exception('Package with ID $packageId not found.');
      }

      final data = doc.data() as Map<String, dynamic>;

      // 🔐 Extra Security: Ensure the package belongs to the clinic (or is a global template)
      if (data['tenantId'] != tenantId && data['isGlobal'] != true) {
        throw Exception("Unauthorized: Package belongs to a different clinic.");
      }

      return PackageModel.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }
}