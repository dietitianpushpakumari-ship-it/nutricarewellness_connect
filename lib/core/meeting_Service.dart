import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/core/appointment_model.dart';

// 🎯 IMPORTANT: If you are using the old MeetingModel in dashboard, you might need to alias or map it.
// For now, this service uses the NEW AppointmentModel.
// You may need to update your Dashboard provider to use AppointmentModel or map it here.

// If your dashboard strictly uses 'MeetingModel', you might need to import it:
import 'package:nutricare_connect/features/dietplan/domain/entities/schedule_meeting_utils.dart'; // Check this path for MeetingModel

final Logger _logger = Logger();

class MeetingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  final String _slotsCollection = 'appointment_slots';
  final String _appointmentsCollection = 'appointments';
  final String _locksCollection = 'availability_locks';
  final String _configCollection = 'configurations';

  // 💰 Global Pricing Configuration
  static const Map<int, double> sessionPrices = {
    15: 299.0,
    30: 499.0,
    60: 899.0,
  };

  // ===========================================================================
  // 🛠️ FIX: THE MISSING METHOD (getClientMeetings)
  // ===========================================================================

  /// Fetches meetings for a client.
  /// Maps the new 'AppointmentModel' structure to the old 'MeetingModel' if needed,
  /// or returns AppointmentModel if you updated the provider.
  Future<List<MeetingModel>> getClientMeetings(String clientId) async {
    try {
      // 1. Try fetching from new 'appointments' collection first
      final snap = await _firestore.collection(_appointmentsCollection)
          .where('clientId', isEqualTo: clientId)
          .orderBy('startTime', descending: true)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) {
          final data = doc.data();
          // Map new AppointmentModel fields to old MeetingModel
          return MeetingModel(
            id: doc.id,
            clientId: data['clientId'],
            startTime: (data['startTime'] as Timestamp).toDate(),
            meetingType: 'Video', // Default
            purpose: data['topic'] ?? 'Consultation',
            status: _mapStatus(data['status']),
            clinicalNotes: '',
            createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
            updatedAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
          );
        }).toList();
      }

      // 2. Fallback to old 'client_meetings' collection if new one is empty
      final oldSnap = await _firestore.collection('client_meetings')
          .where('clientId', isEqualTo: clientId)
          .orderBy('startTime', descending: true)
          .get();

      return oldSnap.docs.map((doc) => MeetingModel.fromFirestore(doc)).toList();

    } catch (e) {
      _logger.e('Error fetching client meetings: $e');
      return [];
    }
  }

  // Helper to map status string to Enum
  MeetingStatus _mapStatus(String? status) {
    switch (status) {
      case 'confirmed': return MeetingStatus.scheduled;
      case 'completed': return MeetingStatus.completed;
      case 'cancelled': return MeetingStatus.cancelled;
      default: return MeetingStatus.scheduled;
    }
  }

  // ===========================================================================
  // 🎯 SLOT MANAGEMENT (Admin)
  // ===========================================================================

  // 1. Generate Base 15-min Slots
  Future<void> createSlots(List<DateTime> startTimes) async {
    final batch = _firestore.batch();
    for (var start in startTimes) {
      final docRef = _firestore.collection(_slotsCollection).doc();
      batch.set(docRef, {
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(start.add(const Duration(minutes: 15))),
        'isBooked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    _logger.i('Generated ${startTimes.length} slots.');
  }

  // 2. Lock a Date Range
  Future<void> lockTimeRange(DateTime start, DateTime end, String reason) async {
    await _firestore.collection(_locksCollection).add({
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(end),
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 3. Delete Slot
  Future<void> deleteSlot(String slotId) async {
    await _firestore.collection(_slotsCollection).doc(slotId).delete();
  }

  // ===========================================================================
  // 🎯 BOOKING LOGIC (Client)
  // ===========================================================================

  // 4. Get Pricing
  Future<Map<String, int>> getSessionPricing() async {
    try {
      final doc = await _firestore.collection(_configCollection).doc('session_pricing').get();
      if (doc.exists && doc.data() != null) {
        return Map<String, int>.from(doc.data()!);
      }
    } catch (e) {
      _logger.e("Error fetching pricing: $e");
    }
    return {'15': 299, '30': 499, '60': 899};
  }

  // 5. Stream Available Slots
  Stream<List<AppointmentSlot>> streamAvailableSlots() {
    final now = DateTime.now();

    return _firestore.collection(_slotsCollection)
        .where('startTime', isGreaterThan: Timestamp.fromDate(now))
        .where('isBooked', isEqualTo: false)
        .orderBy('startTime')
        .snapshots()
        .asyncMap((slotSnap) async {
      // Fetch Locks
      final lockSnap = await _firestore.collection(_locksCollection)
          .where('endTime', isGreaterThan: Timestamp.fromDate(now))
          .get();

      final locks = lockSnap.docs.map((d) => _TimeRange(
          start: (d['startTime'] as Timestamp).toDate(),
          end: (d['endTime'] as Timestamp).toDate()
      )).toList();

      // Filter Slots
      return slotSnap.docs
          .map((doc) => AppointmentSlot.fromFirestore(doc))
          .where((slot) {
        for (var lock in locks) {
          if (slot.startTime.isAfter(lock.start.subtract(const Duration(seconds: 1))) &&
              slot.startTime.isBefore(lock.end)) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  // 6. Book Session
  Future<String> bookSession({
    required String clientId,
    required String clientName,
    required DateTime startTime,
    required int durationMinutes,
    required String topic,
    required bool useFreeSession
  }) async {
    double cost = 0.0;
    final prices = await getSessionPricing();

    if (useFreeSession) {
      if (durationMinutes > 30) throw Exception("Free sessions are limited to 30 mins max.");
      cost = 0.0;
    } else {
      cost = (prices[durationMinutes.toString()] ?? 500).toDouble();
    }

    final requiredBlocks = durationMinutes ~/ 15;

    return await _firestore.runTransaction((transaction) async {
      // A. Verify Balance
      if (useFreeSession) {
        final clientRef = _firestore.collection('clients').doc(clientId);
        final clientSnap = await transaction.get(clientRef);
        final remaining = clientSnap.data()?['freeSessionsRemaining'] ?? 0;
        if (remaining <= 0) throw Exception("No free sessions remaining.");
        transaction.update(clientRef, {'freeSessionsRemaining': remaining - 1});
      }

      // B. Find & Lock Slots
      List<String> slotIdsToBook = [];
      DateTime checkTime = startTime;

      for (int i = 0; i < requiredBlocks; i++) {
        final slotQuery = await _firestore.collection(_slotsCollection)
            .where('startTime', isEqualTo: Timestamp.fromDate(checkTime))
            .where('isBooked', isEqualTo: false)
            .limit(1)
            .get();

        if (slotQuery.docs.isEmpty) throw Exception("Slot at $checkTime is unavailable.");
        slotIdsToBook.add(slotQuery.docs.first.id);
        checkTime = checkTime.add(const Duration(minutes: 15));
      }

      // C. Mark Booked
      for (var id in slotIdsToBook) {
        transaction.update(_firestore.collection(_slotsCollection).doc(id), {
          'isBooked': true,
          'bookedByClientId': clientId
        });
      }

      // D. Create Appointment
      final apptRef = _firestore.collection(_appointmentsCollection).doc();

      // Creating map directly to avoid Model conflicts if you haven't updated AppointmentModel yet
      transaction.set(apptRef, {
        'clientId': clientId,
        'clientName': clientName,
        'coachId': 'ADMIN',
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(startTime.add(Duration(minutes: durationMinutes))),
        'topic': topic,
        'status': useFreeSession ? 'confirmed' : 'payment_pending',
        'amount': cost,
        'isFreeSession': useFreeSession,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return apptRef.id;
    });
  }
}

class _TimeRange {
  final DateTime start;
  final DateTime end;
  _TimeRange({required this.start, required this.end});
}