import 'package:cloud_firestore/cloud_firestore.dart';

import 'diagonosis_master.dart';

// 🎯 NOTE: Adjust import path for your DiagnosisMasterModel

class DiagnosisMasterService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionName = 'diagnoses';
  final CollectionReference _collection =
  FirebaseFirestore.instance.collection("diagnoses");

  /// Fetches a stream of all non-deleted diagnoses.
  Stream<List<DiagnosisMasterModel>> getDiagnoses() {
    return _db
        .collection(_collectionName)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => DiagnosisMasterModel.fromFirestore(doc))
        .toList());
  }

  /// Adds a new diagnosis or updates an existing one.
  Future<void> addOrUpdateDiagnosis(DiagnosisMasterModel diagnosis) async {
    final docRef = _db.collection(_collectionName).doc(diagnosis.id.isEmpty ? null : diagnosis.id);
    await docRef.set(
      diagnosis.toMap(),
      SetOptions(merge: true), // Use merge to only update fields present
    );
  }

  /// Soft deletes a diagnosis (sets isDeleted to true).
  Future<void> softDeleteDiagnosis(String diagnosisId) async {
    await _db.collection(_collectionName).doc(diagnosisId).update({
      'isDeleted': true,
    });
  }


    Future<List<DiagnosisMasterModel>> fetchAllDiagnosisMaster() async {
      try {
        QuerySnapshot<Object?> snapshot = await _collection
            .where('isDeleted', isEqualTo: false)
            .get(); // 🎯 Key change: .get() instead of .snapshots()

        // 2. Map the QuerySnapshot documents to a List<FoodItem>
        return snapshot.docs
            .map((doc) => DiagnosisMasterModel.fromFirestore(doc))
            .toList();
      } catch (e) {
        // Handle errors (e.g., logging, throwing a more specific exception)
        print('Error fetching diagnoses from Firebase: $e');
        // Return an empty list on failure to prevent the app from crashing
        return [];
      }
    }


  Future<List<DiagnosisMasterModel>> fetchAllDiagnosisMasterByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Firestore 'whereIn' limitation: max 10 IDs. You may need to batch this.
    // For simplicity, assuming less than 10 for now.
    final snapshot = await _collection
        .where(FieldPath.documentId, whereIn: ids.take(10).toList())
        .get();

    return snapshot.docs.map((doc) => DiagnosisMasterModel.fromFirestore(doc)).toList();
  }
}

