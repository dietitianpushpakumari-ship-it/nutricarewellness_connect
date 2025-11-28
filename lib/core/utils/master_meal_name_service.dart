// lib/services/master_meal_name_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import 'meal_master_name.dart';


/// Service class for managing MasterMealName data in Firestore.
class MasterMealNameService {
  final CollectionReference _collection =
  FirebaseFirestore.instance.collection('masterMealNames');

  // --- READ ---
  /// Provides a stream of all *active* meal names, ordered by English name.
  Stream<List<MasterMealName>> streamAllActive() {
    return _collection
        .where('isDeleted', isEqualTo: false)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => MasterMealName.fromFirestore(doc))
        .toList());
  }

  // --- CREATE & UPDATE ---
  Future<void> save(MasterMealName mealName) async {
    final Map<String, dynamic> data = mealName.toMap();

    if (mealName.id.isEmpty) {
      // Create: Add a new document
      await _collection.add(data);
    } else {
      // Update: Update existing document
      await _collection.doc(mealName.id).update(data);
    }
  }

  // --- DELETE (Soft Delete) ---
  Future<void> softDelete(String id) async {
    await _collection.doc(id).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }


  Future<List<MasterMealName>> fetchAllMealNames() async {
    try {
      QuerySnapshot<Object?> snapshot = await _collection
          .where('isDeleted', isEqualTo: false)
          .orderBy('order')
          .get(); // 🎯 Key change: .get() instead of .snapshots()

      // 2. Map the QuerySnapshot documents to a List<FoodItem>
      return snapshot.docs
          .map((doc) => MasterMealName.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Handle errors (e.g., logging, throwing a more specific exception)
      print('Error fetching food items from Firebase: $e');
      // Return an empty list on failure to prevent the app from crashing
      return [];
    }
  }
}