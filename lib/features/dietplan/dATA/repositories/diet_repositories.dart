import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import '../../domain/entities/client_log_model.dart';

class DietRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DietRepository();

  // --- 1. HELPER: Generate Consistent Document ID ---
  // Format: "2024-10-25_BREAKFAST"
  // This prevents duplicates and makes querying by ID super fast.
  String _generateLogId(String clientId, DateTime date, String mealName) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    // Sanitize meal name (remove spaces/special chars)
    final safeMealName = mealName.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '_');
    return "${dateStr}_$safeMealName";
  }

  // --- 2. Fetch Active Plan (Unchanged) ---
  Future<ClientDietPlanModel> getActivePlan(String clientId) async {
    try {
      final snapshot = await _db.collection('clientDietPlans')
          .where('clientId', isEqualTo: clientId)
          .where('isDeleted', isEqualTo: false)
          .where('isArchived', isEqualTo: false)
          .orderBy('assignedDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('No active diet plan found for client $clientId');
      }
      return ClientDietPlanModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to fetch active plan: $e');
    }
  }

  // --- 3. FETCH LOGS (From Sub-Collection) ---
  Future<List<ClientLogModel>> getLogsForDate(String clientId, DateTime date) async {
    // We want logs for a specific day.
    // Since we now store them in a sub-collection, we query by date range
    // to be safe, or we could just get all docs for that day if we used a day-based collection structure.
    // But keeping it flat in 'logs' subcollection is better for querying history later.

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      // 🎯 NEW PATH: clients/{id}/logs
      final snapshot = await _db
          .collection('clients')
          .doc(clientId)
          .collection('logs')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .get();

      return snapshot.docs.map((doc) =>
          ClientLogModel.fromMap(doc.data(), doc.id))
          .toList();

    } catch (e) {
      throw Exception('Failed to fetch logs: $e');
    }
  }

  // --- 4. CREATE / UPDATE LOG (Idempotent Save) ---
  // Combines createLog and updateLog into one robust method.
  Future<ClientLogModel> createOrUpdateLog(ClientLogModel log) async {
    try {
      // Generate ID
      final String docId = _generateLogId(log.clientId, log.date, log.mealName);

      final docRef = _db
          .collection('clients')
          .doc(log.clientId)
          .collection('logs')
          .doc(docId);

      // Prepare Data
      final data = log.toMap();

      // 🎯 MERGE: This is key. It creates if new, updates fields if exists.
      await docRef.set(data, SetOptions(merge: true));

      // Return model with the correct ID
      return ClientLogModel.fromMap(data, docId);
    } catch (e) {
      throw Exception('Failed to save log: $e');
    }
  }

  // --- 5. FETCH HISTORY (For Analytics/Charts) ---
  Future<List<ClientLogModel>> fetchAllClientLogs(String clientId) async {
    try {
      final snapshot = await _db
          .collection('clients')
          .doc(clientId)
          .collection('logs')
          .orderBy('date', descending: true)
          .limit(100) // Optimization: Limit to last 100 entries first
          .get();

      return snapshot.docs.map((doc) =>
          ClientLogModel.fromMap(doc.data(), doc.id)
      ).toList();

    } catch (e) {
      throw Exception('Failed to fetch client log history: $e');
    }
  }
}