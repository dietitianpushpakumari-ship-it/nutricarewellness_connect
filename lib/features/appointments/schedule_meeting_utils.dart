import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingStatus {
  scheduled,
  confirmed,
  completed,
  cancelled,
  missed,
  rescheduled,
  pending,
  payment_pending,
  verification_pending
}

// Helper function for Firestore conversion
MeetingStatus stringToMeetingStatus(String status) {
  try {
    // Handle legacy 'scheduled' vs new 'confirmed' mapping if needed
    if (status == 'scheduled') return MeetingStatus.scheduled;
    return MeetingStatus.values.firstWhere((e) => e.name == status);
  } catch (e) {
    return MeetingStatus.scheduled; // Default
  }
}

class MeetingModel {
  final String id;
  final String clientId;
  final DateTime startTime;
  final String meetingType;
  final String purpose;
  final MeetingStatus status;
  final String? clinicalNotes;
  final String? meetLink;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  // 🎯 NEW: To show "Free" vs "Paid" in UI
  final bool isFreeSession;
  final double amount;

  MeetingModel({
    required this.id,
    required this.clientId,
    required this.startTime,
    required this.meetingType,
    required this.purpose,
    this.status = MeetingStatus.scheduled,
    this.clinicalNotes,
    this.meetLink,
    required this.createdAt,
    required this.updatedAt,
    this.isFreeSession = false,
    this.amount = 0.0,
  });

  factory MeetingModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MeetingModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      meetingType: data['type'] ?? 'Video Call', // Mapped from 'type'
      purpose: data['topic'] ?? 'Consultation',  // Mapped from 'topic'
      status: stringToMeetingStatus(data['status'] ?? 'scheduled'),
      clinicalNotes: data['adminNote'],
      meetLink: data['meetLink'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      isFreeSession: data['isFreeSession'] ?? false,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'clientId': clientId,
      'startTime': Timestamp.fromDate(startTime),
      'type': meetingType, // aligned with AppointmentModel
      'topic': purpose,    // aligned with AppointmentModel
      'status': status.name,
      'adminNote': clinicalNotes,
      'meetLink': meetLink,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    };
  }


  // Method for internal copy operations (used for updates)
  MeetingModel copyWith({
    MeetingStatus? status,
    String? clinicalNotes,
    String? meetLink,
  }) {
    return MeetingModel(
      id: id,
      clientId: clientId,
      startTime: startTime,
      meetingType: meetingType,
      purpose: purpose,
      status: status ?? this.status,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      meetLink: meetLink ?? this.meetLink,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
