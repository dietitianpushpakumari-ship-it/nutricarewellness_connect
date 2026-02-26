import 'dart:async';
import 'dart:io';
import 'dart:ui'; // Required for Glassmorphism effects
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/fullscreen_image_viewer.dart';
import 'package:nutricare_connect/new/utils/image_compressor.dart';
import 'package:nutricare_connect/core/utils/pdf_compressor.dart';
import 'package:nutricare_connect/features/chat/data/services/chat_service.dart';
import 'package:nutricare_connect/features/chat/presentation/chat_audio_player.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/chat_message_model.dart';
import 'package:nutricare_connect/new/core/theme_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ClientChatScreen extends ConsumerStatefulWidget {
  final String clientName;

  const ClientChatScreen({super.key, required this.clientName});

  @override
  ConsumerState<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends ConsumerState<ClientChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  // --- State Variables ---
  bool _isRecording = false;
  bool _isUploading = false;
  bool _showSendButton = false;

  // Timer for Audio
  Timer? _recordTimer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      if (mounted) {
        setState(() => _showSendButton = _textController.text.trim().isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  // =================================================================
  // --- 1. SEND LOGIC ---
  // =================================================================

  void _handleSendMessage(ChatService chatService, String clientId, String name) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    await chatService.sendMessage(
      clientName: name,
      clientId: clientId,
      text: text,
      type: MessageType.text,
    );
  }

  Future<void> _handleImageUpload(ChatService service, String clientId, ImageSource source, String name) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);

    if (picked != null) {
      setState(() => _isUploading = true);
      File original = File(picked.path);
      File? compressed = await ImageCompressor.compressAndGetFile(original);

      await service.sendMessage(
        clientName: name,
        clientId: clientId,
        text: "",
        type: MessageType.image,
        attachmentFile: compressed ?? original,
        attachmentName: "photo.webp",
      );
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleFileUpload(String name, ChatService service, String clientId, {bool isReport = false}) async {
    if (!isReport) Navigator.pop(context);

    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);

      File file = File(result.files.single.path!);
      String fname = result.files.single.name;
      String ext = fname.split('.').last.toLowerCase();

      if (['jpg', 'jpeg', 'png'].contains(ext)) {
        File? c = await ImageCompressor.compressAndGetFile(file);
        if (c != null) {
          file = c;
          fname = "${fname.split('.').first}.webp";
        }
      } else if (ext == 'pdf') {
        File? c = await PdfCompressor.compress(file);
        if (c != null) file = c;
      }

      MessageType type = isReport ? MessageType.request : MessageType.file;
      if (['mp3', 'wav', 'm4a', 'aac'].contains(ext)) type = MessageType.audio;

      await service.sendMessage(
        clientName: name,
        clientId: clientId,
        text: isReport ? "Uploaded a Lab Report" : "Shared a file",
        type: type,
        requestType: isReport ? RequestType.labReport : RequestType.none,
        attachmentFile: file,
        attachmentName: fname,
      );
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendQuickMessage(ChatService service, String clientId, String text, RequestType type, String name) {
    service.sendMessage(
      clientName: name,
      clientId: clientId,
      text: text,
      type: MessageType.request,
      requestType: type,
    );
  }

  // =================================================================
  // --- 2. AUDIO RECORDING ---
  // =================================================================

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(const RecordConfig(), path: path);

      _recordDuration = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _recordDuration++));

      setState(() => _isRecording = true);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Microphone permission required")));
    }
  }

  Future<void> _stopRecording(ChatService service, String clientId, String name) async {
    if (!_isRecording) return;
    _recordTimer?.cancel();

    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await service.sendMessage(
          clientName: name,
          clientId: clientId,
          text: "Voice Note",
          type: MessageType.audio,
          attachmentFile: File(path),
          attachmentName: "Voice Note",
        );
      }
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  // =================================================================
  // --- 3. UI BUILD ---
  // =================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final clientId = ref.watch(currentClientIdProvider);
    final chatService = ref.watch(chatServiceProvider);
    final currentUser = ref.read(globalUserProvider);
    final String name = currentUser?.name ?? widget.clientName;

    if (clientId == null) return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: theme.scaffoldBackgroundColor.withOpacity(0.7)),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer.withOpacity(0.4),
              child: Icon(Icons.support_agent_rounded, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Coach', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Online', style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: () => _showRequestBottomSheet(context, chatService, clientId, name, theme, colorScheme, isDark),
              icon: Icon(Icons.bolt_rounded, size: 18, color: colorScheme.primary),
              label: Text("Actions", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: chatService.getMessages(clientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) return _buildEmptyState(theme);

                return ListView.builder(
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    bool showHeader = index == messages.length - 1 || !_isSameDay(msg.timestamp, messages[index + 1].timestamp);

                    final bubble = MessageBubble(
                      key: ValueKey(msg.id),
                      msg: msg,
                      chatService: chatService,
                      clientId: clientId,
                    );

                    if (showHeader) {
                      return Column(children: [_buildDateHeader(msg.timestamp, theme), bubble]);
                    }
                    return bubble;
                  },
                );
              },
            ),
          ),
          if (_isUploading) LinearProgressIndicator(minHeight: 2, color: colorScheme.primary, backgroundColor: Colors.transparent),
          _buildInputArea(chatService, clientId, name, theme, colorScheme, isDark),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatService service, String clientId, String name, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.8),
        border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          if (!_isRecording)
            IconButton(
              icon: Icon(Icons.add_circle_rounded, color: theme.hintColor, size: 28),
              onPressed: () => _showAttachmentOptions(context, service, clientId, name, theme, colorScheme),
            ),
          if (!_isRecording) const SizedBox(width: 8),

          Expanded(
            child: _isRecording
                ? Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(seconds: 1),
                    builder: (context, val, _) => Opacity(
                      opacity: val > 0.5 ? 1 : 0.5,
                      child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                    ),
                    onEnd: () => setState(() {}),
                  ),
                  const SizedBox(width: 12),
                  Text(_formatDuration(_recordDuration), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text("Slide to cancel", style: TextStyle(color: theme.hintColor, fontSize: 12)),
                ],
              ),
            )
                : Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _textController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),

          const SizedBox(width: 12),

          GestureDetector(
            onLongPressStart: (_) async { if (!_showSendButton) await _startRecording(); },
            onLongPressEnd: (_) async { if (!_showSendButton) await _stopRecording(service, clientId, name); },
            onTap: () {
              if (_showSendButton) {
                _handleSendMessage(service, clientId, name);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Hold to Record"), duration: const Duration(milliseconds: 800), backgroundColor: colorScheme.primary));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: _showSendButton
                        ? [colorScheme.primary, colorScheme.primary.withOpacity(0.8)]
                        : [colorScheme.secondary, colorScheme.secondary.withOpacity(0.8)]
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: (_showSendButton ? colorScheme.primary : colorScheme.secondary).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                ],
              ),
              child: Icon(
                _showSendButton ? Icons.arrow_upward_rounded : (_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // 🎯 BOTTOM SHEETS (Themed)
  // =================================================================

  void _showRequestBottomSheet(BuildContext context, ChatService service, String clientId, String name, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    showModalBottomSheet(
      isDismissible: false,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
                Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                const SizedBox(height: 20),
                Flexible(
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildQuickAction(Icons.calendar_today_rounded, "Book New", Colors.purple, () { Navigator.pop(ctx); _showAppointmentRequestDialog(context, service, clientId, name, theme, colorScheme, isReschedule: false); }, theme, colorScheme),
                      _buildQuickAction(Icons.edit_calendar_rounded, "Reschedule", Colors.orange, () { Navigator.pop(ctx); _showAppointmentRequestDialog(context, service, clientId, name, theme, colorScheme, isReschedule: true); }, theme, colorScheme),
                      _buildQuickAction(Icons.restaurant_menu_rounded, "Meal Query", Colors.blue, () { Navigator.pop(ctx); _showMealQueryDialog(context, service, clientId, name, theme, colorScheme, isDark); }, theme, colorScheme),
                      _buildQuickAction(Icons.upload_file_rounded, "Lab Report", Colors.teal, () { Navigator.pop(ctx); _handleFileUpload(name, service, clientId, isReport: true); }, theme, colorScheme),
                      _buildQuickAction(Icons.add_call, "Call Me", Colors.green, () { Navigator.pop(ctx); _sendQuickMessage(service, clientId, "📞 Requesting a callback.", RequestType.callback, name); }, theme, colorScheme),
                      _buildQuickAction(Icons.warning_rounded, "Urgent", Colors.red, () { Navigator.pop(ctx); _sendQuickMessage(service, clientId, "❗ Priority Help Needed", RequestType.prioritySupport, name); }, theme, colorScheme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap, ThemeData theme, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  void _showAppointmentRequestDialog(BuildContext context, ChatService service, String clientId, String name, ThemeData theme, ColorScheme colorScheme, {required bool isReschedule}) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final noteController = TextEditingController();
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      isDismissible: false,
      context: context,
      isScrollControlled: true, // 🎯 Essential for bottom sheets with text fields
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Container(
            // 🎯 Add bottom padding for the keyboard
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor, // 🎯 Themed Background
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // 2. Title & Subtitle
                Text(
                    isReschedule ? "Reschedule Session" : "Request Session",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)
                ),
                const SizedBox(height: 8),
                Text(
                    "Select your preferred date & time.",
                    style: TextStyle(fontSize: 14, color: theme.hintColor)
                ),
                const SizedBox(height: 24),

                // 3. Date Picker Tile
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(DateFormat.yMMMd().format(selectedDate), style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.calendar_month_rounded, color: colorScheme.primary),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030)
                    );
                    if (d != null) setState(() => selectedDate = d);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
                  tileColor: theme.cardColor,
                ),
                const SizedBox(height: 16),

                // 4. Notes Input
                TextField(
                    controller: noteController,
                    style: TextStyle(color: colorScheme.onSurface),
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: "Reason / Preferred Time",
                      labelStyle: TextStyle(color: theme.hintColor),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : theme.cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16),
                    )
                ),
                const SizedBox(height: 32),

                // 5. Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text("Cancel", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold))
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final String typeText = isReschedule ? "Reschedule Request" : "New Appointment Request";
                          service.sendMessage(
                            clientName: name,
                            clientId: clientId,
                            text: "$typeText: ${DateFormat.yMMMd().format(selectedDate)}",
                            type: MessageType.request,
                            requestType: RequestType.appointment,
                            metadata: {
                              'date': selectedDate.toIso8601String(),
                              'note': noteController.text,
                              'isReschedule': isReschedule
                            },
                          );
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                        ),
                        child: const Text("Send Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  void _showMealQueryDialog(BuildContext context, ChatService service, String clientId, String name, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final queryController = TextEditingController();
    List<File> selectedImages = [];
    final List<String> quickTags = ["Is this allowed?", "Portion check", "Good for dinner?", "Too much oil?", "Carb content?", "Protein sufficient?", "Post-workout?", "Eating out"];

    showModalBottomSheet(
      isDismissible: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Meal Query", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      IconButton(icon: Icon(Icons.close, color: theme.hintColor), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text("Upload Meal Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                      const SizedBox(height: 12),
                      if (selectedImages.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(image: FileImage(selectedImages[index]), fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    right: 14, top: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => selectedImages.removeAt(index)),
                                      child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final img = await ImagePicker().pickImage(source: ImageSource.camera);
                                if (img != null) setState(() => selectedImages.add(File(img.path)));
                              },
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: const Text("Camera"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? colorScheme.primaryContainer.withOpacity(0.3) : Colors.blue.shade50,
                                  foregroundColor: colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final List<XFile> imgs = await ImagePicker().pickMultiImage(imageQuality: 80);
                                if (imgs.isNotEmpty) setState(() => selectedImages.addAll(imgs.map((e) => File(e.path))));
                              },
                              icon: const Icon(Icons.photo_library_rounded),
                              label: const Text("Gallery"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                                  foregroundColor: colorScheme.onSurface,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text("Quick Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: quickTags.map((tag) => GestureDetector(
                          onTap: () {
                            final current = queryController.text;
                            queryController.text = current.isEmpty ? tag : "$current, $tag";
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Text(tag, style: TextStyle(fontSize: 12, color: isDark ? Colors.orangeAccent : Colors.orange.shade900, fontWeight: FontWeight.w500)),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text("Notes / Questions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: queryController,
                        maxLines: 5,
                        minLines: 3,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: "Describe ingredients, portion size, or specific concerns...",
                          hintStyle: TextStyle(color: theme.hintColor),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : theme.cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        service.sendMessage(
                          clientName: name,
                          clientId: clientId,
                          text: queryController.text.isEmpty ? "Review my meal" : queryController.text,
                          type: MessageType.request,
                          requestType: RequestType.mealQuery,
                          attachmentFiles: selectedImages,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: const Text("Send Query", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context, ChatService service, String clientId, String name, ThemeData theme, ColorScheme colorScheme) {
    showModalBottomSheet(
      isDismissible: false, // Kept as requested, but added a Cancel button below
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor, // 🎯 Matches other bottom sheets
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5)
                )
              ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle
              const SizedBox(height: 16),
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2))
              ),
              const SizedBox(height: 24),

              // 2. Camera
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt_rounded, color: colorScheme.primary),
                ),
                title: Text('Camera', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () { Navigator.pop(context); _handleImageUpload(service, clientId, ImageSource.camera, name); },
              ),
              Divider(height: 1, color: theme.dividerColor.withOpacity(0.1), indent: 76),

              // 3. Gallery
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                ),
                title: Text('Gallery', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () { Navigator.pop(context); _handleImageUpload(service, clientId, ImageSource.gallery, name); },
              ),
              Divider(height: 1, color: theme.dividerColor.withOpacity(0.1), indent: 76),

              // 4. Document
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.description_rounded, color: Colors.teal),
                ),
                title: Text('Document', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () { Navigator.pop(context); _handleFileUpload(name, service, clientId); },
              ),

              const SizedBox(height: 16),

              // 5. Cancel Button (Prevents user from getting stuck)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        backgroundColor: theme.cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: theme.dividerColor.withOpacity(0.1))
                    ),
                    child: Text("Cancel", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  // --- HELPERS ---
  Widget _buildEmptyState(ThemeData theme) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 60, color: theme.dividerColor.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text("Start a conversation with your coach.", style: TextStyle(color: theme.hintColor)),
      ],
    ),
  );

  Widget _buildDateHeader(DateTime date, ThemeData theme) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    String label = DateFormat.yMMMd().format(date);
    if (d == DateTime(now.year, now.month, now.day)) label = "Today";
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: theme.dividerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  String _formatDuration(int s) => "${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}";
}

// =================================================================
// 🎯 MESSAGE BUBBLE
// =================================================================
class MessageBubble extends StatelessWidget {
  final ChatMessageModel msg;
  final ChatService chatService;
  final String clientId;

  const MessageBubble({super.key, required this.msg, required this.chatService, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMe = msg.isSenderClient;
    final isRequest = msg.type == MessageType.request;
    final isFailed = msg.messageStatus == MessageStatus.failed;
    final isDark = theme.brightness == Brightness.dark;
    final hasMedia = (msg.attachmentUrl != null) || (msg.localFilePath != null) || (msg.attachmentUrls?.isNotEmpty ?? false);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isFailed && isMe)
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.red), onPressed: () => chatService.retryMessage(clientId, msg)),

            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  gradient: isMe ? LinearGradient(
                      colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.85)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight
                  ) : null,
                  color: isMe ? null : theme.cardColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                  ),
                  border: Border.all(
                      color: isMe ? Colors.white.withOpacity(0.1) : theme.dividerColor.withOpacity(0.1)
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isRequest) _buildRequestHeader(msg, isMe, colorScheme, theme),

                    if (hasMedia) ...[
                      if (msg.type == MessageType.audio)
                        ChatAudioPlayer(audioUrl: msg.attachmentUrl, localPath: msg.localFilePath, isSender: isMe)
                      else if (_shouldShowAsImage(msg))
                        _buildImageGrid(context, msg)
                      else
                        _buildFileLink(context, msg, isMe, theme),
                      const SizedBox(height: 6),
                    ],

                    if (msg.text.isNotEmpty)
                      Text(
                        msg.text,
                        style: TextStyle(fontSize: 15, color: isMe ? Colors.white : colorScheme.onSurface, height: 1.4),
                      ),

                    const SizedBox(height: 6),

                    // 🎯 FIXED: Replaced Spacer() with Align to prevent RenderFlex errors
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('h:mm a').format(msg.timestamp),
                            style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : theme.hintColor),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isFailed ? Icons.error_outline_rounded : (msg.messageStatus == MessageStatus.sending ? Icons.access_time_rounded : Icons.done_all_rounded),
                              size: 12, color: isFailed ? Colors.red.shade200 : Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestHeader(ChatMessageModel msg, bool isMe, ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : colorScheme.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getRequestIcon(msg.requestType), size: 14, color: isMe ? Colors.white : colorScheme.secondary),
            const SizedBox(width: 6),
            // 🎯 FIXED: Wrapped Text in Flexible to prevent overflow on long action names
            Flexible(
              child: Text(
                msg.requestType.name.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isMe ? Colors.white : colorScheme.secondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (msg.ticketId != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : colorScheme.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(msg.ticketId!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isMe ? Colors.white : colorScheme.secondary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context, ChatMessageModel msg) {
    final locals = msg.localFilePaths ?? (msg.localFilePath != null ? [msg.localFilePath!] : []);
    final remotes = msg.attachmentUrls ?? (msg.attachmentUrl != null ? [msg.attachmentUrl!] : []);
    int count = locals.length > remotes.length ? locals.length : remotes.length;

    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(count, (index) {
          String? localPath = (index < locals.length) ? locals[index] : null;
          String? remoteUrl = (index < remotes.length) ? remotes[index] : null;
          bool isLocalAvailable = localPath != null && File(localPath).existsSync();

          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                        imageUrl: remoteUrl,
                        localPath: isLocalAvailable ? localPath : null
                    )
                )
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: count > 1 ? 100 : 200,
                height: count > 1 ? 100 : 180,
                child: Builder(
                  builder: (context) {
                    if (isLocalAvailable) {
                      return Image.file(
                        File(localPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          if (remoteUrl != null) {
                            return CachedNetworkImage(
                              imageUrl: remoteUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.black12),
                              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                            );
                          }
                          return const Icon(Icons.broken_image_rounded, color: Colors.grey);
                        },
                      );
                    } else if (remoteUrl != null) {
                      return CachedNetworkImage(
                        imageUrl: remoteUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.black12),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                      );
                    } else {
                      return Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey));
                    }
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFileLink(BuildContext context, ChatMessageModel msg, bool isMe, ThemeData theme) {
    return InkWell(
      onTap: () => launchUrlString(msg.attachmentUrl!, mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : theme.dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.description_rounded, color: isMe ? Colors.white : theme.hintColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(msg.attachmentName ?? "Document", style: TextStyle(decoration: TextDecoration.underline, color: isMe ? Colors.white : Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowAsImage(ChatMessageModel msg) {
    if (msg.type == MessageType.image) return true;
    String? path = msg.attachmentName ?? msg.localFilePath ?? msg.attachmentUrl;
    if (path == null) return false;
    final ext = path.split('?').first.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);
  }

  IconData _getRequestIcon(RequestType t) {
    switch (t) {
      case RequestType.mealQuery: return Icons.restaurant_rounded;
      case RequestType.appointment: return Icons.calendar_month_rounded;
      case RequestType.labReport: return Icons.science_rounded;
      case RequestType.prioritySupport: return Icons.warning_amber_rounded;
      default: return Icons.star_rounded;
    }
  }
}