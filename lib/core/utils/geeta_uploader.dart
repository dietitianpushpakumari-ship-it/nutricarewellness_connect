import 'package:cloud_firestore/cloud_firestore.dart';
import 'geeta_data.dart';
import 'geeta_shloka_model.dart';

class GeetaUploader {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadGeetaBank() async {
    final collection = _firestore.collection('geeta_library');
    int added = 0;

    print("🚀 Starting Geeta Upload...");

    for (GeetaShloka s in masterGeetaBank) {
      final docRef = collection.doc(s.id);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        await docRef.set(s.toMap());
        print("✅ Added: Chapter ${s.chapter}.${s.verse}");
        added++;
      }
    }
    print("🎉 Upload Complete! Added: $added");
  }
}