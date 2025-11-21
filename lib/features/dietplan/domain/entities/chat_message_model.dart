import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, audio, file, request }
enum RequestType { none, appointment, mealQuery, planRevision, labReport, callback, prioritySupport, general }
enum RequestStatus { pending, approved, rejected, completed }
enum MessageStatus { sending, sent, failed }

class ChatMessageModel {
  final String id;
  final String senderId;
  final bool isSenderClient;
  final String text;
  final MessageType type;
  final DateTime timestamp;

  // Media Fields
  final String? attachmentUrl;
  final String? attachmentName;
  final String? localFilePath; // 🎯 CRITICAL for sending state
  final List<String>? attachmentUrls; // For multi-image
  final List<String>? localFilePaths; // For multi-image sending

  // Request Fields
  final RequestType requestType;
  final RequestStatus requestStatus;
  final Map<String, dynamic>? metadata;
  final MessageStatus messageStatus;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.isSenderClient,
    required this.text,
    required this.type,
    required this.timestamp,
    this.attachmentUrl,
    this.attachmentName,
    this.localFilePath,
    this.attachmentUrls,
    this.localFilePaths,
    this.requestType = RequestType.none,
    this.requestStatus = RequestStatus.pending,
    this.metadata,
    this.messageStatus = MessageStatus.sent,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      isSenderClient: data['isSenderClient'] ?? true,
      text: data['text'] ?? '',
      type: MessageType.values.firstWhere((e) => e.name == (data['type'] ?? 'text'), orElse: () => MessageType.text),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),

      // 🎯 Ensure these are mapped correctly
      attachmentUrl: data['attachmentUrl'],
      attachmentName: data['attachmentName'],
      localFilePath: data['localFilePath'],
      attachmentUrls: data['attachmentUrls'] != null ? List<String>.from(data['attachmentUrls']) : null,
      localFilePaths: data['localFilePaths'] != null ? List<String>.from(data['localFilePaths']) : null,

      requestType: RequestType.values.firstWhere((e) => e.name == (data['requestType'] ?? 'none'), orElse: () => RequestType.none),
      requestStatus: RequestStatus.values.firstWhere((e) => e.name == (data['requestStatus'] ?? 'pending'), orElse: () => RequestStatus.pending),
      metadata: data['metadata'],
      messageStatus: MessageStatus.values.firstWhere((e) => e.name == (data['messageStatus'] ?? 'sent'), orElse: () => MessageStatus.sent),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'isSenderClient': isSenderClient,
      'text': text,
      'type': type.name,
      'timestamp': FieldValue.serverTimestamp(),
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'localFilePath': localFilePath, // 🎯 Ensure this is saved
      'attachmentUrls': attachmentUrls,
      'localFilePaths': localFilePaths,
      'requestType': requestType.name,
      'requestStatus': requestStatus.name,
      'metadata': metadata,
      'messageStatus': messageStatus.name,
    };
  }
}