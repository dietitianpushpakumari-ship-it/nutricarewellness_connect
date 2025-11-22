import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/chat_message_model.dart';

final chatServiceProvider = Provider((ref) => ChatService());

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<ChatMessageModel>> getMessages(String clientId) {
    return _firestore
        .collection('chats')
        .doc(clientId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatMessageModel.fromFirestore(doc)).toList());
  }

  // 🎯 SEND MESSAGE
  Future<void> sendMessage({
    required String clientName,
    required String clientId,
    required String text,
    required MessageType type,
    RequestType requestType = RequestType.none,
    Map<String, dynamic>? metadata,
    File? attachmentFile,
    List<File>? attachmentFiles,
    String? attachmentName,
  }) async {
    final chatDocRef = _firestore.collection('chats').doc(clientId);
    final messageRef = chatDocRef.collection('messages').doc();

    // 🎯 GENERATE UNIQUE TICKET ID (Timestamp based)
    String? ticketId;
    if (requestType != RequestType.none) {
      // Get current time in milliseconds
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      // Extract the last 4 digits (e.g., ...1234) to ensure uniqueness + brevity
      String uniqueId = (timestamp % 10000).toString().padLeft(4, '0');

      ticketId = "TICKET-${requestType.name.toUpperCase()}-$uniqueId";
    }

    // 1. Prepare Local Paths
    List<String>? localPaths;
    if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
      localPaths = attachmentFiles.map((f) => f.path).toList();
    } else if (attachmentFile != null) {
      localPaths = [attachmentFile.path];
    }

    // 2. Create "Sending" Model
    final message = ChatMessageModel(
      id: messageRef.id,
      senderId: clientId,
      isSenderClient: true,
      text: text,
      type: type,
      timestamp: DateTime.now(),
      requestType: requestType,
      metadata: metadata,
      messageStatus: MessageStatus.sending,
      localFilePath: attachmentFile?.path,
      localFilePaths: localPaths,
      attachmentName: attachmentName,
      ticketId: ticketId, // Save the timestamp-based ID
    );

    await messageRef.set(message.toMap());

    // 3. Upload Logic
    try {
      Map<String, dynamic> updateData = {
        'messageStatus': MessageStatus.sent.name
      };

      // A. Handle Multiple Images
      if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
        List<String> uploadedUrls = [];

        await Future.wait(attachmentFiles.map((file) async {
          String fName = "img_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}.webp";
          final ref = _storage.ref().child('chat_attachments/$clientId/$fName');
          await ref.putFile(file);
          String url = await ref.getDownloadURL();
          uploadedUrls.add(url);
        }));

        updateData['attachmentUrls'] = uploadedUrls;
        if (uploadedUrls.isNotEmpty) updateData['attachmentUrl'] = uploadedUrls.first;
      }

      // B. Handle Single File
      else if (attachmentFile != null) {
        final ref = _storage.ref().child('chat_attachments/$clientId/${DateTime.now().millisecondsSinceEpoch}_$attachmentName');
        await ref.putFile(attachmentFile);
        String url = await ref.getDownloadURL();
        updateData['attachmentUrl'] = url;
      }

      await messageRef.update(updateData);

    } catch (e) {
      print("Upload failed: $e");
      await messageRef.update({'messageStatus': MessageStatus.failed.name});
    }

    // 4. Update Dashboard Summary
    String snippet = text;
    if (text.isEmpty) {
      if (type == MessageType.image) snippet = "📷 Photo";
      else if (type == MessageType.audio) snippet = "🎤 Voice Note";
      else if (type == MessageType.file) snippet = "📎 File";
    }

    if (ticketId != null) {
      snippet = "🎫 $ticketId: $snippet";
    }

    await chatDocRef.set({
      'name':clientName,
      'lastMessage': snippet,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'clientId': clientId,
      'hasPendingRequest': requestType != RequestType.none,
    }, SetOptions(merge: true));
  }

  // Retry Logic
  Future<void> retryMessage(String clientId, ChatMessageModel message) async {
    await deleteMessage(clientId, message.id);
    // In a real app, you'd re-trigger sendMessage here using the localFilePath data
  }

  Future<void> deleteMessage(String clientId, String messageId) async {
    await _firestore.collection('chats').doc(clientId).collection('messages').doc(messageId).delete();
  }
}