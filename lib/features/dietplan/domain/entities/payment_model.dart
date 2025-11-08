import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String packageAssignmentId;
  final double amount;
  final DateTime paymentDate; // Now explicitly captured
  final String receivedBy;
  final String paymentMethod;
  final String? narration; // New field

  PaymentModel({
    required this.id,
    required this.packageAssignmentId,
    required this.amount,
    required this.paymentDate,
    required this.receivedBy,
    required this.paymentMethod,
    this.narration, // New argument
  });

  Map<String, dynamic> toMap() {
    return {
      'packageAssignmentId': packageAssignmentId,
      'amount': amount,
      'paymentDate': paymentDate,
      'receivedBy': receivedBy,
      'paymentMethod': paymentMethod,
      'narration': narration, // New field map
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      packageAssignmentId: data['packageAssignmentId'] as String,
      amount: (data['amount'] as num).toDouble(),
      paymentDate: (data['paymentDate'] as Timestamp).toDate(),
      receivedBy: data['receivedBy'] as String,
      paymentMethod: data['paymentMethod'] as String,
      narration: data['narration'] as String?, // Retrieve narration
    );
  }
}