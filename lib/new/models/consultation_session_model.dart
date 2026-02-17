import 'package:cloud_firestore/cloud_firestore.dart';

class ConsultationSessionModel {
  final String id;
  final String clientId;
  final String dietitianId;
  final String? tenantId; // 🎯 Added Tenant ID for Multi-Tenancy
  final Timestamp sessionDate;
  final Timestamp startTime;
  final Timestamp? endTime;
  final String status;

  final String? linkedVitalsId;
  final String? linkedDietPlanId;

  // 🎯 NEW FIELDS FOR FOLLOW-UP
  final String? parentId;
  final String consultationType; // 'Initial' or 'Followup'

  final Map<String, dynamic> steps;

  ConsultationSessionModel({
    this.id = '',
    required this.clientId,
    required this.dietitianId,
    this.tenantId, // 🎯 Initialize
    required this.sessionDate,
    required this.startTime,
    this.endTime,
    this.status = 'Ongoing',
    this.linkedVitalsId,
    this.linkedDietPlanId,
    this.parentId,
    this.consultationType = 'Initial',
    this.steps = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'dietitianId': dietitianId,
      'tenantId': tenantId, // 🔒 Save Tenant ID
      'sessionDate': sessionDate,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'linkedVitalsId': linkedVitalsId,
      'linkedDietPlanId': linkedDietPlanId,
      'steps': steps,
      // 🎯 Save New Fields
      'parentId': parentId,
      'consultationType': consultationType,
    };
  }

  factory ConsultationSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Safety check for steps
    Map<String, dynamic> stepsMap = data['steps'] is Map ? Map<String, dynamic>.from(data['steps']) : {};

    // Migration logic for old status fields
    if (!stepsMap.containsKey('clinical') && data['clinicalStatus'] == 'complete') stepsMap['clinical'] = true;
    if (!stepsMap.containsKey('plan') && data['planStatus'] == 'complete') stepsMap['plan'] = true;

    return ConsultationSessionModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      dietitianId: data['dietitianId'] ?? '',
      tenantId: data['tenantId'], // 🔒 Retrieve Tenant ID
      sessionDate: data['sessionDate'] as Timestamp? ?? Timestamp.now(),
      startTime: data['startTime'] as Timestamp? ?? Timestamp.now(),
      endTime: data['endTime'] as Timestamp?,
      status: data['status'] ?? 'Ongoing',
      linkedVitalsId: data['linkedVitalsId'],
      linkedDietPlanId: data['linkedDietPlanId'],
      steps: stepsMap,
      // 🎯 Retrieve New Fields
      parentId: data['parentId'],
      consultationType: data['consultationType'] ?? 'Initial',
    );
  }
}