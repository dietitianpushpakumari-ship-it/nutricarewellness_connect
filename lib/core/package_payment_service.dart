import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/features/appointments/appointment_model.dart';
import 'package:nutricare_connect/core/assigned_package_data.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/payment_model.dart';
import 'package:nutricare_connect/features/auth/client_service.dart';


// Ensure your logger is correctly initialized elsewhere or use a simple print statement
final Logger _logger = Logger(/* ... */);
final FirebaseFirestore _db = FirebaseFirestore.instance;
final String _assignmentCollectionName = 'packageAssignments';


final CollectionReference _clientCollection = FirebaseFirestore.instance.collection('clients');
CollectionReference _assignmentCollection(String clientId) =>
    _clientCollection.doc(clientId).collection(_assignmentCollectionName);

///clients/0fVnqxUPFeGswQKv7z8i/packageAssignments/Ipwq6XmWaxlzqfDig8Du
CollectionReference _paymentCollection(String clientId, String assignmentId) {
  final path = '${_clientCollection.path}/$clientId/${_assignmentCollectionName}/$assignmentId';

  // 🎯 LOGGING ADDED HERE: Now you can see the exact path being queried.
  if (kDebugMode) {
    _logger.i('Payment Collection Path: $path');
  }
  _paymentCollectionPath(clientId,assignmentId);
  final assignmentDocRef = _assignmentCollection(clientId).doc(assignmentId);
  return assignmentDocRef.collection(assignmentId);
  //return _assignmentCollection(clientId).doc('payments').collection(assignmentId);




  //final assignmentDocRef = _assignmentCollection(clientId).doc(assignmentId);

  // 2. Return the subcollection reference for payments


}

// The correct helper function for the nested payments collection
CollectionReference _paymentCollectionPath(String clientId, String assignmentId) {
  final paymentCollectionRef = _assignmentCollection(clientId);
    //  .doc(assignmentId)
    //  .collection(_paymentCollectionName);

  if (kDebugMode) {
    _logger.i('Full Payment Collection Path: ${paymentCollectionRef.path}');
  }
  return paymentCollectionRef;
}

/*CollectionReference _paymentCollectionPath(String clientId, String assignmentId) {
  // 1. Build the document reference for the assignment
  final assignmentDocRef = _assignmentCollection(clientId).doc(assignmentId);

  // 2. Add the subcollection reference for payments
  final paymentCollectionRef = assignmentDocRef.collection(_paymentCollectionName);

  if (kDebugMode) {
    // 🎯 CHECK 1: Explicitly log the subcollection name to ensure it is 'payments'.
    _logger.i('Payment Subcollection Name: $_paymentCollectionName');

    // 🎯 CHECK 2: Log the .path property of the final COLLECTION REFERENCE.
    _logger.i('Full Payment Collection Path: ${paymentCollectionRef.path}');
  }

  return paymentCollectionRef;
} */
final CollectionReference _paymentCollectionv2 = FirebaseFirestore.instance.collection('payments');

class PackagePaymentService {

  /*Future<void> addPayment(PaymentModel payment, {
    required String clientId,
    required String assignmentId,
  }) async {
    try {
      // 🎯 CORRECT CALL: Call the function with parameters to get the CollectionReference
      await _paymentCollection(clientId, assignmentId).add(payment.toMap());
    } catch (e) {
      _logger.e('Failed to record payment: $e');
      throw Exception('Failed to record payment.');
    }
  }*/

  Future<void> addPayment(PaymentModel payment) async {
    try {
      // For simplicity, we use doc.id as the packageAssignmentId in the PaymentModel
      await _paymentCollectionv2.add(payment.toMap());
    } catch (e) {
      throw Exception('Failed to record payment.');
    }
  }

// NOTE: Keep all other methods (e.g., for Packages CRUD) in this file as well.


  /// Streams all payments recorded against a specific package assignment.
  Stream<List<PaymentModel>> streamPaymentsForAssignment(String assignmentId) {
    return _paymentCollectionv2
        .where('packageAssignmentId', isEqualTo: assignmentId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => PaymentModel.fromFirestore(doc)).toList());
  }


  /*Stream<List<PaymentModel>> streamPaymentsForAssignment(String clientId,
      String assignmentId) {
    // 🎯 CORRECT CALL: Call the function with parameters
    return _paymentCollection(clientId, assignmentId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => PaymentModel.fromFirestore(doc)).toList());
  }*/


  Future<void> deletePayment(String paymentId,
      {required String deletionReason}) async {
    final paymentRef = _db.collection('payments').doc(paymentId);
    final deletedPaymentsRef = _db.collection('deletedPaymentsAudit').doc();

    return _db.runTransaction((transaction) async {
      // 1. Get the document to be deleted
      DocumentSnapshot paymentSnapshot = await transaction.get(paymentRef);

      if (!paymentSnapshot.exists) {
        throw Exception("Payment record not found for ID: $paymentId");
      }

      final paymentData = paymentSnapshot.data() as Map<String, dynamic>;

      // 2. Prepare the audit data (include the reason, who deleted it, and when)
      final auditData = {
        ...paymentData,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': FirebaseAuth.instance.currentUser?.email ?? 'SystemAdmin',
        'deletionReason': deletionReason,
        'originalId': paymentId, // Keep reference to the original ID
      };

      // 3. Add the record to the audit collection
      transaction.set(deletedPaymentsRef, auditData);

      // 4. Delete the record from the active 'payments' collection
      transaction.delete(paymentRef);
    }).then((result) {
      // Transaction succeeded
      print("Payment $paymentId successfully audited and deleted.");
    }).catchError((error) {
      // Transaction failed
      print("Transaction failed: $error");
      throw Exception("Failed to process payment deletion: $error");
    });
  }

  Future<List<AssignedPackageData>> getAllAssignmentsWithCollectedAmounts() async {
    final List<AssignedPackageData> ledgerData = [];

    // 1. Efficiently fetch ALL payments needed (one single read operation)
    final allPaymentsSnapshot = await _paymentCollectionv2.get();

    // Group payments by assignmentId for fast O(1) lookup during the loop
    final Map<String, List<DocumentSnapshot>> paymentsByAssignment = {};
    for (var doc in allPaymentsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final currentAssignmentId = data['packageAssignmentId'] as String?;
      if (currentAssignmentId != null) {
        paymentsByAssignment.putIfAbsent(currentAssignmentId, () => []).add(doc);
      }
    }

    // 2. Fetch clients and assignments as before
    final clientSnapshot = await _clientCollection.get();

    for (var clientDoc in clientSnapshot.docs) {
      final clientId = clientDoc.id;
      final clientName = ClientModel.fromFirestore(clientDoc).name;
      final assignmentSnapshot = await _assignmentCollection(clientId).get();

      for (var assignmentDoc in assignmentSnapshot.docs) {
        final assignmentId = assignmentDoc.id;
        final assignment = PackageAssignmentModel.fromFirestore(assignmentDoc);

        // 3. Calculate total collected amount using the pre-fetched map
        final relevantPayments = paymentsByAssignment[assignmentId] ?? [];

        final collectedAmount = relevantPayments.fold<double>(0.0, (sum, doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            // Robust check for amount type
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            return sum + amount;
          } catch (e) {
            if (kDebugMode) {
              _logger.w('Failed to process payment document ${doc.id} for assignment $assignmentId: $e');
            }
            return sum;
          }
        });

        // 4. Combine and add to the final list
        ledgerData.add(
          AssignedPackageData(
            clientName: clientName!,
            assignment: assignment,
            collectedAmount: collectedAmount,
          ),
        );
      }
    }

    ledgerData.sort((a, b) => a.clientName.compareTo(b.clientName));
    return ledgerData;
  }

  Future<double> getTotalCollectedForClient(String clientId) async {
    try {
      // 1. Query the root 'payments' collection
      final QuerySnapshot snapshot = await _paymentCollectionv2
          .where('clientId', isEqualTo: clientId) // 🎯 Filter by the client ID
          .get();
      double totalCollected = 0.0;

      // 2. Aggregate (Sum) the amount field
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Ensure 'amount' exists and is a number type (int/double)
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        totalCollected += amount;
      }

      return totalCollected;

    } catch (e) {
      // Log or handle the error appropriately
      print('Error fetching total collected for client $clientId: $e');
      return 0.0;
    }
  }

  Future<double> getCollectedAmountForAssignment(String assignmentId) async {
    try {
      // 1. Query the root 'payments' collection
      final QuerySnapshot snapshot = await _paymentCollectionv2
          .where('packageAssignmentId', isEqualTo: assignmentId) // 🎯 Filter by the client ID
          .get();
      double totalCollected = 0.0;

      // 2. Aggregate (Sum) the amount field
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Ensure 'amount' exists and is a number type (int/double)
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        totalCollected += amount;
      }

      return totalCollected;

    } catch (e) {
      // Log or handle the error appropriately
      print('Error fetching total collected for assignment $assignmentId: $e');
      return 0.0;
    }
  }
// 🎯 NEW HELPER: Fetch the total collected amount for a single assignment
 /* Future<double> getCollectedAmountForAssignment(String clientId, String assignmentId) async {
    final paymentsSnapshot = await _paymentCollectionv2.doc(clientId).get();
    final doc = await _clientCollection.doc(clientId).get();

    double collectedAmount = 0.0;

    for (var doc in paymentsSnapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        // Assuming payment models stores amount as 'amount'
        collectedAmount += (data['amount'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        if (kDebugMode) {
          print('Warning: Failed to process payment document ${doc.id}: $e');
        }
      }
    }
    return collectedAmount;
  }*/

// Inside PackagePaymentService

  // 1. Fetch Unsettled Appointments
// 1. Stream Unsettled Appointments (With Client-Side Filtering)
  Stream<List<AppointmentModel>> streamUnsettledAppointments() {
    return _db.collection('appointments')
        .where('status', whereIn: ['confirmed', 'completed']) // Only active bookings
    // ⚠️ REMOVED: .where('isSettled', isEqualTo: false)
    // Reason: Legacy docs don't have 'isSettled', so Firestore excludes them.
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => AppointmentModel.fromFirestore(d))
      // 🎯 Client-Side Filter: Catch missing field (default false) OR explicit false
          .where((appt) => !appt.isSettled && (appt.amountPaid ?? 0) > 0)
          .toList();
    });
  }
  // 2. The Manual Post Action
  Future<void> postSettlement({
    required AppointmentModel appointment,
    required double finalAmount,
    required String paymentMode,
    required String paymentRef,
    required String narration,
  }) async {
    if (appointment.clientId == null) {
      throw Exception("Cannot settle guest bookings. Register client first.");
    }

    final batch = _db.batch();

    // A. Create Virtual "Single Session" Assignment
    final virtualAssignmentId = "appt_${appointment.id}"; // Unique ID based on Appt
    final assignmentRef = _assignmentCollection(appointment.clientId!).doc(virtualAssignmentId);

    final virtualAssignment = PackageAssignmentModel(
      id: virtualAssignmentId,
      packageId: 'single_session',
      packageName: "Session: ${appointment.topic}",
      purchaseDate: DateTime.now(), // Settlement Date
      expiryDate: appointment.endTime,
      isActive: false, // Consumed
      isLocked: true,
      clientId: appointment.clientId!,
      diagnosis: 'One-off Consultation',
      bookedAmount: finalAmount, // 🎯 Use the verified amount
      category: 'Consultation',
      discount: 0,
    );

    // B. Create Ledger Payment Record
    final paymentDoc = _paymentCollectionv2.doc();
    final payment = PaymentModel(
      id: paymentDoc.id,
      packageAssignmentId: virtualAssignmentId,
      amount: finalAmount,
      paymentDate: DateTime.now(),
      receivedBy: FirebaseAuth.instance.currentUser?.email ?? 'Admin',
      paymentMethod: paymentMode,
      narration: "$narration (Appt Ref: ${appointment.id})",
    );

    // C. Update Appointment as Settled
    final apptRef = _db.collection('appointments').doc(appointment.id);

    // EXECUTE
    batch.set(assignmentRef, virtualAssignment.toMap());
    batch.set(paymentDoc, payment.toMap());
    batch.update(apptRef, {
      'isSettled': true,
      'amount': finalAmount, // Update booking amount to match verified
      'paymentRef': paymentRef,
      'paymentMethod': paymentMode
    });

    await batch.commit();
    _logger.i("Settlement posted for Appt ${appointment.id}");
  }

}
