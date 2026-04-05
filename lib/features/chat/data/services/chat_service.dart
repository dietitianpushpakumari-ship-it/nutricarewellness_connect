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

  // =================================================================
  // 🎯 1. GET MESSAGES (New Flat Architecture)
  // =================================================================
  Stream<List<ChatMessageModel>> getMessages(String clientId) {
    return _firestore
        .collection('clients')
        .doc(clientId)
        .collection('chat') // 🎯 Now points to the correct sub-collection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatMessageModel.fromFirestore(doc)).toList());
  }

  // =================================================================
  // 🎯 2. SEND MESSAGE (With Tenant Security & Uploads)
  // =================================================================
  Future<void> sendMessage({
    required String clientName,
    required String clientId,
    required String tenantId, // 🔒 CRITICAL: Required for Admin Dashboard visibility
    required String text,
    required MessageType type,
    RequestType requestType = RequestType.none,
    Map<String, dynamic>? metadata,
    File? attachmentFile,
    List<File>? attachmentFiles,
    String? attachmentName,
  }) async {
    final clientDocRef = _firestore.collection('clients').doc(clientId);
    final messageRef = clientDocRef.collection('chat').doc();

    // 🎫 GENERATE UNIQUE TICKET ID (Timestamp based)
    String? ticketId;
    if (requestType != RequestType.none) {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      String uniqueId = (timestamp % 10000).toString().padLeft(4, '0');
      ticketId = "TICKET-${requestType.name.toUpperCase()}-$uniqueId";
    }

    // 1. Prepare Local Paths (For Optimistic UI loading)
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
      ticketId: ticketId,
    );

    // 🔒 3. INJECT TENANT ID & SAVE INITIAL STATE
    final messageData = message.toMap();
    messageData['tenantId'] = tenantId; // Allows Admin collectionGroup queries to find this

    await messageRef.set(messageData);

    // 4. UPLOAD LOGIC
    try {
      Map<String, dynamic> updateData = {
        'messageStatus': MessageStatus.sent.name
      };

      // A. Handle Multiple Images (Gallery select)
      if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
        List<String> uploadedUrls = [];

        await Future.wait(attachmentFiles.map((file) async {
          String fName = "img_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}.webp";
          final ref = _storage.ref().child('chat_attachments/$tenantId/$clientId/$fName');
          await ref.putFile(file);
          String url = await ref.getDownloadURL();
          uploadedUrls.add(url);
        }));

        updateData['attachmentUrls'] = uploadedUrls;
        if (uploadedUrls.isNotEmpty) updateData['attachmentUrl'] = uploadedUrls.first;
      }

      // B. Handle Single File (Camera, Audio, PDF)
      else if (attachmentFile != null) {
        final ref = _storage.ref().child('chat_attachments/$tenantId/$clientId/${DateTime.now().millisecondsSinceEpoch}_$attachmentName');
        await ref.putFile(attachmentFile);
        String url = await ref.getDownloadURL();
        updateData['attachmentUrl'] = url;
      }

      // Mark as Sent and attach URLs
      await messageRef.update(updateData);

    } catch (e) {
      print("Upload failed: $e");
      await messageRef.update({'messageStatus': MessageStatus.failed.name});
    }

    // 5. UPDATE PARENT CLIENT DOC (For Admin Inbox Preview)
    String snippet = text;
    if (text.isEmpty) {
      if (type == MessageType.image) snippet = "📷 Photo";
      else if (type == MessageType.audio) snippet = "🎤 Voice Note";
      else if (type == MessageType.file) snippet = "📎 File";
    }

    if (ticketId != null) {
      snippet = "🎫 $ticketId: $snippet";
    }

    await clientDocRef.set({
      'name': clientName,
      'lastMessage': snippet,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'clientId': clientId,
      'tenantId': tenantId, // 🔒 Keep parent synced with tenant
      'hasPendingRequest': requestType != RequestType.none,
    }, SetOptions(merge: true));
  }

  // =================================================================
  // 🎯 3. MESSAGE MANAGEMENT
  // =================================================================

  Future<void> retryMessage(String clientId, ChatMessageModel message) async {
    // Delete the failed message
    await deleteMessage(clientId, message.id);
    // Note: In a full implementation, you would re-call sendMessage here
    // passing the message.localFilePath back in to attempt the upload again.
  }

  Future<void> deleteMessage(String clientId, String messageId) async {
    await _firestore
        .collection('clients')
        .doc(clientId)
        .collection('chat')
        .doc(messageId)
        .delete();
  }
}