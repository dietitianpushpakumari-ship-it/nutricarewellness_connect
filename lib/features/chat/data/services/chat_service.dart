import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/image_compressor.dart';
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

  // 🎯 Send Message with Optimistic UI (Sending -> Sent/Failed)
  Future<void> sendMessage({
    required String clientId,
    required String text,
    required MessageType type,
    RequestType requestType = RequestType.none,
    Map<String, dynamic>? metadata,
    File? attachmentFile,         // Single (Audio/Doc)
    List<File>? attachmentFiles,  // 🆕 Multiple (Images)
    String? attachmentName,
  }) async {
    final chatDocRef = _firestore.collection('chats').doc(clientId);
    final messageRef = chatDocRef.collection('messages').doc();

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
      // Store single file data for backward compat / non-image types
      localFilePath: attachmentFile?.path,
      attachmentName: attachmentName,
      // Store list data for multiple images
      localFilePaths: localPaths,
    );

    await messageRef.set(message.toMap());

    // 3. Upload Logic
    try {
      Map<String, dynamic> updateData = {'messageStatus': MessageStatus.sent.name};

      // A. Handle Multiple Images
      if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
        List<String> uploadedUrls = [];

        // Upload all in parallel
        await Future.wait(attachmentFiles.map((file) async {
          // Compress first
          File? compressed = await ImageCompressor.compressAndGetFile(file);
          File fileToSend = compressed ?? file;

          String fName = "img_${DateTime.now().millisecondsSinceEpoch}_${file.hashCode}.webp";
          final ref = _storage.ref().child('chat_attachments/$clientId/$fName');
          await ref.putFile(fileToSend);
          String url = await ref.getDownloadURL();
          uploadedUrls.add(url);
        }));

        updateData['attachmentUrls'] = uploadedUrls;
        // Set the first image as the main 'attachmentUrl' for backward compatibility
        if (uploadedUrls.isNotEmpty) updateData['attachmentUrl'] = uploadedUrls.first;
      }

      // B. Handle Single File (Audio/PDF)
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

    // 4. Update Summary
    String snippet = text;
    if (text.isEmpty) {
      if (type == MessageType.image) snippet = "📷 Photo(s)";
      else if (type == MessageType.audio) snippet = "🎤 Voice Note";
      else if (type == MessageType.file) snippet = "📎 File";
    }

    await chatDocRef.set({
      'lastMessage': snippet,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'clientId': clientId,
      'hasPendingRequest': requestType != RequestType.none,
    }, SetOptions(merge: true));
  }

  // 🎯 Retry Logic
  Future<void> retryMessage(String clientId, ChatMessageModel message) async {
    if (message.localFilePath != null) {
      final file = File(message.localFilePath!);
      if (await file.exists()) {
        await sendMessage(
            clientId: clientId, text: message.text, type: message.type,
            requestType: message.requestType, metadata: message.metadata,
            attachmentFile: file, attachmentName: message.attachmentName
        );
        await deleteMessage(clientId, message.id); // Remove failed copy
      }
    } else if (message.type == MessageType.text) {
      await sendMessage(clientId: clientId, text: message.text, type: message.type);
      await deleteMessage(clientId, message.id);
    }
  }

  Future<void> deleteMessage(String clientId, String messageId) async {
    await _firestore.collection('chats').doc(clientId).collection('messages').doc(messageId).delete();
  }
}