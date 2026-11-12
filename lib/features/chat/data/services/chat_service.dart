import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ensure this matches your actual path for Cloudinary
import 'package:pure_shift/core/utils/CloudinaryService.dart';
import 'package:pure_shift/core/utils/database_provider.dart';
import 'package:pure_shift/features/auth/auth_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/chat_message_model.dart';
final chatLimitProvider = StateProvider.autoDispose<int>((ref) => 40);
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref);
});

class ChatService {
  final Ref _ref;
  ChatService(this._ref);

  FirebaseFirestore get _firestore => _ref.read(firestoreProvider);

  // =================================================================
  // 🔒 CLIENT CONTEXT HELPERS
  // =================================================================

  String get _clientId {
    // 🚀 FIXED: Using your actual auth profile instead of the placeholder
    final client = _ref.read(authNotifierProvider).clientProfile;
    if (client == null || client.id.isEmpty) throw Exception("🔒 Unauthorized: Missing Client Context");
    return client.id;
  }

  String get _tenantId {
    // 🚀 FIXED: Using your actual auth profile instead of the placeholder
    final client = _ref.read(authNotifierProvider).clientProfile;
    if (client == null) throw Exception("🔒 Unauthorized: Missing Tenant Context");
    return client.tenantId ?? 'guest';
  }

  // =================================================================
  // 🎯 1. CHAT MESSAGES STREAM
  // =================================================================

  Stream<List<ChatMessageModel>> getMessages(int limit) {
    final client = _ref.read(authNotifierProvider).clientProfile;

    if (client == null || client.id.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('clients')
        .doc(client.id)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .limit(limit) // 🚀 2. Injecting the dynamic limit here
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChatMessageModel.fromFirestore(doc))
        .toList());
  }

  // =================================================================
  // 🎯 2. SEND MESSAGE (WITH CLOUDINARY)
  // =================================================================
  Future<void> sendClientMessage({
    required String text,
    required MessageType type,
    XFile? attachmentFile, // 🚀 2. CHANGE TO XFile HERE
    String? attachmentName,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToAttachmentUrl,
  }) async {
    final clientId = _clientId;
    final tenantId = _tenantId;
    String? attachmentUrl;

    // 🚀 CLOUDINARY UPLOAD LOGIC (WEB-SAFE)
    if (attachmentFile != null) {
      final cloudinaryService = _ref.read(cloudinaryServiceProvider);
      final folderPath = 'tenants/$tenantId/clients/$clientId/chat_images';

      if (kIsWeb) {
        // 🌐 WEB UPLOAD: Extract raw memory bytes directly from the XFile
        final bytes = await attachmentFile.readAsBytes();
        attachmentUrl = await cloudinaryService.uploadWebFile(
          bytes: bytes,
          fileName: attachmentName ?? 'file_${DateTime.now().millisecondsSinceEpoch}',
          folderName: folderPath,
        );
      }
      else {
        // 📱 NATIVE UPLOAD: Convert XFile back to dart:io File
        attachmentUrl = await cloudinaryService.uploadFile(
          file: File(attachmentFile.path),
          folderName: folderPath,
        );
      }

      if (attachmentUrl == null || attachmentUrl.isEmpty) {
        throw Exception("Failed to upload attachment to Cloudinary.");
      }
    }

    final messageDocRef = _firestore
        .collection('clients')
        .doc(clientId)
        .collection('chat')
        .doc();

    final Map<String, dynamic> messageData = {
      'id': messageDocRef.id,
      'senderId': clientId,
      'isSenderClient': true,
      'text': text,
      'type': type.name,
      'timestamp': FieldValue.serverTimestamp(),
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'isRead': false,
      'replyToMessageId': replyToMessageId,
      'replyToMessageText': replyToMessageText,
      'replyToAttachmentUrl': replyToAttachmentUrl,
      'tenantId': tenantId,
    };

    final batch = _firestore.batch();
    batch.set(messageDocRef, messageData);

    batch.set(_firestore.collection('clients').doc(clientId), {
      'lastMessage': type == MessageType.text ? text : "📎 Sent an attachment",
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // =================================================================
  // ✏️ 3. EDIT MESSAGE
  // =================================================================

  Future<void> editMessage(String messageId, String newText) async {
    try {
      await _firestore
          .collection('clients')
          .doc(_clientId)
          .collection('chat')
          .doc(messageId)
          .update({
        'text': newText,
        'isEdited': true, // Triggers the 'Edited' tag in the UI
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error editing message: $e");
      throw Exception("Failed to edit message");
    }
  }

  // =================================================================
  // 🗑️ 4. DELETE MESSAGE
  // =================================================================

  Future<void> deleteMessage(String messageId) async {
    try {
      // Hard delete: completely removes the document
      await _firestore
          .collection('clients')
          .doc(_clientId)
          .collection('chat')
          .doc(messageId)
          .delete();

      // Optional Soft Delete (Uncomment if you prefer "This message was deleted"):
      /*
      await _firestore.collection('clients').doc(_clientId).collection('chat').doc(messageId).update({
        'text': '🚫 This message was deleted',
        'isDeleted': true,
        'attachmentUrl': FieldValue.delete(),
        'type': MessageType.text.name,
      });
      */
    } catch (e) {
      debugPrint("Error deleting message: $e");
      throw Exception("Failed to delete message");
    }
  }

  // =================================================================
  // 👁️ 5. MARK MESSAGES AS READ (READ RECEIPTS)
  // =================================================================

  Future<void> markMessagesAsRead() async {
    try {
      final unreadDocs = await _firestore
          .collection('clients')
          .doc(_clientId)
          .collection('chat')
          .where('isSenderClient', isEqualTo: false) // Only target Admin's messages
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error marking messages as read: $e");
    }
  }
}