import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/features/appointments/appointment_model.dart';
import 'package:pure_shift/core/assigned_package_data.dart';
import 'package:pure_shift/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:pure_shift/features/dietplan/domain/entities/payment_model.dart';

final Logger _logger = Logger();
final FirebaseFirestore _db = FirebaseFirestore.instance;

class PackagePaymentService {
  final String _tenantId;
  final CollectionReference _paymentCollectionv2 = _db.collection('payments');
  final CollectionReference _clientCollection = _db.collection('clients');

  // 🎯 Constructor receives the auto-fetched ID from the Provider
  PackagePaymentService({required String tenantId}) : _tenantId = tenantId;

  // Helper for subcollection access
  CollectionReference _assignmentCollection(String clientId) =>
      _clientCollection.doc(clientId).collection('packageAssignments');

  // ---------------------------------------------------------------------------
  // 💰 CORE LEDGER METHODS
  // ---------------------------------------------------------------------------

  /// Fetches all assignments and calculates collected amounts strictly for the current tenant.
  Future<List<AssignedPackageData>> getAllAssignmentsWithCollectedAmounts() async {
    final List<AssignedPackageData> ledgerData = [];

    // 1. Fetch only payments belonging to THIS tenant
    final allPaymentsSnapshot = await _paymentCollectionv2
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    final Map<String, List<DocumentSnapshot>> paymentsByAssignment = {};
    for (var doc in allPaymentsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final currentAssignmentId = data['packageAssignmentId'] as String?;
      if (currentAssignmentId != null) {
        paymentsByAssignment.putIfAbsent(currentAssignmentId, () => []).add(doc);
      }
    }

    // 2. Fetch clients strictly for this tenant
    final clientSnapshot = await _clientCollection
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    for (var clientDoc in clientSnapshot.docs) {
      final clientId = clientDoc.id;
      final clientName = ClientModel.fromFirestore(clientDoc).name;
      final assignmentSnapshot = await _assignmentCollection(clientId).get();

      for (var assignmentDoc in assignmentSnapshot.docs) {
        final assignmentId = assignmentDoc.id;
        final assignment = PackageAssignmentModel.fromFirestore(assignmentDoc);

        final relevantPayments = paymentsByAssignment[assignmentId] ?? [];
        final collectedAmount = relevantPayments.fold<double>(0.0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['amount'] as num?)?.toDouble() ?? 0.0);
        });

        ledgerData.add(
          AssignedPackageData(
            clientName: clientName ?? 'Unknown',
            assignment: assignment,
            collectedAmount: collectedAmount,
          ),
        );
      }
    }

    ledgerData.sort((a, b) => a.clientName.compareTo(b.clientName));
    return ledgerData;
  }

  // ---------------------------------------------------------------------------
  // 🤝 APPOINTMENT SETTLEMENT
  // ---------------------------------------------------------------------------

  Stream<List<AppointmentModel>> streamUnsettledAppointments() {
    return _db.collection('appointments')
        .where('tenantId', isEqualTo: _tenantId)
        .where('status', whereIn: ['confirmed', 'completed'])
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => AppointmentModel.fromFirestore(d))
        .where((appt) => !appt.isSettled && (appt.amountPaid ?? 0) > 0)
        .toList());
  }

  Future<void> postSettlement({
    required AppointmentModel appointment,
    required double finalAmount,
    required String paymentMode,
    required String paymentRef,
    required String narration,
  }) async {
    if (appointment.clientId == null) throw Exception("Client context missing.");

    final batch = _db.batch();
    final virtualAssignmentId = "appt_${appointment.id}";
    final assignmentRef = _assignmentCollection(appointment.clientId!).doc(virtualAssignmentId);

    final virtualAssignment = PackageAssignmentModel(
      id: virtualAssignmentId,
      packageId: 'single_session',
      packageName: "Session: ${appointment.topic}",
      purchaseDate: DateTime.now(),
      expiryDate: appointment.endTime,
      isActive: false,
      isLocked: true,
      clientId: appointment.clientId!,
      diagnosis: 'Consultation',
      bookedAmount: finalAmount,
      category: 'Consultation',
      tenantId: _tenantId,
    );

    final paymentDoc = _paymentCollectionv2.doc();
    final payment = PaymentModel(
      id: paymentDoc.id,
      packageAssignmentId: virtualAssignmentId,
      amount: finalAmount,
      paymentDate: DateTime.now(),
      receivedBy: FirebaseAuth.instance.currentUser?.email ?? 'Admin',
      paymentMethod: paymentMode,
      narration: "$narration (Appt Ref: ${appointment.id})",
      // Ensure your PaymentModel supports tenantId if needed globally
    );

    batch.set(assignmentRef, virtualAssignment.toMap());
    final paymentData = payment.toMap();
    paymentData['tenantId'] = _tenantId; // 🎯 Inject tenantId
    batch.set(paymentDoc, paymentData);

    batch.update(_db.collection('appointments').doc(appointment.id), {
      'isSettled': true,
      'amount': finalAmount,
      'paymentRef': paymentRef,
      'paymentMethod': paymentMode,
      'tenantId': _tenantId,
    });

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // ➕ BASIC CRUD
  // ---------------------------------------------------------------------------

  Future<void> addPayment(PaymentModel payment) async {
    final paymentData = payment.toMap();
    paymentData['tenantId'] = _tenantId;
    await _paymentCollectionv2.add(paymentData);
  }

  Stream<List<PaymentModel>> streamPaymentsForAssignment(String assignmentId) {
    return _paymentCollectionv2
        .where('tenantId', isEqualTo: _tenantId)
        .where('packageAssignmentId', isEqualTo: assignmentId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => PaymentModel.fromFirestore(doc)).toList());
  }
}