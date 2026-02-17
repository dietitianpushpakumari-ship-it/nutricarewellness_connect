import 'package:cloud_firestore/cloud_firestore.dart';

class PrescriptionModel {
  final String id;
  final String sessionId;
  final String clientId;
  final String doctorId;
  final DateTime date;
  final String diagnosis;
  final String chiefComplaints;
  final List<PrescribedMedicine> medications;
  final List<String> labTests;
  final String advice;
  final DateTime? followUpDate;

  PrescriptionModel({
    required this.id,
    required this.sessionId,
    required this.clientId,
    required this.doctorId,
    required this.date,
    this.diagnosis = '',
    this.chiefComplaints = '',
    this.medications = const [],
    this.labTests = const [],
    this.advice = '',
    this.followUpDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'clientId': clientId,
      'doctorId': doctorId,
      'date': Timestamp.fromDate(date),
      'diagnosis': diagnosis,
      'chiefComplaints': chiefComplaints,
      'medications': medications.map((m) => m.toMap()).toList(),
      'labTests': labTests,
      'advice': advice,
      'followUpDate': followUpDate != null ? Timestamp.fromDate(followUpDate!) : null,
    };
  }

  factory PrescriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrescriptionModel(
      id: doc.id,
      sessionId: data['sessionId'] ?? '',
      clientId: data['clientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      diagnosis: data['diagnosis'] ?? '',
      chiefComplaints: data['chiefComplaints'] ?? '',
      medications: (data['medications'] as List<dynamic>?)
          ?.map((m) => PrescribedMedicine.fromMap(m))
          .toList() ?? [],
      labTests: List<String>.from(data['labTests'] ?? []),
      advice: data['advice'] ?? '',
      followUpDate: (data['followUpDate'] as Timestamp?)?.toDate(),
    );
  }
}

class PrescribedMedicine {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String instruction;
  final String? reminderTime; // 🎯 Added for Smart Nudge (Format "HH:MM")

  PrescribedMedicine({
    required this.name,
    this.dosage = '',
    this.frequency = '',
    this.duration = '',
    this.instruction = '',
    this.reminderTime,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
    'duration': duration,
    'instruction': instruction,
    'reminderTime': reminderTime,
  };

  factory PrescribedMedicine.fromMap(Map<String, dynamic> map) => PrescribedMedicine(
    name: map['name'] ?? '',
    dosage: map['dosage'] ?? '',
    frequency: map['frequency'] ?? '',
    duration: map['duration'] ?? '',
    instruction: map['instruction'] ?? '',
    reminderTime: map['reminderTime'],
  );

  // Helper to get display name
  String get medicineName => name;
  String get timing => frequency.isNotEmpty ? frequency : (reminderTime ?? "");
}