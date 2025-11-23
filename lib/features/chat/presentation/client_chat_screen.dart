import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/fullscreen_image_viewer.dart';
import 'package:nutricare_connect/core/utils/image_compressor.dart';
import 'package:nutricare_connect/core/utils/pdf_compressor.dart';
import 'package:nutricare_connect/features/chat/data/services/chat_service.dart';
import 'package:nutricare_connect/features/chat/presentation/chat_audio_player.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/chat_message_model.dart';
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
    final clientId = ref.watch(currentClientIdProvider);
    final chatService = ref.watch(chatServiceProvider);
    final currentUser = ref.read(globalUserProvider);
    final String name = currentUser?.name ?? widget.clientName ?? 'Client';

    if (clientId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE0E7FF),
              child: Icon(Icons.support_agent, color: Colors.indigo),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Coach', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Online', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              onPressed: () => _showRequestBottomSheet(context, chatService, clientId, name),
              icon: const Icon(Icons.flash_on_rounded, size: 16),
              label: const Text("Actions"),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessageModel>>(
                stream: chatService.getMessages(clientId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) return _buildEmptyState();
        
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      bool showHeader = false;
                      if (index == messages.length - 1) {
                        showHeader = true;
                      } else {
                        final nextMsg = messages[index + 1];
                        if (!_isSameDay(msg.timestamp, nextMsg.timestamp)) showHeader = true;
                      }
        
                      final bubble = MessageBubble(
                        key: ValueKey(msg.id),
                        msg: msg,
                        chatService: chatService,
                        clientId: clientId,
                      );
        
                      if (showHeader) {
                        return Column(children: [_buildDateHeader(msg.timestamp), bubble]);
                      }
                      return bubble;
                    },
                  );
                },
              ),
            ),
            if (_isUploading) const LinearProgressIndicator(minHeight: 2, color: Colors.indigo),
            _buildInputArea(chatService, clientId, name),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatService service, String clientId, String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          if (!_isRecording)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.grey, size: 28),
              onPressed: () => _showAttachmentOptions(context, service, clientId, name),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (!_isRecording) const SizedBox(width: 12),

          Expanded(
            child: _isRecording
                ? Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.red.shade100),
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
                  const Text("Release to send", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
                : Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
          ),

          const SizedBox(width: 12),

          GestureDetector(
            onLongPressStart: (_) async {
              if (!_showSendButton) await _startRecording();
            },
            onLongPressEnd: (_) async {
              if (!_showSendButton) await _stopRecording(service, clientId, name);
            },
            onTap: () {
              if (_showSendButton) {
                _handleSendMessage(service, clientId, name);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hold to Record"), duration: Duration(milliseconds: 800)));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : (_showSendButton ? Colors.indigo : Colors.teal),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : Colors.indigo).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(
                _showSendButton ? Icons.arrow_upward : (_isRecording ? Icons.stop : Icons.mic),
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
  // 🎯 REVAMPED: QUICK ACTIONS MENU (Bento Grid)
  // =================================================================
  void _showRequestBottomSheet(BuildContext context, ChatService service, String clientId, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.0,
                  children: [
                    _buildQuickAction(Icons.calendar_today, "Book New", Colors.purple, () {
                      Navigator.pop(ctx);
                      _showAppointmentRequestDialog(context, service, clientId, name, isReschedule: false);
                    }),
                    // 🎯 NEW: Reschedule Button
                    _buildQuickAction(Icons.edit_calendar, "Reschedule", Colors.orange, () {
                      Navigator.pop(ctx);
                      _showAppointmentRequestDialog(context, service, clientId, name, isReschedule: true);
                    }),
                    _buildQuickAction(Icons.restaurant_menu, "Meal Query", Colors.blue, () {
                      Navigator.pop(ctx);
                      _showMealQueryDialog(context, service, clientId, name);
                    }),
                    _buildQuickAction(Icons.upload_file, "Lab Report", Colors.teal, () {
                      Navigator.pop(ctx);
                      _handleFileUpload(name, service, clientId, isReport: true);
                    }),
                    _buildQuickAction(Icons.add_call, "Call Me", Colors.green, () {
                      Navigator.pop(ctx);
                      _sendQuickMessage(service, clientId, "📞 Requesting a callback.", RequestType.callback, name);
                    }),
                    _buildQuickAction(Icons.warning_rounded, "Urgent", Colors.red, () {
                      Navigator.pop(ctx);
                      _sendQuickMessage(service, clientId, "❗ Priority Help Needed", RequestType.prioritySupport, name);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 Update the Dialog to handle Rescheduling logic
  void _showAppointmentRequestDialog(BuildContext context, ChatService service, String clientId, String name, {required bool isReschedule}) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isReschedule ? "Reschedule Session" : "Request Session"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select your preferred date:", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              ListTile(
                title: Text(DateFormat.yMMMd().format(selectedDate)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                  if (d != null) setState(() => selectedDate = d);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
              ),
              const SizedBox(height: 10),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: "Reason / Preferred Time")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
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
              child: const Text("Send Request"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey.shade100),
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
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // =================================================================
  // 🎯 REVAMPED: MEAL QUERY DIALOG (Full Bottom Sheet)
  // =================================================================
  void _showMealQueryDialog(BuildContext context, ChatService service, String clientId, String name) {
    final queryController = TextEditingController();
    List<File> selectedImages = [];

    final List<String> quickTags = [
      "Is this allowed?",
      "Portion check",
      "Good for dinner?",
      "Too much oil?",
      "Carb content?",
      "Protein sufficient?",
      "Post-workout?",
      "Eating out"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Full height
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => SafeArea(child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Header
              const SizedBox(height: 16),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),

              // Title & Close
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Meal Query", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 1. Photo Selection
                    const Text("Upload Meal Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

                    // 🎯 DUAL BUTTONS: Camera & Gallery
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final img = await ImagePicker().pickImage(source: ImageSource.camera);
                              if (img != null) setState(() => selectedImages.add(File(img.path)));
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Camera"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
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
                            icon: const Icon(Icons.photo_library),
                            label: const Text("Gallery"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 2. Quick Tags
                    const Text("Quick Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Text(tag, style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w500)),
                        ),
                      )).toList(),
                    ),

                    const SizedBox(height: 24),

                    // 3. Large Text Input
                    const Text("Notes / Questions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: queryController,
                      maxLines: 5,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: "Describe ingredients, portion size, or specific concerns...",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Send Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
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
        ),),
      ),
    );
  }

  // ... (Other dialogs like Custom Query & Attachments remain clean bottom sheets) ...
// =================================================================
  // 🎯 REVAMPED: CUSTOM QUERY SHEET
  // =================================================================
  void _showCustomQueryDialog(BuildContext context, ChatService service, String clientId, String name) {
    final controller = TextEditingController();

    // 🎯 New: Quick Topics to help users start typing
    final List<String> topics = [
      "Supplement help",
      "Digestion issue",
      "Feeling weak",
      "Cravings",
      "Travel tips",
      "Recipe request"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Full height for keyboard
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => SafeArea(child: Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Handle & Header
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text("Ask a Question", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              const Text("Select a topic or type your question below.", style: TextStyle(color: Colors.grey, fontSize: 14)),

              const SizedBox(height: 20),

              // 2. Topic Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topics.map((topic) => GestureDetector(
                  onTap: () {
                    // Append topic to text field
                    final current = controller.text;
                    if (current.isEmpty) {
                      controller.text = "$topic: ";
                    } else {
                      controller.text = "$current\n$topic: ";
                    }
                    // Move cursor to end
                    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Text(topic, style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w600)),
                  ),
                )).toList(),
              ),

              const SizedBox(height: 24),

              // 3. Input Area
              TextField(
                controller: controller,
                maxLines: 5,
                minLines: 3,
                autofocus: true,
                style: const TextStyle(fontSize: 16, height: 1.4),
                decoration: InputDecoration(
                  hintText: "Type your message here...",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 24),

              // 4. Send Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (controller.text.trim().isNotEmpty) {
                      service.sendMessage(
                        clientName: name,
                        clientId: clientId,
                        text: controller.text.trim(),
                        type: MessageType.request,
                        requestType: RequestType.general,
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 20),
                  label: const Text("Send Message", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),)
      ),
    );
  }
  void _showAttachmentOptions(BuildContext context, ChatService service, String clientId, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.indigo),
              title: const Text('Camera'),
              onTap: () { Navigator.pop(context); _handleImageUpload(service, clientId, ImageSource.camera, name); },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Gallery'),
              onTap: () { Navigator.pop(context); _handleImageUpload(service, clientId, ImageSource.gallery, name); },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.teal),
              title: const Text('Document'),
              onTap: () { Navigator.pop(context); _handleFileUpload(name, service, clientId); },
            ),
          ],
        ),
      ),
    );
  }


  // --- HELPERS ---
  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text("Start a conversation with your coach.", style: TextStyle(color: Colors.grey)),
      ],
    ),
  );

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    String label = DateFormat.yMMMd().format(date);
    if (d == DateTime(now.year, now.month, now.day)) label = "Today";
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  String _formatDuration(int s) => "${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}";
}

// =================================================================
// 🎯 MESSAGE BUBBLE (Same as before)
// =================================================================
class MessageBubble extends StatelessWidget {
  final ChatMessageModel msg;
  final ChatService chatService;
  final String clientId;

  const MessageBubble({super.key, required this.msg, required this.chatService, required this.clientId});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isSenderClient;
    final isRequest = msg.type == MessageType.request;
    final isFailed = msg.messageStatus == MessageStatus.failed;
    final hasMedia = (msg.attachmentUrl != null) || (msg.localFilePath != null) || (msg.attachmentUrls?.isNotEmpty ?? false);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isFailed && isMe)
            IconButton(icon: const Icon(Icons.refresh, color: Colors.red), onPressed: () => chatService.retryMessage(clientId, msg)),

          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                gradient: isMe ? const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF00897B)]) : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                border: isRequest ? Border.all(color: Colors.orange.shade200) : null,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRequest)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getRequestIcon(msg.requestType), size: 14, color: isMe ? Colors.white70 : Colors.orange.shade800),
                          const SizedBox(width: 4),
                          Text(msg.requestType.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMe ? Colors.white70 : Colors.orange.shade800)),
                          if (msg.ticketId != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(msg.ticketId!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.orange.shade900)),
                            ),
                          ],
                        ],
                      ),
                    ),

                  if (hasMedia) ...[
                    if (msg.type == MessageType.audio)
                      ChatAudioPlayer(audioUrl: msg.attachmentUrl, localPath: msg.localFilePath, isSender: isMe)
                    else if (_shouldShowAsImage(msg))
                      _buildImageGrid(context, msg)
                    else
                      _buildFileLink(context, msg, isMe),
                    const SizedBox(height: 4),
                  ],

                  if (msg.text.isNotEmpty)
                    Text(msg.text, style: TextStyle(fontSize: 15, color: isMe ? Colors.white : Colors.black87, height: 1.4)),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Text(DateFormat('h:mm a').format(msg.timestamp), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey.shade400)),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(isFailed ? Icons.error : (msg.messageStatus == MessageStatus.sending ? Icons.access_time : Icons.done_all), size: 12, color: isFailed ? Colors.red : Colors.white70),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// 🎯 FIX: Smart Image Loader with Fallback
  Widget _buildImageGrid(BuildContext context, ChatMessageModel msg) {
    // 1. Get both local paths and remote URLs lists
    final locals = msg.localFilePaths ?? (msg.localFilePath != null ? [msg.localFilePath!] : []);
    final remotes = msg.attachmentUrls ?? (msg.attachmentUrl != null ? [msg.attachmentUrl!] : []);

    // 2. Determine the total number of images to show
    // (We take the max length to ensure we show everything, even if one list is incomplete)
    int count = locals.length > remotes.length ? locals.length : remotes.length;

    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(count, (index) {
          // Get the pair (Local Path, Remote URL) for this index
          String? localPath = (index < locals.length) ? locals[index] : null;
          String? remoteUrl = (index < remotes.length) ? remotes[index] : null;

          // 3. Check if the local file actually exists on this device right now
          bool isLocalAvailable = localPath != null && File(localPath).existsSync();

          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      // Prefer remote for sharing/viewing if available, otherwise try local
                        imageUrl: remoteUrl,
                        localPath: isLocalAvailable ? localPath : null
                    )
                )
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                // Dynamic sizing: Big if single image, grid if multiple
                width: count > 1 ? 100 : 200,
                height: count > 1 ? 100 : 180,
                child: Builder(
                  builder: (context) {
                    // A. Try Local File First (if it exists)
                    if (isLocalAvailable) {
                      return Image.file(
                        File(localPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // 🎯 FALLBACK 1: If Image.file fails (e.g. permission/corrupt), try Remote
                          if (remoteUrl != null) {
                            return CachedNetworkImage(
                              imageUrl: remoteUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.black12),
                              errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                            );
                          }
                          return const Icon(Icons.broken_image, color: Colors.grey);
                        },
                      );
                    }

                    // B. If Local missing, use Remote URL
                    else if (remoteUrl != null) {
                      return CachedNetworkImage(
                        imageUrl: remoteUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.black12),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    }

                    // C. If neither exists (shouldn't happen), show error
                    else {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      );
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
  Widget _buildFileLink(BuildContext context, ChatMessageModel msg, bool isMe) {
    return InkWell(
      onTap: () => launchUrlString(msg.attachmentUrl!, mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(Icons.description, color: isMe ? Colors.white : Colors.grey.shade700),
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
      case RequestType.mealQuery: return Icons.restaurant;
      case RequestType.appointment: return Icons.calendar_month;
      case RequestType.labReport: return Icons.science;
      case RequestType.prioritySupport: return Icons.warning_amber_rounded;
      default: return Icons.star;
    }
  }
}