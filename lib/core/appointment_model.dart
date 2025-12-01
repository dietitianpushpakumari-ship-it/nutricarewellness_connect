import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { scheduled, pending, confirmed, cancelled, completed }

// 1. The Booking Request
class AppointmentModel {
  final String id;
  final String clientId;
  final String clientName; // Denormalized for easy display
  final String coachId;
  final DateTime startTime;
  final DateTime endTime;
  final String topic;
  final String meetingLink; // Admin adds this later
  final AppointmentStatus status;

  AppointmentModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.coachId,
    required this.startTime,
    required this.endTime,
    required this.topic,
    this.meetingLink = '',
    this.status = AppointmentStatus.pending,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppointmentModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? 'Client',
      coachId: data['coachId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      topic: data['topic'] ?? '',
      meetingLink: data['meetingLink'] ?? '',
      status: AppointmentStatus.values.firstWhere(
              (e) => e.name == (data['status'] ?? 'pending'),
          orElse: () => AppointmentStatus.pending),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'coachId': coachId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'topic': topic,
      'meetingLink': meetingLink,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// 2. The Admin Availability Slot
class AppointmentSlot {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;
  final String? bookedByClientId;

  AppointmentSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.bookedByClientId,
  });

  factory AppointmentSlot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppointmentSlot(
      id: doc.id,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      isBooked: data['isBooked'] ?? false,
      bookedByClientId: data['bookedByClientId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isBooked': isBooked,
      'bookedByClientId': bookedByClientId,
    };
  }
}