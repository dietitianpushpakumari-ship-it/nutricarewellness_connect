// lib/services/guideline_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/programme_feature_model.dart';


/// Service class for managing Guideline master data in Firestore.
class PackageService {
  final CollectionReference _packageCollection = FirebaseFirestore.instance.collection('packages');
  final CollectionReference _clientCollection = FirebaseFirestore.instance.collection('clients');
  CollectionReference clientAssignmentCollection(String clientId) {
    // 🎯 FIX: Drill down from the existing _clientCollection reference.
    // This correctly returns a CollectionReference, resolving the type mismatch error
    // that the compiler was seeing.
    return _clientCollection
        .doc(clientId)
        .collection('packageAssignments');
  }
  final CollectionReference _featureCollection =
  FirebaseFirestore.instance.collection('programFeatures');

  // Stream all features for the master list
  Future<List<ProgramFeatureModel>> getFeaturesByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];

      final snapshot = await _featureCollection
          .where(FieldPath.documentId, whereIn: ids) // ✅ filter by IDs
          .orderBy('name') // optional, only if you want sorted result
          .get(); // ✅ one-time fetch

      return snapshot.docs
          .map((doc) => ProgramFeatureModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to load features: $e');
    }
  }

  Future<List<PackageAssignmentModel>> getPackageAssignments(String clientId)  async{
    // 1. Get the CollectionReference for the subcollection.
    final assignmentRef = clientAssignmentCollection(clientId);

    try {
      final snapshot = await assignmentRef
          .orderBy('purchaseDate', descending: true)
          .get(); // ✅ get() returns a Future, not a Stream

      return snapshot.docs
          .map((doc) => PackageAssignmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to load assignments: $e');
    }

  }
  Future<PackageModel> getAllActivePackagesById(String packageId) async {
    //_logger.i('Fetching client record for ID: $clientId');
    try {
      final doc = await _clientCollection.doc(packageId).get();

      if (!doc.exists) {
        throw Exception('Client with ID $packageId not found.');
      }

      return PackageModel.fromFirestore(doc);
    } catch (e, stack) {
    //  _logger.e('Error fetching client by ID: ${e.toString()}', error: e, stackTrace: stack);
      // Re-throw the original exception or a service-specific one
      rethrow;
    }
  }

}