import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 🎯 CORRECT IMPORT: Use your existing model

import 'meal_master_name.dart';

final masterMealNamesProvider = StreamProvider<List<MasterMealName>>((ref) {
  return FirebaseFirestore.instance
      .collection('masterMealNames')
      .where('isDeleted', isEqualTo: false)
      .orderBy('order')
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => MasterMealName.fromFirestore(doc))
      .toList());
});