// lib/features/diet_plan/data/repositories/diet_repositories.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import '../../domain/entities/client_log_model.dart'; // Assumed to be fixed

class DietRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DietRepository(); // No dependencies required

  // 1. Fetch the Active Plan (Uses the corrected fromFirestore factory)
  Future<ClientDietPlanModel> getActivePlan(String clientId) async {
    try {
      final snapshot = await _db.collection('clientDietPlans')
        //  .doc(clientId)
        //  .collection('diet_plans') // Placeholder for your plan subcollection
          .where('clientId', isEqualTo: clientId)
          .where('isDeleted', isEqualTo: false)
          .where('isArchived', isEqualTo: false)
          .orderBy('assignedDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('No active diet plan found for client $clientId');
      }

      final doc = snapshot.docs.first;

      // 🎯 FIX: Call the robust manual factory on the DocumentSnapshot
      return ClientDietPlanModel.fromFirestore(doc);

    } catch (e) {
      throw Exception('Failed to fetch active plan: $e');
    }
  }

  // 2. Fetch Daily Logs (Simplified read)
  Future<List<ClientLogModel>> getLogsForDate(String clientId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final snapshot = await _db.collection('client_logs')
          .where('clientId', isEqualTo: clientId)
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .get();

      // Assuming ClientLogModel has a correct fromMap/fromJson factory
      return snapshot.docs.map((doc) =>
          ClientLogModel.fromMap(doc.data(), doc.id)) // Use fromMap for safety
          .toList();

    } catch (e) {
      throw Exception('Failed to fetch logs: $e');
    }
  }

  // 3. Create a Log Entry (Simplified write)
  Future<ClientLogModel> createLog(ClientLogModel log) async {
    try {
      final docRef = await _db.collection('client_logs').add(log.toMap()); // Use toMap() for manual mapping

      // Return the created log with the new ID
      return ClientLogModel.fromMap({...log.toMap(), 'id': docRef.id}, docRef.id);
    } catch (e) {
      throw Exception('Failed to create log: $e');
    }
  }


  Future<List<ClientLogModel>> fetchAllClientLogs(String clientId) async {
    try {
      final snapshot = await _db.collection('client_logs')
          .where('clientId', isEqualTo: clientId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) => ClientLogModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

    } catch (e) {
      throw Exception('Failed to fetch client log history: $e');
    }
  }

  // --- 🎯 NEW: Update Log (Client Modification / Admin Review) ---

  /// Updates an existing log record. Used by client to modify details or admin to review/comment.
  Future<void> updateLog(ClientLogModel log) async {
    if (log.id.isEmpty) {
      throw Exception('Log ID is required for update.');
    }
    try {
      // 🎯 FIX: Use toMap() for data conversion
      await _db.collection('client_logs').doc(log.id).update(log.toMap());
    } catch (e) {
      throw Exception('Failed to update log: $e');
    }
  }



}