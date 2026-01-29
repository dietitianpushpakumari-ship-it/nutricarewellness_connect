import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // For TimeOfDay
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/features/appointments/appointment_model.dart';
import 'package:nutricare_connect/features/appointments/schedule_meeting_utils.dart';

final Logger _logger = Logger();

class MeetingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _scheduleCollection = 'schedules';
  final String _appointmentsCollection = 'appointments';
  final String _configCollection = 'configurations';

  static const Map<int, double> sessionPrices = {
    15: 299.0,
    30: 499.0,
    60: 899.0,
  };

  Stream<List<AppointmentSlot>> streamCoachSlots(String coachId, DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final String docId = "${DateFormat('yyyy-MM-dd').format(normalizedDate)}_$coachId";

    return _firestore.collection(_scheduleCollection).doc(docId).snapshots().map((doc) {
      if (!doc.exists) return [];
      final schedule = DailyScheduleModel.fromFirestore(doc);
      return schedule.slots.where((s) => s.status == SlotStatus.available).toList();
    });
  }

  // 🎯 FIXED: Ensure 'guestPhone' is in the parameters
  Future<String> bookSession({
    required String clientId,
    required String clientName,
    String? guestPhone, // 🎯 This parameter must exist
    required String coachId,
    required DateTime startTime,
    required int durationMinutes,
    required String topic,
    required bool useFreeSession,
    String? paymentRef,
    required String performedByUid,
    required String performedByName,
    bool isAdminBooking = false,
  }) async {
    double cost = 0.0;
    final prices = await getSessionPricing();

    if (useFreeSession) {
      if (durationMinutes > 30) throw Exception("Free sessions are limited to 30 mins max.");
      cost = 0.0;
    } else {
      cost = (prices[durationMinutes.toString()] ?? 500).toDouble();
    }

    final DateTime date = DateTime(startTime.year, startTime.month, startTime.day);
    final String scheduleDocId = "${DateFormat('yyyy-MM-dd').format(date)}_$coachId";
    final int requiredBlocks = (durationMinutes / 15).ceil();

    return await _firestore.runTransaction((transaction) async {
      // A. Deduct Free Credit
      if (useFreeSession) {
        final clientRef = _firestore.collection('clients').doc(clientId);
        final clientSnap = await transaction.get(clientRef);
        final remaining = clientSnap.data()?['freeSessionsRemaining'] ?? 0;
        if (remaining <= 0) throw Exception("No free sessions remaining.");
        transaction.update(clientRef, {'freeSessionsRemaining': remaining - 1});
      }

      // B. Lock Slots in Admin Schedule
      final scheduleRef = _firestore.collection(_scheduleCollection).doc(scheduleDocId);
      final scheduleSnap = await transaction.get(scheduleRef);

      if (!scheduleSnap.exists) throw Exception("Coach schedule not found.");

      final scheduleData = scheduleSnap.data()!;
      List<dynamic> slotsData = List.from(scheduleData['slots'] ?? []);
      bool slotsUpdated = false;

      DateTime checkTime = startTime;
      List<int> indicesToBook = [];

      for (int i = 0; i < requiredBlocks; i++) {
        final index = slotsData.indexWhere((s) {
          DateTime sTime = (s['startTime'] as Timestamp).toDate();
          return sTime.isAtSameMomentAs(checkTime);
        });

        if (index == -1) throw Exception("Slot at ${DateFormat.jm().format(checkTime)} does not exist.");

        final slotMap = slotsData[index] as Map<String, dynamic>;
        final String statusStr = slotMap['status'] ?? 'available';
        bool isUnavailable = statusStr != 'available';

        if (isUnavailable) throw Exception("Slot at ${DateFormat.jm().format(checkTime)} is unavailable.");

        indicesToBook.add(index);
        checkTime = checkTime.add(const Duration(minutes: 15));
      }

      SlotStatus targetSlotStatus;
      AppointmentStatus targetApptStatus;

      if (isAdminBooking) {
        targetSlotStatus = SlotStatus.booked;
        targetApptStatus = AppointmentStatus.confirmed;
      } else {
        if (useFreeSession) {
          targetSlotStatus = SlotStatus.booked;
          targetApptStatus = AppointmentStatus.pending;
        } else if (paymentRef != null) {
          targetSlotStatus = SlotStatus.booked;
          targetApptStatus = AppointmentStatus.verification_pending;
        } else {
          targetSlotStatus = SlotStatus.pending_payment;
          targetApptStatus = AppointmentStatus.payment_pending;
        }
      }

      for (var idx in indicesToBook) {
        slotsData[idx]['status'] = targetSlotStatus.name;
        slotsData[idx]['bookedByClientId'] = clientId;
        slotsData[idx]['bookedByGuestName'] = clientName;
        slotsUpdated = true;
      }

      if (slotsUpdated) {
        transaction.update(scheduleRef, {'slots': slotsData});
      }

      // C. Create Appointment
      final apptRef = _firestore.collection(_appointmentsCollection).doc();
      transaction.set(apptRef, {
        'clientId': clientId,
        'clientName': clientName,
        'coachId': coachId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(startTime.add(Duration(minutes: durationMinutes))),
        'topic': topic,
        'status': targetApptStatus.name,
        'amount': cost,
        'isFreeSession': useFreeSession,
        'paymentRef': paymentRef,
        'type': 'online',
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': performedByUid,
        'createdByName': performedByName,
        'isSettled': false,
        'guestPhone': guestPhone, // 🎯 Save to Firestore
      });

      return apptRef.id;
    });
  }

  Future<Map<String, int>> getSessionPricing() async {
    try {
      final doc = await _firestore.collection(_configCollection).doc('session_pricing').get();
      if (doc.exists && doc.data() != null) return Map<String, int>.from(doc.data()!);
    } catch (_) {}
    return {'15': 299, '30': 499, '60': 899};
  }

  Future<List<MeetingModel>> getClientMeetings(String clientId) async {
    try {
      final snap = await _firestore.collection(_appointmentsCollection)
          .where('clientId', isEqualTo: clientId)
          .orderBy('startTime', descending: true)
          .get();

      return snap.docs.map((doc) {
        final d = doc.data();
        return MeetingModel(
            id: doc.id,
            clientId: d['clientId'] ?? '',
            startTime: (d['startTime'] as Timestamp).toDate(),
            meetingType: d['type'] ?? 'Video Call',
            purpose: d['topic'] ?? 'Consultation',
            status: stringToMeetingStatus(d['status'] ?? 'scheduled'),
            clinicalNotes: d['adminNote'],
            createdAt: d['createdAt'] ?? Timestamp.now(),
            updatedAt: d['createdAt'] ?? Timestamp.now()
        );
      }).toList();
    } catch (e) { return []; }
  }

  Future<void> scheduleMeeting({
    required String clientId,
    required DateTime startTime,
    required String meetingType,
    required String purpose,
    String? meetLink,
    String? clinicalNotes
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final String coachId = user?.uid ?? 'system_admin';
    final String adminName = user?.displayName ?? user?.email ?? 'Admin';

    String clientName = 'Client';
    try {
      final clientDoc = await _firestore.collection('clients').doc(clientId).get();
      if (clientDoc.exists) {
        clientName = clientDoc.data()?['name'] ?? 'Client';
      }
    } catch (_) {}

    final apptId = await bookSession(
      clientId: clientId,
      clientName: clientName,
      coachId: coachId,
      startTime: startTime,
      durationMinutes: 30,
      topic: purpose,
      useFreeSession: false,
      isAdminBooking: true,
      performedByUid: coachId,
      performedByName: adminName,
    );

    if (meetLink != null || clinicalNotes != null) {
      await _firestore.collection(_appointmentsCollection).doc(apptId).update({
        if (meetLink != null) 'meetLink': meetLink,
        if (clinicalNotes != null) 'adminNote': clinicalNotes,
      });
    }
  }
  Future<void> cancelAppointment(String appointmentId) async {
    await _firestore.collection(_appointmentsCollection).doc(appointmentId).update({
      'status': AppointmentStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Note: This does not automatically free the slot in the Coach's schedule
    // (which prevents instant re-booking of a cancelled slot without admin review).
    // If you want auto-free, you'd need to reverse the 'bookSession' transaction logic here.
  }

  Future<void> deleteFreeSlots({
    required String coachId,
    required DateTime date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final String docId = "${DateFormat('yyyy-MM-dd').format(normalizedDate)}_$coachId";
    final docRef = _firestore.collection(_scheduleCollection).doc(docId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final schedule = DailyScheduleModel.fromFirestore(snapshot);
      List<AppointmentSlot> updatedSlots = List.from(schedule.slots);

      bool shouldDelete(AppointmentSlot slot) {
        if (slot.status != SlotStatus.available) return false;

        if (startTime != null && endTime != null) {
          final slotStart = TimeOfDay.fromDateTime(slot.startTime);
          final int startMin = startTime.hour * 60 + startTime.minute;
          final int endMin = endTime.hour * 60 + endTime.minute;
          final int slotStartMin = slotStart.hour * 60 + slotStart.minute;
          return slotStartMin >= startMin && slotStartMin < endMin;
        }
        return true;
      }

      updatedSlots.removeWhere(shouldDelete);

      transaction.update(docRef, {
        'slots': updatedSlots.map((e) => e.toJson()).toList(),
        'hasAvailableSlots': updatedSlots.any((s) => s.status == SlotStatus.available),
      });
    });
  }

  Future<void> reassignSession({
    required String oldCoachId,
    required String newCoachId,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (oldCoachId == newCoachId) return;

    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final String oldDocId = "${DateFormat('yyyy-MM-dd').format(normalizedDate)}_$oldCoachId";
    final String newDocId = "${DateFormat('yyyy-MM-dd').format(normalizedDate)}_$newCoachId";

    final oldScheduleRef = _firestore.collection(_scheduleCollection).doc(oldDocId);
    final newScheduleRef = _firestore.collection(_scheduleCollection).doc(newDocId);

    final apptQuery = await _firestore.collection(_appointmentsCollection)
        .where('coachId', isEqualTo: oldCoachId)
        .where('startTime', isEqualTo: Timestamp.fromDate(startTime))
        .limit(1)
        .get();

    if (apptQuery.docs.isEmpty) {
      throw Exception("Appointment record not found for reassignment.");
    }
    final apptDocRef = apptQuery.docs.first.reference;

    await _firestore.runTransaction((transaction) async {
      final oldSnap = await transaction.get(oldScheduleRef);
      final newSnap = await transaction.get(newScheduleRef);

      if (!oldSnap.exists) throw Exception("Source schedule not found.");
      if (!newSnap.exists) throw Exception("Target coach has no schedule generated for this day.");

      final oldSchedule = DailyScheduleModel.fromFirestore(oldSnap);
      final newSchedule = DailyScheduleModel.fromFirestore(newSnap);

      List<AppointmentSlot> oldSlots = List.from(oldSchedule.slots);
      List<AppointmentSlot> newSlots = List.from(newSchedule.slots);

      final slotsToMove = oldSlots.where((s) =>
      (s.startTime.isAtSameMomentAs(startTime) || s.startTime.isAfter(startTime)) &&
          s.startTime.isBefore(endTime)
      ).toList();

      if (slotsToMove.isEmpty) throw Exception("No slots found to move.");

      final String? guestName = slotsToMove.first.bookedByGuestName;
      final String? clientId = slotsToMove.first.bookedByClientId;
      final SlotStatus status = slotsToMove.first.status;

      for (var sourceSlot in slotsToMove) {
        final oldIndex = oldSlots.indexWhere((s) => s.id == sourceSlot.id);
        if (oldIndex != -1) {
          // 🎯 FIXED: Correct parameter names
          oldSlots[oldIndex] = oldSlots[oldIndex].copyWith(
              status: SlotStatus.available,
              bookedByGuestName: null,
              bookedByClientId: null
          );
        }

        final newIndex = newSlots.indexWhere((s) => s.startTime.isAtSameMomentAs(sourceSlot.startTime));
        if (newIndex == -1) throw Exception("Target coach does not have a slot at ${DateFormat.jm().format(sourceSlot.startTime)}.");
        if (newSlots[newIndex].status != SlotStatus.available) throw Exception("Target coach is already booked at ${DateFormat.jm().format(sourceSlot.startTime)}.");

        // 🎯 FIXED: Correct parameter names
        newSlots[newIndex] = newSlots[newIndex].copyWith(
          status: status,
          bookedByGuestName: guestName,
          bookedByClientId: clientId,
          coachId: newCoachId,
        );
      }

      transaction.update(oldScheduleRef, {
        'slots': oldSlots.map((e) => e.toJson()).toList(),
      });

      transaction.update(newScheduleRef, {
        'slots': newSlots.map((e) => e.toJson()).toList(),
      });

      transaction.update(apptDocRef, {
        'coachId': newCoachId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rescheduleSession({
    required String coachId,
    required DateTime oldStartTime,
    required DateTime newStartTime,
    required int durationMinutes,
  }) async {
    final DateTime oldDate = DateTime(oldStartTime.year, oldStartTime.month, oldStartTime.day);
    final DateTime newDate = DateTime(newStartTime.year, newStartTime.month, newStartTime.day);

    final String oldDocId = "${DateFormat('yyyy-MM-dd').format(oldDate)}_$coachId";
    final String newDocId = "${DateFormat('yyyy-MM-dd').format(newDate)}_$coachId";

    final oldScheduleRef = _firestore.collection(_scheduleCollection).doc(oldDocId);
    final newScheduleRef = _firestore.collection(_scheduleCollection).doc(newDocId);

    final apptQuery = await _firestore.collection(_appointmentsCollection)
        .where('coachId', isEqualTo: coachId)
        .where('startTime', isEqualTo: Timestamp.fromDate(oldStartTime))
        .limit(1)
        .get();

    if (apptQuery.docs.isEmpty) throw Exception("Original appointment record not found. Cannot reschedule.");
    final apptDocRef = apptQuery.docs.first.reference;

    await _firestore.runTransaction((transaction) async {
      final oldSnap = await transaction.get(oldScheduleRef);
      final newSnap = await transaction.get(newScheduleRef);

      if (!oldSnap.exists) throw Exception("Source schedule data missing.");
      if (!newSnap.exists) throw Exception("Target day schedule not generated yet.");

      final oldSchedule = DailyScheduleModel.fromFirestore(oldSnap);
      final newSchedule = DailyScheduleModel.fromFirestore(newSnap);

      List<AppointmentSlot> oldSlots = List.from(oldSchedule.slots);
      List<AppointmentSlot> newSlots = List.from(newSchedule.slots);

      DateTime checkTime = newStartTime;
      final int slotsNeeded = (durationMinutes / 15).ceil();
      final List<int> newSlotIndices = [];

      for (int i = 0; i < slotsNeeded; i++) {
        final index = newSlots.indexWhere((s) => s.startTime.isAtSameMomentAs(checkTime));

        if (index == -1) throw Exception("Target time ${DateFormat.jm().format(checkTime)} does not exist in schedule.");
        if (newSlots[index].status != SlotStatus.available) throw Exception("Target slot ${DateFormat.jm().format(checkTime)} is already booked.");

        newSlotIndices.add(index);
        checkTime = checkTime.add(const Duration(minutes: 15));
      }

      final DateTime oldEndTime = oldStartTime.add(Duration(minutes: durationMinutes));
      final slotsToClear = oldSlots.where((s) =>
      (s.startTime.isAtSameMomentAs(oldStartTime) || s.startTime.isAfter(oldStartTime)) &&
          s.startTime.isBefore(oldEndTime)
      ).toList();

      if (slotsToClear.isEmpty) throw Exception("Original slots not found in schedule grid.");

      final infoSlot = slotsToClear.first;
      final String? clientId = infoSlot.bookedByClientId;
      final String? guestName = infoSlot.bookedByGuestName;
      final SlotStatus status = infoSlot.status;

      for (var slot in slotsToClear) {
        final idx = oldSlots.indexWhere((s) => s.id == slot.id);
        if (idx != -1) {
          // 🎯 FIXED: Correct parameter names
          oldSlots[idx] = oldSlots[idx].copyWith(
              status: SlotStatus.available,
              bookedByClientId: null,
              bookedByGuestName: null
          );
        }
      }

      for (var idx in newSlotIndices) {
        // 🎯 FIXED: Correct parameter names
        newSlots[idx] = newSlots[idx].copyWith(
            status: status,
            bookedByClientId: clientId,
            bookedByGuestName: guestName
        );
      }

      transaction.update(oldScheduleRef, {
        'slots': oldSlots.map((e) => e.toJson()).toList(),
        'hasAvailableSlots': oldSlots.any((s) => s.status == SlotStatus.available),
      });

      if (oldDocId == newDocId) {
        final combinedSlots = List<AppointmentSlot>.from(oldSchedule.slots);
        for (var slot in slotsToClear) {
          final idx = combinedSlots.indexWhere((s) => s.id == slot.id);
          if(idx!=-1) combinedSlots[idx] = combinedSlots[idx].copyWith(status: SlotStatus.available, bookedByClientId: null, bookedByGuestName: null);
        }
        for (int i = 0; i < slotsNeeded; i++) {
          DateTime t = newStartTime.add(Duration(minutes: 15 * i));
          final idx = combinedSlots.indexWhere((s) => s.startTime.isAtSameMomentAs(t));
          if(idx!=-1) combinedSlots[idx] = combinedSlots[idx].copyWith(status: status, bookedByClientId: clientId, bookedByGuestName: guestName);
        }
        transaction.update(oldScheduleRef, {
          'slots': combinedSlots.map((e) => e.toJson()).toList(),
        });
      } else {
        transaction.update(newScheduleRef, {
          'slots': newSlots.map((e) => e.toJson()).toList(),
          'hasAvailableSlots': newSlots.any((s) => s.status == SlotStatus.available),
        });
      }

      transaction.update(apptDocRef, {
        'startTime': Timestamp.fromDate(newStartTime),
        'endTime': Timestamp.fromDate(newStartTime.add(Duration(minutes: durationMinutes))),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ... (Other methods remain unchanged)
  Stream<List<AppointmentModel>> streamUpcomingReminders(String coachId) {
    final now = DateTime.now();
    final next24h = now.add(const Duration(hours: 24));

    return _firestore.collection(_appointmentsCollection)
        .where('coachId', isEqualTo: coachId)
        .where('status', isEqualTo: AppointmentStatus.confirmed.name)
        .where('startTime', isGreaterThan: Timestamp.fromDate(now))
        .where('startTime', isLessThan: Timestamp.fromDate(next24h))
        .orderBy('startTime')
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AppointmentModel.fromFirestore(d)).toList());
  }

  Stream<List<AppointmentModel>> streamNudgeAppointments(String coachId) {
    final start = DateTime.now().subtract(const Duration(days: 3));
    final end = DateTime.now().add(const Duration(days: 7));

    return _firestore.collection(_appointmentsCollection)
        .where('coachId', isEqualTo: coachId)
        .where('startTime', isGreaterThan: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => AppointmentModel.fromFirestore(d)).toList();
      return list.where((a) =>
      a.status != AppointmentStatus.cancelled &&
          a.status != AppointmentStatus.completed
      ).toList();
    });
  }
}