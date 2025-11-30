import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/clinical_model.dart'; // Ensure this model exists

class ClinicalMasterService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection Names
  static const String colComplaints = 'master_complaints';
  static const String colAllergies = 'master_allergies';
  static const String colMedicines = 'master_medicines';
  static const String colClinicalNotes = 'master_clinical_notes';
  static const String colInstructions = 'master_instructions';

  CollectionReference _getCollection(String name) => _db.collection(name);

  // 1. Stream Active Items (Full Models)
  Stream<List<ClinicalItemModel>> streamActiveItems(String collectionName) {
    return _getCollection(collectionName)
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ClinicalItemModel.fromFirestore(doc)).toList());
  }

  // 2. Stream Strings (For Autocomplete)
  Stream<List<String>> streamItemNames(String collectionName) {
    return streamActiveItems(collectionName).map((list) => list.map((e) => e.name).toList());
  }

  // 3. Add New Item (Client might add custom meds)
  Future<void> addItem(String collectionName, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final duplicateCheck = await _getCollection(collectionName)
        .where('name', isEqualTo: trimmedName)
        .limit(1)
        .get();

    if (duplicateCheck.docs.isNotEmpty) return;

    await _getCollection(collectionName).add({
      'name': trimmedName,
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 4. Save/Update
  Future<void> saveItem(String collectionName, ClinicalItemModel item) async {
    if (item.id.isEmpty) {
      await addItem(collectionName, item.name);
    } else {
      await _getCollection(collectionName).doc(item.id).update({
        'name': item.name,
        'updatedAt': FieldValue.serverTimestamp()
      });
    }
  }

  Future<void> deleteItem(String collectionName, String id) async {
    await _getCollection(collectionName).doc(id).update({'isDeleted': true});
  }
}