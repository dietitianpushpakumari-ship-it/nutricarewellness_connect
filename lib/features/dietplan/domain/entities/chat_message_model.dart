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

  // Media
  final String? attachmentUrl;
  final String? attachmentName;
  final String? localFilePath;
  final List<String>? attachmentUrls;
  final List<String>? localFilePaths;

  // Request Data
  final RequestType requestType;
  final RequestStatus requestStatus;
  final Map<String, dynamic>? metadata;
  final MessageStatus messageStatus;

  // 🎯 NEW: Ticket ID
  final String? ticketId;

  // Reply Link
  final String? replyToMessageId;
  final String? replyToMessageText;
  final MessageType? replyToMessageType;

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
    this.ticketId,            // 🆕
    this.replyToMessageId,
    this.replyToMessageText,
    this.replyToMessageType,
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

      attachmentUrl: data['attachmentUrl'],
      attachmentName: data['attachmentName'],
      localFilePath: data['localFilePath'],
      attachmentUrls: data['attachmentUrls'] != null ? List<String>.from(data['attachmentUrls']) : null,
      localFilePaths: data['localFilePaths'] != null ? List<String>.from(data['localFilePaths']) : null,

      requestType: RequestType.values.firstWhere((e) => e.name == (data['requestType'] ?? 'none'), orElse: () => RequestType.none),
      requestStatus: RequestStatus.values.firstWhere((e) => e.name == (data['requestStatus'] ?? 'pending'), orElse: () => RequestStatus.pending),
      metadata: data['metadata'],
      messageStatus: MessageStatus.values.firstWhere((e) => e.name == (data['messageStatus'] ?? 'sent'), orElse: () => MessageStatus.sent),

      ticketId: data['ticketId'], // 🆕

      replyToMessageId: data['replyToMessageId'],
      replyToMessageText: data['replyToMessageText'],
      replyToMessageType: data['replyToMessageType'] != null ? MessageType.values.firstWhere((e) => e.name == data['replyToMessageType'], orElse: () => MessageType.text) : null,
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
      'localFilePath': localFilePath,
      'attachmentUrls': attachmentUrls,
      'localFilePaths': localFilePaths,
      'requestType': requestType.name,
      'requestStatus': requestStatus.name,
      'metadata': metadata,
      'messageStatus': messageStatus.name,
      'ticketId': ticketId, // 🆕
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToMessageType': replyToMessageType?.name,
    };
  }
}