import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingStatus { scheduled, completed, cancelled, missed,rescheduled }

// Helper function for Firestore conversion
MeetingStatus stringToMeetingStatus(String status) {
  try {
    return MeetingStatus.values.firstWhere((e) => e.name == status);
  } catch (e) {
    return MeetingStatus.scheduled; // Default to scheduled if unrecognized
  }
}

class MeetingModel {
  final String id;
  final String clientId;
  final DateTime startTime;
  final String meetingType; // e.g., 'Video Call', 'Voice Call', 'In-Person'
  final String purpose;
  final MeetingStatus status;
  final String? clinicalNotes;
  final String? meetLink;
  final Timestamp createdAt;
  final Timestamp updatedAt;

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
  });

  // Factory constructor for creating a MeetingModel from a Firestore document
  factory MeetingModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MeetingModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      meetingType: data['meetingType'] ?? 'Video Call',
      purpose: data['purpose'] ?? 'Follow-up',
      status: stringToMeetingStatus(data['status'] ?? MeetingStatus.scheduled.name),
      clinicalNotes: data['clinicalNotes'],
      meetLink: data['meetLink'],
      // Firestore timestamps are non-nullable for auditing, but use .now() as fallback
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  // Method to convert a MeetingModel to a map for Firestore
  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'clientId': clientId,
      'startTime': Timestamp.fromDate(startTime),
      'meetingType': meetingType,
      'purpose': purpose,
      'status': status.name,
      'clinicalNotes': clinicalNotes,
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
