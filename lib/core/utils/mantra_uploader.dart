import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_shift/core/utils/spiritual_mantra_model.dart';

import 'mantra_data.dart' show masterMantraList;

class MantraUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadMantras() async {
    final collection = _firestore.collection('mantra_library');
    int added = 0;

    print("🚀 Starting Mantra Upload...");

    for (SpiritualMantraModel m in masterMantraList) {
      final docRef = collection.doc(m.id);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        await docRef.set(m.toMap());
        print("✅ Added: ${m.name}");
        added++;
      } else {
        // Optional: Update if you want to sync changes from code
        // await docRef.update(m.toMap());
      }
    }
    print("🎉 Upload Complete! Added: $added");
  }
}