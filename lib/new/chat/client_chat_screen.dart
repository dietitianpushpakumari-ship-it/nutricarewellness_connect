import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_shift/core/utils/pdf_viewer_screen.dart';
import 'package:pure_shift/features/auth/auth_provider.dart';
import 'package:pure_shift/layout_utils.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:pure_shift/features/chat/data/services/chat_service.dart';
import 'package:pure_shift/features/dietplan/domain/entities/chat_message_model.dart';
import 'package:pure_shift/new/utils/image_compressor.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/chat/presentation/chat_audio_player.dart';

const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class ClientChatScreen extends ConsumerStatefulWidget {
  const ClientChatScreen({super.key});
  @override
  ConsumerState<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends ConsumerState<ClientChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessageModel> _allMessages = []; // 🚀 Added to cache messages for dynamic scrolling

  bool _isUploading = false;
  bool _isTyping = false;

  ChatMessageModel? _replyMessage;
  ChatMessageModel? _editMessage;
  final Map<String, GlobalKey> _messageKeys = {};

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  String _recordingDuration = "00:00";

  // 🚀 UPGRADED: Multi-Image Attachment Support
  final List<File> _pendingAttachments = [];
  MessageType? _pendingAttachmentType;
  String? _pendingAttachmentName;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() => _isTyping = _textController.text.trim().isNotEmpty);
    });
    _scrollController.addListener(_scrollListener);
  }
  void _scrollListener() {
    // If the user scrolls within 200 pixels of the top (older messages)
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final currentLimit = ref.read(chatLimitProvider);

      // Prevent infinite requests: Only increase the limit if we actually hit the current limit.
      // (If _allMessages.length is less than currentLimit, it means we reached the very beginning of the chat history)
      if (_allMessages.length >= currentLimit) {
        ref.read(chatLimitProvider.notifier).state = currentLimit + 30; // Load 30 more
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _cancelReplyOrEdit() {
    HapticFeedback.selectionClick();
    setState(() {
      _replyMessage = null;
      if (_editMessage != null) {
        _editMessage = null;
        _textController.clear();
      }
    });
  }

  void _clearPendingAttachments() {
    setState(() {
      _pendingAttachments.clear();
      _pendingAttachmentType = null;
      _pendingAttachmentName = null;
    });
  }

  // =========================================================================
  // 🚀 NON-BLOCKING UPLOAD LOGIC (FIRE-AND-FORGET)
  // =========================================================================

  void _triggerSend(ChatService service) {
    final text = _textController.text.trim();

    if (_isTyping || _editMessage != null || _pendingAttachments.isNotEmpty) {
      HapticFeedback.lightImpact();

      if (_editMessage != null) {
        service.editMessage(_editMessage!.id, text);
        _textController.clear();
        _cancelReplyOrEdit();
        return;
      }

      // 1. Capture the exact state of what the user wants to send
      final capturedText = text;
      final capturedAttachments = List<File>.from(_pendingAttachments);
      final capturedType = _pendingAttachmentType;
      final capturedName = _pendingAttachmentName;
      final capturedReply = _replyMessage;

      // 2. INSTANTLY CLEAR THE UI SO THE USER CAN KEEP TYPING
      _textController.clear();
      _clearPendingAttachments();
      _cancelReplyOrEdit();
      setState(() => _isTyping = false);

      // 3. PASS THE DATA TO THE BACKGROUND UPLOADER (Do not use 'await' here!)
      _processAndUploadInBackground(
          service,
          capturedText,
          capturedAttachments,
          capturedType,
          capturedName,
          capturedReply
      );
    }
  }

  Future<void> _processAndUploadInBackground(
      ChatService service,
      String text,
      List<File> attachments,
      MessageType? type,
      String? name,
      ChatMessageModel? replyTo,
      ) async {
    setState(() => _isUploading = true); // Shows the thin loading bar above the input

    try {
      if (attachments.isNotEmpty && type != null) {
        for (var file in attachments) {
          File finalFile = file;

          // Compress in background
          if (type == MessageType.image) {
            final compressed = await ImageCompressor.compressAndGetFile(file);
            if (compressed != null) finalFile = compressed;
          }

          // Upload to Firebase
          await service.sendClientMessage(
            text: text, // Caption
            type: type,
            attachmentFile: finalFile,
            attachmentName: name ?? "IMG_${DateTime.now().millisecondsSinceEpoch}.webp",
            replyToMessageId: replyTo?.id,
            replyToMessageText: replyTo?.text ?? "Attachment",
          );
        }
      } else if (text.isNotEmpty) {
        await service.sendClientMessage(
          text: text,
          type: MessageType.text,
          replyToMessageId: replyTo?.id,
          replyToMessageText: replyTo?.text,
        );
      }

      _triggerPushNotification(text.isNotEmpty ? text : "Sent an attachment 📎");
    } catch (e) {
      debugPrint("Upload failed: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send message.")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

// 🚀 THE FIX: Read FCM Token instantly from RAM (Zero Firebase Costs!)
  Future<void> _triggerPushNotification(String bodyText) async {
    try {
      // 1. Get the Client's profile (already in RAM)
      final clientProfile = ref.read(clientProfileFutureProvider).valueOrNull;

      if (clientProfile == null || clientProfile.coachId == null || clientProfile.coachId!.isEmpty) {
        debugPrint("Client has no assigned coach to notify.");
        return;
      }

      // 2. Get the Coach's profile (already cached in RAM from the Dashboard!)
      final coachProfile = ref.read(dietitianProfileProvider(clientProfile.coachId!)).valueOrNull;

      // 3. Extract the token directly from the model
      final coachToken = coachProfile?.fcmToken;

      if (coachToken != null && coachToken.isNotEmpty) {

        // 4. Fire the notification!
        await ref.read(dietRepositoryProvider).sendPushNotification(
          token: coachToken,
          title: "New message from ${clientProfile.name}",
          body: bodyText,
          data: {
            'route': 'chat',
            'clientId': clientProfile.id ?? '', // Tells the Admin app which chat to open!
          },
        );

      } else {
        debugPrint("Could not find Coach FCM token in the provider state.");
      }
    } catch (e) {
      debugPrint("Push Notification Trigger Failed: $e");
    }
  }
  // =========================================================================
  // 🎙️ VOICE RECORDING LOGIC
  // =========================================================================
  Future<void> _startRecording() async {
    if (_editMessage != null) return;
    HapticFeedback.mediumImpact();
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/client_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
          _recordingDuration = "00:00";
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
          if (_recordingStartTime != null) {
            final duration = DateTime.now().difference(_recordingStartTime!);
            setState(() {
              _recordingDuration = "${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
            });
          }
        });
      }
    } catch (e) {
      debugPrint("Recording Error: $e");
    }
  }

  Future<void> _stopRecordingAndSend(ChatService service) async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path != null) {
      HapticFeedback.heavyImpact();
      final file = File(path);

      // Use the background uploader for audio too!
      _processAndUploadInBackground(
        service,
        "",
        [file],
        MessageType.audio,
        "Voice_Note_${DateTime.now().millisecondsSinceEpoch}.m4a",
        _replyMessage,
      );

      _cancelReplyOrEdit();
    }
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingDuration = "00:00";
    });
  }

  // =========================================================================
  // 📸 ATTACHMENT LOGIC
  // =========================================================================
  void _onAddAttachment(ChatService service) async {
    HapticFeedback.selectionClick();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(12), context.scale(24), context.scale(32)),
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(32))), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: context.scale(36), height: context.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(context.scale(2)))),
              SizedBox(height: context.scale(24)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSheetOption(ctx, Icons.camera_alt_rounded, "Camera", Colors.pinkAccent, () async {
                    Navigator.pop(ctx);
                    _handleImageSelection(service, isCamera: true);
                  }, theme),
                  _buildSheetOption(ctx, Icons.photo_library_rounded, "Gallery", Colors.purpleAccent, () async {
                    Navigator.pop(ctx);
                    _handleImageSelection(service, isCamera: false);
                  }, theme),
                  _buildSheetOption(ctx, Icons.picture_as_pdf_rounded, "Document", Colors.orangeAccent, () async {
                    Navigator.pop(ctx);
                    _handleDocumentSelection(service);
                  }, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetOption(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
              width: context.scale(56), height: context.scale(56),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.2))),
              child: Icon(icon, color: color, size: context.scale(24))
          ),
          SizedBox(height: context.scale(8)),
          Text(label, style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Future<void> _handleImageSelection(ChatService service, {required bool isCamera}) async {
    try {
      final picker = ImagePicker();

      if (isCamera) {
        final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (pickedFile != null) {
          setState(() {
            _pendingAttachments.add(File(pickedFile.path));
            _pendingAttachmentType = MessageType.image;
          });
        }
      } else {
        final pickedFiles = await picker.pickMultiImage(imageQuality: 80);
        if (pickedFiles.isNotEmpty) {
          setState(() {
            _pendingAttachments.addAll(pickedFiles.map((x) => File(x.path)));
            _pendingAttachmentType = MessageType.image;
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to attach image(s): $e")));
    }
  }

  Future<void> _handleDocumentSelection(ChatService service) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pendingAttachments.clear();
        _pendingAttachments.add(File(result.files.single.path!));
        _pendingAttachmentType = MessageType.document;
        _pendingAttachmentName = result.files.single.name;
      });
    }
  }

  void _showMessageOptions(ChatMessageModel msg, ChatService service) {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMe = msg.isSenderClient;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(12), context.scale(24), context.scale(24)),
          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(32))), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: context.scale(36), height: context.scale(4), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(context.scale(2)))),
              SizedBox(height: context.scale(24)),
              _buildMenuAction(ctx, "Reply", Icons.reply_rounded, () {
                Navigator.pop(ctx);
                setState(() { _replyMessage = msg; _editMessage = null; });
              }, theme, cs),
              if (msg.text.isNotEmpty)
                _buildMenuAction(ctx, "Copy", Icons.copy_rounded, () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied to clipboard", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11))), backgroundColor: cs.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(12)))));
                }, theme, cs),
              if (isMe && msg.type == MessageType.text)
                _buildMenuAction(ctx, "Edit", Icons.edit_rounded, () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editMessage = msg;
                    _replyMessage = null;
                    _textController.text = msg.text;
                    _isTyping = true;
                  });
                }, theme, cs),
              if (isMe)
                _buildMenuAction(ctx, "Delete", Icons.delete_outline_rounded, () {
                  Navigator.pop(ctx);
                  _confirmDelete(msg, service, theme, cs);
                }, theme, cs, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuAction(BuildContext context, String title, IconData icon, VoidCallback onTap, ThemeData theme, ColorScheme cs, {bool isDestructive = false}) {
    final color = isDestructive ? cs.error : cs.onSurface;
    return ListTile(
      leading: Container(padding: EdgeInsets.all(context.scale(8)), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: context.scale(18), color: color)),
      title: Text(title, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(12), fontWeight: FontWeight.w600, color: color)),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  void _confirmDelete(ChatMessageModel msg, ChatService service, ThemeData theme, ColorScheme cs) {
    showDialog(
        context: context,
        builder: (ctx) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(24))),
            title: Text("Delete Message", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(14), fontWeight: FontWeight.w700, color: cs.error)),
            content: Text("This message will be permanently deleted for everyone in this chat.", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(12), color: theme.hintColor, height: 1.5)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11), fontWeight: FontWeight.w700, color: theme.hintColor))),
              FilledButton(
                  onPressed: () {
                    service.deleteMessage(msg.id);
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(backgroundColor: cs.error, elevation: 0),
                  child: Text("DELETE", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(11), fontWeight: FontWeight.w700))
              ),
            ],
          ),
        )
    );
  }

  // 🚀 FIXED: Dynamic Index Scrolling
  void _scrollToMessage(String targetId) {
    HapticFeedback.selectionClick();
    final int index = _allMessages.indexWhere((m) => m.id == targetId);

    if (index != -1) {
      _scrollController.animateTo(
          index * 100.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic
      ).then((_) {
        final key = _messageKeys[targetId];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, alignment: 0.5);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Original message is too far up to scroll to.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(chatServiceProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final chatAccessState = ref.watch(clientProfileFutureProvider);
    final bool isChatEnabled = chatAccessState.valueOrNull?.chatEnabled ?? false;
    final chatLimit = ref.watch(chatLimitProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
        leadingWidth: context.scale(48),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface, size: context.scale(18)),
          onPressed: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: context.scale(16),
              backgroundColor: cs.primary.withOpacity(0.1),
              child: Icon(Icons.support_agent_rounded, color: cs.primary, size: context.scale(18)),
            ),
            SizedBox(width: context.scale(12)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Coach Pushpa", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: context.scale(14))),
                Row(
                  children: [
                    Container(width: context.scale(6), height: context.scale(6), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    SizedBox(width: context.scale(4)),
                    Text("Online", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: context.scale(10), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: theme.dividerColor.withOpacity(0.1), height: 1),
        ),
      ),
      body: SafeArea(
        top: false, bottom: true,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessageModel>>(
                // 🚀 Pass the dynamic limit to the service
                stream: service.getMessages(chatLimit),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2));

                  _allMessages = snapshot.data!;

                  if (_allMessages.isNotEmpty) {
                    bool hasUnreadCoachMsgs = _allMessages.any((m) => !m.isSenderClient && !m.isRead);
                    if (hasUnreadCoachMsgs) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => service.markMessagesAsRead());
                    }
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    cacheExtent: 1500, // 🚀 Enhanced cache extent
                    physics: const BouncingScrollPhysics(),
                    addAutomaticKeepAlives: true, // 🚀 Keeps bubbles in memory
                    addRepaintBoundaries: true,
                    padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(8)),
                    itemCount: _allMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _allMessages[index];
                      final msgKey = _messageKeys.putIfAbsent(msg.id, () => GlobalKey());
                      return Dismissible(
                        key: ValueKey(msg.id),
                        direction: DismissDirection.startToEnd,
                        movementDuration: const Duration(milliseconds: 200),
                        resizeDuration: null,
                        confirmDismiss: (direction) async {
                          HapticFeedback.selectionClick();
                          setState(() { _replyMessage = msg; _editMessage = null; });
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(left: context.scale(20)),
                          child: Container(padding: EdgeInsets.all(context.scale(8)), decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.reply_rounded, size: context.scale(18), color: cs.primary)),
                        ),
                        child: Container(
                          key: msgKey,
                          child: ClientMessageBubble(
                            msg: msg,
                            allMessages: _allMessages, // 🚀 Pass all messages for thumbnail lookup
                            onReplyTap: _scrollToMessage,
                            onLongPress: () => _showMessageOptions(msg, service),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_isUploading) LinearProgressIndicator(minHeight: context.scale(2), backgroundColor: theme.scaffoldBackgroundColor, color: cs.primary),

            if (isChatEnabled)
              _buildInputArea(context, service, theme, cs)
            else
              _buildChatLockedOverlay(context, theme)
          ],
        ),
      ),
    );
  }

  Widget _buildChatLockedOverlay(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(context.scale(20), context.scale(24), context.scale(20), context.scale(24)),
      decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05),
              blurRadius: 20, offset: const Offset(0, -5),
            )
          ]
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(context.scale(12)),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.lock_clock_rounded, color: Colors.orange, size: context.scale(28)),
            ),
            SizedBox(height: context.scale(12)),
            Text(
              "Chat Support Paused",
              style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.bold, fontSize: context.scale(16), color: theme.colorScheme.onSurface),
            ),
            SizedBox(height: context.scale(4)),
            Text(
              "Your consultation package has ended. Renew to continue chatting with Coach Pushpa.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(12), color: theme.hintColor),
            ),
            SizedBox(height: context.scale(16)),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Redirecting to Packages...", style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(12)))));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(12))),
                  padding: EdgeInsets.symmetric(horizontal: context.scale(24), vertical: context.scale(12))
              ),
              child: Text("VIEW PACKAGES", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.bold, fontSize: context.scale(12))),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatService service, ThemeData theme, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(context.scale(12), context.scale(10), context.scale(12), context.scale(24)),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1)))),
      child: _isRecording
          ? _buildRecordingBar(context, service, theme, cs)
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // 🚀 1. REPLY PREVIEW UI
          if (_replyMessage != null)
            Container(
                margin: EdgeInsets.only(bottom: context.scale(8)),
                padding: EdgeInsets.symmetric(horizontal: context.scale(12), vertical: context.scale(8)),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(context.scale(12)),
                  border: Border(left: BorderSide(color: cs.primary, width: 4)),
                ),
                child: Row(
                    children: [
                      Icon(Icons.reply_rounded, size: context.scale(16), color: cs.primary),
                      SizedBox(width: context.scale(8)),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Replying to ${_replyMessage!.isSenderClient ? 'Yourself' : 'Coach Pushpa'}",
                                    style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.bold, color: cs.primary, fontSize: context.scale(11))
                                ),
                                SizedBox(height: context.scale(2)),
                                Text(
                                    _replyMessage!.text.isNotEmpty ? _replyMessage!.text : 'Attachment',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(12), color: theme.colorScheme.onSurface)
                                ),
                              ]
                          )
                      ),

                      // Show thumbnail if it's an image
                      if (_replyMessage!.attachmentUrl != null && _replyMessage!.type == MessageType.image)
                        Container(
                          margin: EdgeInsets.only(right: context.scale(8)),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(context.scale(6)), border: Border.all(color: theme.dividerColor.withOpacity(0.2))),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(context.scale(6)),
                              child: CachedNetworkImage(
                                imageUrl: _replyMessage!.attachmentUrl!, width: context.scale(36), height: context.scale(36), fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: theme.dividerColor.withOpacity(0.1)),
                              )
                          ),
                        )
                      else if (_replyMessage!.type == MessageType.document)
                        Container(
                          margin: EdgeInsets.only(right: context.scale(8)), width: context.scale(36), height: context.scale(36),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(context.scale(6))),
                          child: Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: context.scale(18)),
                        ),

                      IconButton(icon: Icon(Icons.close_rounded, size: context.scale(18), color: theme.hintColor), onPressed: () => setState(() => _replyMessage = null), padding: EdgeInsets.zero, constraints: const BoxConstraints())
                    ]
                )
            ),

          // 🚀 2. MULTI-IMAGE ATTACHMENT PREVIEW TRAY
          if (_pendingAttachments.isNotEmpty)
            Container(
              height: context.scale(60),
              margin: EdgeInsets.only(bottom: context.scale(8)),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: EdgeInsets.only(right: context.scale(8)),
                        width: context.scale(60),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(context.scale(12)),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                          image: _pendingAttachmentType == MessageType.image
                              ? DecorationImage(image: FileImage(_pendingAttachments[index]), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _pendingAttachmentType != MessageType.image
                            ? Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: context.scale(20)))
                            : null,
                      ),
                      Positioned(
                        top: context.scale(2), right: context.scale(10),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _pendingAttachments.removeAt(index);
                              if (_pendingAttachments.isEmpty) _clearPendingAttachments();
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: Icon(Icons.close, size: context.scale(14), color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // 🚀 3. THE ACTUAL TEXT INPUT ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_editMessage == null)
                Padding(
                  padding: EdgeInsets.only(bottom: context.scale(4), right: context.scale(8)),
                  child: GestureDetector(
                    onTap: () { HapticFeedback.lightImpact(); _onAddAttachment(service); },
                    child: Container(
                      height: context.scale(40), width: context.scale(40),
                      decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle, border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
                      child: Icon(Icons.add_rounded, color: theme.hintColor, size: context.scale(24)),
                    ),
                  ),
                ),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(context.scale(24)),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _textController,
                    minLines: 1, maxLines: 5,
                    style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(14), color: cs.onSurface),
                    decoration: InputDecoration(
                        hintText: _pendingAttachments.isNotEmpty ? "Add a caption..." : "Message...",
                        hintStyle: TextStyle(fontFamily: kBodyFont, color: theme.hintColor.withOpacity(0.5), fontSize: context.scale(14)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(10))
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.scale(8)),

              GestureDetector(
                onLongPress: _startRecording,
                onLongPressUp: () => _stopRecordingAndSend(service),
                onTap: () => _triggerSend(service), // 🚀 FIRES THE NON-BLOCKING TRIGGER
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: context.scale(44), width: context.scale(44),
                  decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  child: Center(
                    child: Icon(
                      (_isTyping || _editMessage != null || _pendingAttachments.isNotEmpty)
                          ? (_editMessage != null ? Icons.check_rounded : Icons.send_rounded)
                          : Icons.mic_rounded,
                      color: cs.onPrimary, size: context.scale(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar(BuildContext context, ChatService service, ThemeData theme, ColorScheme cs) {
    return Container(
      height: context.scale(44),
      padding: EdgeInsets.symmetric(horizontal: context.scale(8)),
      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(context.scale(30)), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(height: context.scale(32), width: context.scale(32), decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle), child: Icon(Icons.delete_outline_rounded, size: context.scale(18), color: Colors.redAccent)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: context.scale(8), height: context.scale(8), decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.6), blurRadius: 8)])),
                SizedBox(width: context.scale(12)),
                Text(_recordingDuration, style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: context.scale(14), color: Colors.redAccent)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _stopRecordingAndSend(service),
            child: Container(height: context.scale(36), width: context.scale(36), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: Icon(Icons.send_rounded, color: Colors.white, size: context.scale(16))),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 💬 MESSAGE BUBBLE WIDGET
// ============================================================================
class ClientMessageBubble extends StatelessWidget {
  final ChatMessageModel msg;
  final List<ChatMessageModel> allMessages;
  final Function(String) onReplyTap;
  final VoidCallback onLongPress;

  const ClientMessageBubble({
    super.key,
    required this.msg,
    required this.allMessages,
    required this.onReplyTap,
    required this.onLongPress
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMe = msg.isSenderClient;

    bool hasText = msg.text.trim().isNotEmpty;
    bool isImageOnly = !hasText && msg.type == MessageType.image;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(bottom: context.scale(6)),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),

          padding: EdgeInsets.all(isImageOnly ? context.scale(4) : context.scale(10)),
          decoration: BoxDecoration(
            color: isMe ? cs.primary : theme.cardColor,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(context.scale(18)),
                topRight: Radius.circular(context.scale(18)),
                bottomLeft: Radius.circular(isMe ? context.scale(18) : context.scale(4)),
                bottomRight: Radius.circular(isMe ? context.scale(4) : context.scale(18))
            ),
            border: isMe ? null : Border.all(color: theme.dividerColor.withOpacity(0.08)),
            boxShadow: isMe && !isImageOnly ? [BoxShadow(color: cs.primary.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.replyToMessageId != null) _buildReplyPreview(context, theme, isMe, cs),

              if (isImageOnly)
                Stack(
                    children: [
                      _buildMediaPreview(context, theme, isMe, cs),
                      Positioned(
                          bottom: context.scale(6),
                          right: context.scale(6),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: context.scale(6), vertical: context.scale(3)),
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(context.scale(10))
                            ),
                            child: _buildTimestamp(context, theme, isMe, cs, isOverlay: true),
                          )
                      )
                    ]
                )
              else ...[
                _buildMediaPreview(context, theme, isMe, cs),
                if (hasText) Text(msg.text, style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(13), color: isMe ? cs.onPrimary : cs.onSurface, height: 1.3)),
                SizedBox(height: context.scale(4)),
                Align(alignment: Alignment.bottomRight, child: _buildTimestamp(context, theme, isMe, cs, isOverlay: false)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, ThemeData theme, bool isMe, ColorScheme cs, {required bool isOverlay}) {
    final timeColor = isOverlay ? Colors.white : (isMe ? cs.onPrimary.withOpacity(0.7) : theme.hintColor);
    final tickColor = isOverlay
        ? (msg.isRead ? Colors.lightBlueAccent : Colors.white70)
        : (msg.isRead ? Colors.blue.shade200 : cs.onPrimary.withOpacity(0.6));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(DateFormat('h:mm a').format(msg.timestamp), style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(9), color: timeColor, fontWeight: FontWeight.w700)),
        if (isMe) ...[
          SizedBox(width: context.scale(4)),
          Icon(msg.isRead ? Icons.done_all_rounded : Icons.done_rounded, size: context.scale(12), color: tickColor)
        ]
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context, ThemeData theme, bool isMe, ColorScheme cs) {
    ChatMessageModel? originalMessage;
    try {
      originalMessage = allMessages.firstWhere((m) => m.id == msg.replyToMessageId);
    } catch (_) {
      originalMessage = null;
    }

    final String? thumbnailUrl = originalMessage?.attachmentUrl;
    final bool hasThumbnail = thumbnailUrl != null && originalMessage?.type == MessageType.image;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onReplyTap(msg.replyToMessageId!),
      child: Container(
        margin: EdgeInsets.only(bottom: context.scale(6)),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            color: isMe ? cs.onPrimary.withOpacity(0.15) : cs.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(context.scale(8)),
            border: Border(left: BorderSide(color: isMe ? cs.onPrimary.withOpacity(0.6) : cs.primary, width: context.scale(3)))
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(context.scale(8.0)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isMe ? "You" : "Coach", style: TextStyle(fontFamily: kDisplayFont, fontSize: context.scale(10), fontWeight: FontWeight.w700, color: isMe ? cs.onPrimary : cs.primary)),
                      SizedBox(height: context.scale(2)),
                      Text(
                          msg.replyToMessageText?.isNotEmpty == true ? msg.replyToMessageText! : "Attachment",
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), color: isMe ? cs.onPrimary.withOpacity(0.9) : cs.onSurface.withOpacity(0.8))
                      ),
                    ],
                  ),
                ),
              ),

              if (hasThumbnail)
                Container(
                  width: context.scale(48),
                  decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.05)),
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SizedBox.shrink(),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(Icons.insert_drive_file_rounded, size: context.scale(20), color: isMe ? cs.onPrimary.withOpacity(0.7) : theme.hintColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context, ThemeData theme, bool isMe, ColorScheme cs) {
    if (msg.type == MessageType.audio || (msg.attachmentName != null && (msg.attachmentName!.endsWith('.m4a') || msg.attachmentName!.endsWith('.mp3')))) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.scale(6.0)),
        child: ChatAudioPlayer(audioUrl: msg.attachmentUrl ?? (msg.attachmentUrls?.isNotEmpty == true ? msg.attachmentUrls!.first : null), isSender: isMe),
      );
    }

    if (msg.attachmentUrl != null && msg.type == MessageType.image) {
      return Padding(
        padding: EdgeInsets.only(bottom: msg.text.trim().isEmpty ? 0 : context.scale(6)),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: msg.attachmentUrl!)));
          },
          // 🚀 THE FIX: Added ClipRRect back so corners stay rounded
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.scale(14)),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: context.scale(220),
                maxHeight: context.scale(300),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: msg.attachmentUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 600, // 🚀 Saves RAM on scroll
                  placeholder: (context, url) => Container(
                    color: isMe ? cs.onPrimary.withOpacity(0.1) : theme.dividerColor.withOpacity(0.1),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: isMe ? cs.onPrimary : cs.primary)),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded),
                  fadeInDuration: const Duration(milliseconds: 300),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (msg.attachmentUrl != null && msg.type == MessageType.document) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfUrl: msg.attachmentUrl!, title: msg.attachmentName ?? "Document")));
        },
        child: Container(
          margin: EdgeInsets.only(bottom: context.scale(6)),
          padding: EdgeInsets.all(context.scale(12)),
          decoration: BoxDecoration(
              color: isMe ? cs.onPrimary.withOpacity(0.15) : theme.dividerColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(context.scale(12))
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: isMe ? cs.onPrimary : Colors.redAccent, size: context.scale(24)),
              SizedBox(width: context.scale(10)),
              Flexible(
                  child: Text(
                      msg.attachmentName ?? "Document",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: kBodyFont, fontSize: context.scale(11), fontWeight: FontWeight.w600, color: isMe ? cs.onPrimary : cs.onSurface)
                  )
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ============================================================================
// 🔍 FULL SCREEN IMAGE VIEWER
// ============================================================================
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true, minScale: 1.0, maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl, fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 50),
          ),
        ),
      ),
    );
  }



}



// 🚀 THE FIX: Push Notification Trigger
