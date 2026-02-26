// lib/features/dietplan/dATA/services/vitals_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';

final Logger _logger = Logger();

final vitalsServiceProvider = Provider<VitalsService>((ref) {
  // Watch the current client from your AuthNotifier
  final currentClient = ref.watch(currentClientProvider);

  // Extract their tenantId (fallback to empty string if not logged in)
  final tenantId = currentClient?.tenantId ?? '';

  // Return the configured service
  return VitalsService(tenantId: tenantId);
});

class VitalsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🎯 1. Hold the tenantId at the class level
  final String tenantId;

  // 🎯 2. Require it when the service is created
  VitalsService({required this.tenantId});

  CollectionReference _getVitalsCollection() {
    // 🎯 Use the new collection name
    return _firestore.collection('patient_vitals');
  }

  // --- CREATE/ADD NEW VITALS RECORD ---
  Future<void> addVitals(VitalsModel vitals) async {
    _logger.i('Adding vitals for client: ${vitals.clientId}');
    try {
      final data = vitals.toMap();
      data['tenantId'] = tenantId; // 🎯 Automatically applied

      await _getVitalsCollection().add(data);
    } catch (e, stack) {
      _logger.e('Error adding vitals: $e', error: e, stackTrace: stack);
      throw Exception('Failed to add vitals record.');
    }
  }

  // --- READ/RETRIEVAL: GET ALL VITALS FOR HISTORY ---
  Future<List<VitalsModel>> getClientVitals(String clientId) async {
    try {
      final snapshot = await _getVitalsCollection()
          .where('tenantId', isEqualTo: tenantId) // 🎯 Strictly filter by tenant
          .where('clientId', isEqualTo: clientId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) => VitalsModel.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error fetching vitals: $e');
      return [];
    }
  }

  Future<List<VitalsModel>> getClientMappedVitals(String clientId, String planId) async {
    try {
      final snapshot = await _getVitalsCollection()
          .where('tenantId', isEqualTo: tenantId) // 🎯 Strictly filter by tenant
          .where('assignedDietPlanIds', arrayContains: planId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) => VitalsModel.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error fetching vitals: $e');
      return [];
    }
  }

  // --- UPDATE EXISTING VITALS RECORD ---
  Future<void> updateVitals(VitalsModel vitals) async {
    if (vitals.id.isEmpty) {
      throw Exception('Vitals ID is required for update.');
    }
    _logger.i('Updating vitals record ${vitals.id} for client: ${vitals.clientId}');

    try {
      final docRef = _getVitalsCollection().doc(vitals.id);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        throw Exception('Vitals record not found.');
      }

      // 🎯 Strict read-before-write check
      final docData = docSnap.data() as Map<String, dynamic>;
      if (docData['tenantId'] != tenantId) {
        throw Exception('Unauthorized: tenantId mismatch.');
      }

      final data = vitals.toMap();
      data['tenantId'] = tenantId; // Enforce tenant presence in update

      await docRef.update(data);
    } catch (e, stack) {
      _logger.e('Error updating vitals: $e', error: e, stackTrace: stack);
      throw Exception('Failed to update vitals record.');
    }
  }

  // --- DELETE VITALS RECORD ---
  Future<void> deleteVitals(String recordId) async {
    _logger.i('Deleting vitals record $recordId');
    try {
      final docRef = _getVitalsCollection().doc(recordId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        throw Exception('Vitals record not found.');
      }

      // 🎯 Strict read-before-delete check
      final docData = docSnap.data() as Map<String, dynamic>;
      if (docData['tenantId'] != tenantId) {
        throw Exception('Unauthorized: tenantId mismatch.');
      }

      await docRef.delete();
    } catch (e, stack) {
      _logger.e('Error deleting vitals: $e', error: e, stackTrace: stack);
      throw Exception('Failed to delete vitals record.');
    }
  }

  // --- UPDATE ASSIGNED DIET PLANS ---
  Future<void> updateAssignedDietPlans(String id, List<String> finalAssignedIds) async {
    try {
      final docRef = _getVitalsCollection().doc(id);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        throw Exception('Vitals record not found.');
      }

      // 🎯 Strict read-before-write check
      final docData = docSnap.data() as Map<String, dynamic>;
      if (docData['tenantId'] != tenantId) {
        throw Exception('Unauthorized: tenantId mismatch.');
      }

      await docRef.update({'assignedDietPlanIds': finalAssignedIds});
    } catch (e, stack) {
      _logger.e('Error updating vitals: $e', error: e, stackTrace: stack);
      throw Exception('Failed to update vitals record.');
    }
  }

  // --- GET VITALS FOR SPECIFIC DATE ---
  Future<VitalsModel?> getDailyVitals(String clientId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _getVitalsCollection()
          .where('tenantId', isEqualTo: tenantId) // 🎯 Strictly filter by tenant
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

  // --- 🎯 SMART SAVE METHOD (CREATE OR UPDATE) ---
  Future<void> saveVitals(VitalsModel vital) async {
    try {
      final data = vital.toMap();
      data['tenantId'] = tenantId; // 🎯 Strictly enforce tenantId

      if (vital.id.isNotEmpty) {
        final docRef = _getVitalsCollection().doc(vital.id);
        final docSnap = await docRef.get();

        // 🎯 Strict verification if the document exists before merging
        if (docSnap.exists) {
          final docData = docSnap.data() as Map<String, dynamic>;
          if (docData['tenantId'] != tenantId) {
            throw Exception('Unauthorized: tenantId mismatch on save.');
          }
        }

        await docRef.set(data, SetOptions(merge: true));
      } else {
        await _getVitalsCollection().add(data);
      }
    } catch (e) {
      throw Exception("Failed to save vitals: $e");
    }
  }
}