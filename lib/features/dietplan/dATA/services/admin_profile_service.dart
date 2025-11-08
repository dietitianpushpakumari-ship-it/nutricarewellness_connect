import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';


// 🎯 STUB: Assuming this structure from your admin_profile_model.dart import
enum UserRole { superAdmin, admin }

class AdminProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'admins';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- READ Operation (Stream) ---
  /// Streams the profile data for a specific admin UID.
  Stream<AdminProfileModel> streamAdminProfile(String adminUid) {
    return _firestore
        .collection(_collection)
        .doc(adminUid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        // Handle case where profile doc doesn't exist yet
        throw Exception("Admin profile not found for UID: $adminUid");
      }
      return AdminProfileModel.fromFirestore(snapshot);
    });
  }

  // --- UPDATE Operation ---
  Future<AdminProfileModel> fetchAdminProfile() async {
    try {

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: 'superAdmin')
      // Sort by start time for consistent display (most recent first)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return AdminProfileModel.fromFirestore(querySnapshot.docs.first);
      } else {
        throw Exception('No active package found.');
        //return null;
      }

    } on FirebaseException catch (e) {
      throw Exception('Firebase Error fetching meetings: ${e.code} - ${e.message}');
      throw Exception('Failed to load meetings: ${e.message}');
    } catch (e) {

      throw Exception('An unexpected error occurred while loading meetings.');
    }
  }
}