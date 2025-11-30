// lib/services/vitals_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';
// Ensure this models exists

// Assuming you have a logger instance initialized globally or in your services file
final Logger _logger = Logger(/* ... */);

class VitalsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _getVitalsCollection() {
    // Stores vitals in clients/{clientId}/vitals
    // return _firestore.collection('clients').doc(clientId).collection('vitals');
    return _firestore.collection('clientVitals');
  }

  // --- CREATE/ADD NEW VITALS RECORD ---

  Future<void> addVitals(VitalsModel vitals) async {
    _logger.i('Adding new vitals record for client: ${vitals.clientId}');
    try {
      await _getVitalsCollection().add(vitals.toMap());
    } catch (e, stack) {
      _logger.e(
        'Error adding vitals: ${e.toString()}',
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to add vitals record.');
    }
  }

  // --- READ/RETRIEVAL: GET ALL VITALS FOR HISTORY ---

  Future<List<VitalsModel>> getClientVitals(String clientId) async {
    try {
      final snapshot = await _getVitalsCollection()
          .where('clientId', isEqualTo: clientId)
          .orderBy('date', descending: true) // Sort by most recent first
          .get();

      return snapshot.docs
          .map((doc) => VitalsModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Error fetching vitals: ${e.toString()}');
      return [];
    }
  }

  // await _clientCollection.where('assignedDietPlanIds', isEqualTo: mobile).limit(1).get();
  Future<List<VitalsModel>> getClientMappedVitals(String clientId,
      String planId,) async {
    try {
      final snapshot = await _getVitalsCollection()
          .where('assignedDietPlanIds', arrayContains: planId)
          .orderBy('date', descending: true) // Sort by most recent first
          .get();

      return snapshot.docs
          .map((doc) => VitalsModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Error fetching vitals: ${e.toString()}');
      return [];
    }
  }

  // --- UPDATE EXISTING VITALS RECORD ---

  Future<void> updateVitals(VitalsModel vitals) async {
    if (vitals.id.isEmpty) {
      throw Exception('Vitals ID is required for update.');
    }
    _logger.i(
      'Updating vitals record ${vitals.id} for client: ${vitals.clientId}',
    );
    try {
      await _getVitalsCollection(
      ).doc(vitals.id).update(vitals.toMap());
    } catch (e, stack) {
      _logger.e(
        'Error updating vitals: ${e.toString()}',
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to update vitals record.');
    }
  }

  // --- DELETE VITALS RECORD ---

  Future<void> deleteVitals(String clientId, String recordId) async {
    _logger.i('Deleting vitals record $recordId for client: $clientId');
    try {
      await _getVitalsCollection().doc(recordId).delete();
    } catch (e, stack) {
      _logger.e(
        'Error deleting vitals: ${e.toString()}',
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to delete vitals record.');
    }
  }

  Future<void> updateAssignedDietPlans(String clientId,
      String id,
      List<String> finalAssignedIds,) async {
    try {
      await _getVitalsCollection(
      ).doc(id).update({'assignedDietPlanIds': finalAssignedIds});
    } catch (e, stack) {
      _logger.e(
        'Error updating vitals: ${e.toString()}',
        error: e,
        stackTrace: stack,
      );
      throw Exception('Failed to update vitals record.');
    }
  }


// --- GET VITALS FOR SPECIFIC DATE ---
  Future<VitalsModel?> getDailyVitals(String clientId, DateTime date) async {
    try {
      // Create a range for the whole day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _getVitalsCollection()
          .where('clientId', isEqualTo: clientId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return VitalsModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      _logger.e('Error fetching daily vitals: $e');
      return null;
    }
  }
  // 🎯 NEW: SAVE METHOD
  Future<void> saveVitals(VitalsModel vital) async {
    try {
      // If ID exists, update. If empty, create new.
      if (vital.id.isNotEmpty) {
        await _getVitalsCollection(
        )
            .doc(vital.id)
            .set(vital.toMap(), SetOptions(merge: true));
      } else {
       await _getVitalsCollection(
        ).add(vital.toMap());
      }
    } catch (e) {
      throw Exception("Failed to save vitals: $e");
    }
  }

}
