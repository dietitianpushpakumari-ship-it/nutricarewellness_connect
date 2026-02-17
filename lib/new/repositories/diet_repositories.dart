import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/new/models/consultation_session_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
// Ensure this model exists in your project. If not, create it (code provided below).

class DietRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // 🎯 1. RELATIONAL FETCHING (Session -> Plan & Vitals)
  // ---------------------------------------------------------------------------

  /// Fetches the latest consultation session for a specific client and tenant.
  Future<ConsultationSessionModel?> getLatestSession(String clientId, String tenantId) async {
    try {
      final query = await _db.collection('patient_consultation_sessions')
          .where('clientId', isEqualTo: clientId)
          .where('tenantId', isEqualTo: tenantId) // 白 Strict Tenant Check
          .orderBy('sessionDate', descending: true) // Get newest first
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return ConsultationSessionModel.fromFirestore(query.docs.first);
    } catch (e) {
      print("Error fetching latest session: $e");
      return null;
    }
  }
  Future<ClientDietPlanModel?> getActivePlan(String clientId, String tenantId) async {
    try {
      final query = await _db.collection('patient_mealPlan')
          .where('clientId', isEqualTo: clientId)
          .where('tenantId', isEqualTo: tenantId)
          .where('isActive', isEqualTo: true) // Direct Active Check
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return ClientDietPlanModel.fromFirestore(query.docs.first);
    } catch (e) {
      print("Error fetching active plan fallback: $e");
      return null;
    }
  }

  // 識 NEW: Fallback - Fetch Latest Vitals directly
  Future<VitalsModel?> getLatestVitals(String clientId) async {
    try {
      final query = await _db.collection('patient_vitals')
          .where('clientId', isEqualTo: clientId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return VitalsModel.fromFirestore(query.docs.first);
    } catch (e) {
      print("Error fetching vitals fallback: $e");
      return null;
    }
  }
  /// Fetches the Diet Plan by ID (linked from session)
  Future<ClientDietPlanModel?> getPlanById(String planId) async {
    try {
      final doc = await _db.collection('patient_mealPlan').doc(planId).get();
      if (!doc.exists) return null;
      return ClientDietPlanModel.fromFirestore(doc);
    } catch (e) {
      print("Error fetching plan $planId: $e");
      return null;
    }
  }

  /// Fetches Vitals/Clinical Data by ID (linked from session)
  Future<VitalsModel?> getVitalsById(String vitalsId) async {
    try {
      final doc = await _db.collection('patient_vitals').doc(vitalsId).get();
      if (!doc.exists) return null;
      return VitalsModel.fromFirestore(doc);
    } catch (e) {
      print("Error fetching vitals $vitalsId: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 🎯 2. LOGGING LOGIC (Client Scoped)
  // ---------------------------------------------------------------------------

  /// Fetches logs for a specific date (used by Daily View)
  Future<List<ClientLogModel>> getLogsForDate(String clientId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final snapshot = await _db
          .collection('clients')
          .doc(clientId)
          .collection('logs')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .get();

      return snapshot.docs
          .map((doc) => ClientLogModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("Error fetching logs for date: $e");
      return [];
    }
  }

  /// 🎯 FIXED: This was missing! Fetches ALL logs for history/trends.
  Future<List<ClientLogModel>> fetchAllClientLogs(String clientId) async {
    try {
      final snapshot = await _db
          .collection('clients')
          .doc(clientId)
          .collection('logs')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ClientLogModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("Error fetching all logs: $e");
      return [];
    }
  }

  /// Creates or Updates a Log entry
  Future<ClientLogModel> createOrUpdateLog(ClientLogModel log) async {
    try {
      final collectionRef = _db.collection('clients').doc(log.clientId).collection('logs');

      // If ID exists, update; otherwise, create new
      final docRef = log.id.isNotEmpty
          ? collectionRef.doc(log.id)
          : collectionRef.doc(); // Auto-ID

      final logWithId = log.copyWith(id: docRef.id);

      // Use set with merge to be safe
      await docRef.set(logWithId.toMap(), SetOptions(merge: true));

      return logWithId;
    } catch (e) {
      throw Exception("Failed to save log: $e");
    }
  }
}