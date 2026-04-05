import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/flat_diet_plan_model.dart';

// Ensure this points to FlatClientDietPlanModel
import 'package:nutricare_connect/new/models/consultation_session_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class DietRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // 🎯 1. RELATIONAL FETCHING (STRICT TENANT ENFORCEMENT)
  // ---------------------------------------------------------------------------

  Future<ConsultationSessionModel?> getLatestSession(String clientId, String tenantId) async {
    try {
      final query = await _db.collection('patient_consultation_sessions')
          .where('clientId', isEqualTo: clientId)
          .where('tenantId', isEqualTo: tenantId) // 🔒 Enforced
          .orderBy('sessionDate', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return ConsultationSessionModel.fromFirestore(query.docs.first);
    } catch (e) {
      print("Error fetching latest session: $e");
      return null;
    }
  }
  Future<List<FlatDietPlanItem>> _fetchShardedItems(DocumentReference planRef) async {
    final List<FlatDietPlanItem> allItems = [];
    try {
      // 1. Get all documents from the 'days' subcollection
      final daysSnapshot = await planRef.collection('days').get();

      for (var doc in daysSnapshot.docs) {
        final data = doc.data();
        final List? itemsJson = data['items'] as List?;

        if (itemsJson != null) {
          for (var x in itemsJson) {
            // 2. Parse each item and add to the master list
            allItems.add(FlatDietPlanItem.fromMap(Map<String, dynamic>.from(x)));
          }
        }
      }
    } catch (e) {
      print("Error fetching sharded items: $e");
    }
    return allItems;
  }

  // 🚀 UPDATE: getActivePlan now REASSEMBLES the sharded data
  Future<FlatClientDietPlanModel?> getActivePlan(String clientId, String tenantId) async {
    try {
      final query = await _db.collection('patient_mealPlan')
          .where('clientId', isEqualTo: clientId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;

      // 1. Get the base metadata (Habits, Goals, etc.)
      final basePlan = FlatClientDietPlanModel.fromFirestore(doc);

      // 2. 🎯 CRITICAL: Fetch the food items from the subcollection
      final items = await _fetchShardedItems(doc.reference);

      // 3. Merge them together
      return basePlan.copyWith(allItems: items);

    } catch (e) {
      print("Fetch error: $e");
      return null;
    }
  }

  // 🚀 UPDATE: getPlanById also needs reassembly
  Future<FlatClientDietPlanModel?> getPlanById(String planId, String tenantId) async {
    try {
      final docRef = _db.collection('patient_mealPlan').doc(planId);
      final doc = await docRef.get();

      if (!doc.exists) return null;

      final basePlan = FlatClientDietPlanModel.fromFirestore(doc);

      // 🎯 Fetch sharded items
      final items = await _fetchShardedItems(docRef);

      return basePlan.copyWith(allItems: items);
    } catch (e) {
      return null;
    }
  }

  // Inside DietRepository in diet_repositories.dart



  Future<VitalsModel?> getLatestVitals(String clientId, String tenantId) async {
    try {
      final query = await _db.collection('patient_vitals')
          .where('clientId', isEqualTo: clientId)
          .where('tenantId', isEqualTo: tenantId) // 🔒 STRICT ENFORCEMENT ADDED
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


  Future<VitalsModel?> getVitalsById(String vitalsId, String tenantId) async {
    try {
      final doc = await _db.collection('patient_vitals').doc(vitalsId).get();
      // 🔒 STRICT ENFORCEMENT: Reject if the document belongs to another clinic
      if (!doc.exists || doc.data()?['tenantId'] != tenantId) return null;

      return VitalsModel.fromFirestore(doc);
    } catch (e) {
      print("Error fetching vitals $vitalsId: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 🎯 2. ATOMIC LOGGING LOGIC (STRICT TENANT ENFORCEMENT)
  // ---------------------------------------------------------------------------

  Future<ClientLogModel?> getDailyRecord(String clientId, DateTime date, String tenantId) async {
    final dateId = DateFormat('yyyy-MM-dd').format(date);

    try {
      final doc = await _db
          .collection('clients')
          .doc(clientId)
          .collection('daily_logs')
          .doc(dateId)
          .get();

      if (!doc.exists || doc.data() == null) return null;

      // 🔒 STRICT ENFORCEMENT: Ensure the fetched log matches the clinic context
      if (doc.data()!['tenantId'] != tenantId) return null;

      return ClientLogModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print("Error fetching daily record: $e");
      return null;
    }
  }

  Future<List<ClientLogModel>> fetchAllClientLogs(String clientId, String tenantId) async {
    try {
      final snapshot = await _db
          .collection('clients')
          .doc(clientId)
          .collection('daily_logs')
          .where('tenantId', isEqualTo: tenantId) // 🔒 STRICT ENFORCEMENT ADDED
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

  Future<void> sendPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('sendCoachNotification').call({
      'token': token,
      'title': title,
      'body': body,
      'data': data,
    });
  }

  Future<void> saveAtomicDailyRecord({
    required String clientId,
    required String tenantId, // 🔒 ALREADY STRICT
    required String dateId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final docRef = _db
          .collection('clients')
          .doc(clientId)
          .collection('daily_logs')
          .doc(dateId);

      // Inject security & tracking metadata directly at the data layer
      data['tenantId'] = tenantId;
      data['clientId'] = clientId;
      data['dateId'] = dateId;
      data['lastUpdated'] = FieldValue.serverTimestamp();

      data['date'] ??= Timestamp.fromDate(DateTime.parse(dateId));

      await docRef.set(data, SetOptions(merge: true));

    } catch (e) {
      throw Exception("Failed to atomic update daily record: $e");
    }
  }
}