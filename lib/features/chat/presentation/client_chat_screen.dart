import 'dart:async' show Timer;
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
import 'package:nutricare_connect/features/dietplan/domain/entities/chat_message_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';



class ClientChatScreen extends ConsumerStatefulWidget {
  final String clientName;
  const ClientChatScreen({super.key, required this.clientName});

  @override
  ConsumerState<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends ConsumerState<ClientChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;
  bool _isUploading = false;
  bool _showSendButton = false;
  String? _recordedPath;
  int _recordDuration = 0;

  // 🎯 3. ADD TIMER VARIABLES
  Timer? _recordTimer;      // Requires 'dart:async'
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
    super.dispose();
  }

  // =================================================================
  // --- 1. SEND LOGIC ---
  // =================================================================

  void _handleSendMessage(ChatService chatService, String clientId) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await chatService.sendMessage(clientId: clientId, text: text, type: MessageType.text);
  }

  // 📸 Image Upload
  Future<void> _handleImageUpload(ChatService service, String clientId, ImageSource source) async {
    // Close bottom sheet first if open (check handled by caller usually, but safe to call pop if sheet is top)
    // Navigator.pop(context);

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);

    if (picked != null) {
      setState(() => _isUploading = true);
      File original = File(picked.path);
      File? compressed = await ImageCompressor.compressAndGetFile(original);

      await service.sendMessage(
          clientId: clientId,
          text: "",
          type: MessageType.image,
          attachmentFile: compressed ?? original,
          attachmentName: "photo.webp"
      );
      if(mounted) setState(() => _isUploading = false);
    }
  }

  // 📎 File Upload (PDF, Doc, Audio)
  Future<void> _handleFileUpload(ChatService service, String clientId, {bool isReport = false}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);

      File file = File(result.files.single.path!);
      String name = result.files.single.name;
      String ext = name.split('.').last.toLowerCase();

      if (['jpg', 'jpeg', 'png'].contains(ext)) {
        File? c = await ImageCompressor.compressAndGetFile(file);
        if(c != null) { file = c; name = "${name.split('.').first}.webp"; }
      } else if (ext == 'pdf') {
        File? c = await PdfCompressor.compress(file);
        if(c != null) file = c;
      }

      MessageType type = isReport ? MessageType.request : MessageType.file;
      if(['mp3', 'wav', 'm4a', 'aac'].contains(ext)) type = MessageType.audio;

      await service.sendMessage(
          clientId: clientId,
          text: isReport ? "Uploaded a Lab Report" : "Shared a file",
          type: type,
          requestType: isReport ? RequestType.labReport : RequestType.none,
          attachmentFile: file,
          attachmentName: name
      );
      if(mounted) setState(() => _isUploading = false);
    }
  }

  // ⚡ Quick Message
  void _sendQuickMessage(ChatService service, String clientId, String text, RequestType type) {
    service.sendMessage(clientId: clientId, text: text, type: MessageType.request, requestType: type);
  }

  // =================================================================
  // --- 2. QUICK ACTIONS & DIALOGS ---
  // =================================================================

  void _showRequestBottomSheet(BuildContext context, ChatService service, String clientId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _buildQuickBtn("Meal Query", Icons.restaurant, Colors.orange, () {
                      Navigator.pop(sheetContext);
                      _showMealQueryDialog(context, service, clientId);
                    }),
                    _buildQuickBtn("Appointment", Icons.calendar_month, Colors.purple, () {
                      Navigator.pop(sheetContext);
                      _showAppointmentRequestDialog(context, service, clientId);
                    }),
                    _buildQuickBtn("Upload Report", Icons.science, Colors.blue, () {
                      Navigator.pop(sheetContext);
                      _handleFileUpload(service, clientId, isReport: true);
                    }),
                    _buildQuickBtn("Plan Revision", Icons.sync, Colors.teal, () {
                      Navigator.pop(sheetContext);
                      _sendQuickMessage(service, clientId, "🔄 I need a revision in my current diet plan.", RequestType.planRevision);
                    }),
                    _buildQuickBtn("Call Me", Icons.call, Colors.green, () {
                      Navigator.pop(sheetContext);
                      _sendQuickMessage(service, clientId, "📞 Please call me back when available.", RequestType.callback);
                    }),
                    _buildQuickBtn("Priority Help", Icons.warning_rounded, Colors.red, () {
                      Navigator.pop(sheetContext);
                      _sendQuickMessage(service, clientId, "❗ I need priority support.", RequestType.prioritySupport);
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

  // 🥗 Meal Query Dialog
  void _showMealQueryDialog(BuildContext context, ChatService service, String clientId) {
    final queryController = TextEditingController();
    List<File> selectedImages = [];
    final List<String> quickTags = ["Is this allowed?", "Portion size?", "Good for dinner?", "Eating out"];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Meal Query"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image List
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ...selectedImages.map((file) => Stack(children: [
                    Image.file(file, width: 70, height: 70, fit: BoxFit.cover),
                    Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => setState(() => selectedImages.remove(file)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white))))
                  ])),
                  IconButton(icon: const Icon(Icons.add_a_photo), onPressed: () async {
                    final List<XFile> imgs = await ImagePicker().pickMultiImage(imageQuality: 80);
                    if(imgs.isNotEmpty) setState(() => selectedImages.addAll(imgs.map((e)=>File(e.path))));
                  }),
                  IconButton(icon: const Icon(Icons.camera_alt), onPressed: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                    if(img != null) setState(() => selectedImages.add(File(img.path)));
                  })
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 6, runSpacing: 6, children: quickTags.map((tag) => InkWell(onTap: () => queryController.text = tag, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade100)), child: Text(tag, style: TextStyle(fontSize: 11, color: Colors.orange.shade800))))).toList()),
                const SizedBox(height: 16),
                TextField(controller: queryController, decoration: const InputDecoration(hintText: "Details...", border: OutlineInputBorder()), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await service.sendMessage(
                    clientId: clientId,
                    text: queryController.text.isEmpty ? "Review my meal" : queryController.text,
                    type: MessageType.request,
                    requestType: RequestType.mealQuery,
                    attachmentFiles: selectedImages
                );
              },
              child: const Text("Send"),
            )
          ],
        ),
      ),
    );
  }

  // 📅 Appointment Dialog
  void _showAppointmentRequestDialog(BuildContext context, ChatService service, String clientId) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final noteController = TextEditingController();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text("Request Appointment"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ElevatedButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2026)); if(d!=null) setState(()=>selectedDate=d); }, child: Text(DateFormat.yMMMd().format(selectedDate))),
        TextField(controller: noteController, decoration: const InputDecoration(labelText: "Note")),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")), FilledButton(onPressed: () {
        Navigator.pop(ctx);
        service.sendMessage(clientId: clientId, text: "Requesting Appt: ${DateFormat.yMMMd().format(selectedDate)}", type: MessageType.request, requestType: RequestType.appointment, metadata: {'date': selectedDate.toIso8601String(), 'note': noteController.text});
      }, child: const Text("Request"))],
    )));
  }

  // 📎 Attachment Options
  void _showAttachmentOptions(BuildContext context, ChatService service, String clientId) {
    showModalBottomSheet(context: context, builder: (sheetContext) => Wrap(children: [
      ListTile(leading: const Icon(Icons.camera), title: const Text('Camera'), onTap: () { Navigator.pop(sheetContext); _handleImageUpload(service, clientId, ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.image), title: const Text('Gallery'), onTap: () { Navigator.pop(sheetContext); _handleImageUpload(service, clientId, ImageSource.gallery); }),
      ListTile(leading: const Icon(Icons.attach_file), title: const Text('File'), onTap: () { Navigator.pop(sheetContext); _handleFileUpload(service, clientId); }),
    ]));
  }

  // =================================================================
  // --- 3. UI BUILD & INPUT ---
  // =================================================================

  @override
  Widget build(BuildContext context) {
    final clientId = ref.watch(currentClientIdProvider);
    final chatService = ref.watch(chatServiceProvider);

    if (clientId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Dietitian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Online', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              onPressed: () => _showRequestBottomSheet(context, chatService, clientId),
              icon: const Icon(Icons.flash_on_rounded, size: 16),
              label: const Text("Quick Actions"),
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 12)),
            ),
          )
        ],
      ),
      body: Column(
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
                  cacheExtent: 1000, // Optimizes scrolling
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    // Date Header Logic
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
                        clientId: clientId
                    );

                    if (showHeader) return Column(children: [_buildDateHeader(msg.timestamp), bubble]);
                    return bubble;
                  },
                );
              },
            ),
          ),
          if (_isUploading) const LinearProgressIndicator(minHeight: 2, color: Colors.green),
          _buildInputArea(chatService, clientId),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatService service, String clientId) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          if (!_isRecording)
     //       IconButton(
       //       icon: const Icon(Icons.add_circle, color: Colors.blueGrey, size: 28),
         //     onPressed: () => _showAttachmentOptions(context, service, clientId),
           // ),
            const SizedBox(width: 8),
          Expanded(
            child: _isRecording
            // 🔴 RECORDING STATE (With Timer)
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(24)
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Text(
                      _formatRecordTime(_recordDuration), // 🎯 Show Timer
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  const Spacer(),
                  const Text("Release to Send", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
            // ⚪ NORMAL STATE
                : TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Message',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),

          const SizedBox(width: 8),

          // Mic/Send Button
          GestureDetector(
            onLongPress: _showSendButton ? null : _startRecording,
            onLongPressUp: _showSendButton ? null : () => _stopRecording(service, clientId),
            onTap: () => _showSendButton
                ? _handleSendMessage(service, clientId)
                : ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hold to Record 🎙️"))),
            child: CircleAvatar(
              backgroundColor: _isRecording ? Colors.red : (_showSendButton ? Colors.indigo : Colors.teal),
              radius: 24,
              child: Icon(
                _showSendButton ? Icons.send : (_isRecording ? Icons.stop : Icons.mic),
                color: Colors.white, size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(const RecordConfig(), path: path);

      // 🎯 Start Timer
      _recordDuration = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordDuration++);
      });

      setState(() {
        _isRecording = true;
        _recordedPath = path;
      });
    }
  }

  // --- STOP RECORDING ---
  Future<void> _stopRecording(ChatService service, String clientId) async {
    if (!_isRecording) return;

    _recordTimer?.cancel(); // 🎯 Stop Timer

    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        await service.sendMessage(
            clientId: clientId,
            text: "Voice Note", // Fallback text
            type: MessageType.audio,
            attachmentFile: File(path),
            attachmentName: "Voice Note"
        );
      }
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  // Helper to format 65 seconds -> "01:05"
  String _formatRecordTime(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return "$min:$sec";
  }
  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    String label = DateFormat.yMMMd().format(date);
    if (d == today) label = "Today"; else if (d == yesterday) label = "Yesterday";
    return Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[800], fontWeight: FontWeight.bold))));
  }
  bool _isSameDay(DateTime d1, DateTime d2) => d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  Widget _buildQuickBtn(String label, IconData icon, Color color, VoidCallback onTap) => InkWell(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]));
  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey), SizedBox(height: 16), Text("Start a conversation.")]));
}

// =================================================================
// 🎯 OPTIMIZED MESSAGE BUBBLE
// =================================================================

class MessageBubble extends StatefulWidget {
  final ChatMessageModel msg;
  final ChatService chatService;
  final String clientId;
  const MessageBubble({super.key, required this.msg, required this.chatService, required this.clientId});
  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final msg = widget.msg;
    final isMe = msg.isSenderClient;
    final isRequest = msg.type == MessageType.request;
    final isFailed = msg.messageStatus == MessageStatus.failed;

    // 🎯 FIX: Correctly check if msg should display as Image Grid
    final showAsImage = _shouldShowAsImage(msg);

    // Check if ANY media exists (Image, Audio, File)
    final hasMedia = (msg.attachmentUrl != null) || (msg.localFilePath != null) ||
        (msg.attachmentUrls != null && msg.attachmentUrls!.isNotEmpty) ||
        (msg.localFilePaths != null && msg.localFilePaths!.isNotEmpty);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isFailed && isMe) IconButton(icon: const Icon(Icons.refresh, color: Colors.red), onPressed: () => widget.chatService.retryMessage(widget.clientId, msg)),

          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isRequest ? Colors.orange.shade50 : (isMe ? const Color(0xFFDCF8C6) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: isFailed ? Border.all(color: Colors.red) : (isRequest ? Border.all(color: Colors.orange.shade200) : null),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 1, offset: const Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRequest) _buildRequestHeader(msg),

                  if (hasMedia) ...[
                    if (msg.type == MessageType.audio)
                      ChatAudioPlayer(audioUrl: msg.attachmentUrl, localPath: msg.localFilePath, isSender: isMe)
                    // 🎯 FIX: Uses the corrected check
                    else if (showAsImage)
                      _buildImageContent(context, msg)
                    else
                      _buildFileContent(context, msg),
                    const SizedBox(height: 4),
                  ],

                  if (msg.text.isNotEmpty) Text(msg.text, style: const TextStyle(fontSize: 15, color: Colors.black87)),

                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                    const Spacer(),
                    Text(DateFormat('h:mm a').format(msg.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    if (isMe) ...[const SizedBox(width: 4), Icon(isFailed ? Icons.error : (msg.messageStatus == MessageStatus.sending ? Icons.access_time : Icons.done_all), size: 12, color: isFailed ? Colors.red : Colors.blue)]
                  ])
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 FIX: Robust check for Images vs PDFs vs Empty Lists
  bool _shouldShowAsImage(ChatMessageModel msg) {
    // 1. Priority: If type says Image, it is an image.
    if (msg.type == MessageType.image) return true;

    // 2. Check inside lists. If first file is PDF, return FALSE.
    String? path;
    if (msg.localFilePaths != null && msg.localFilePaths!.isNotEmpty) {
      path = msg.localFilePaths!.first;
    } else if (msg.attachmentUrls != null && msg.attachmentUrls!.isNotEmpty) {
      path = msg.attachmentUrls!.first;
    } else if (msg.localFilePath != null) {
      path = msg.localFilePath;
    } else if (msg.attachmentUrl != null) {
      path = msg.attachmentUrl;
    }

    if (path != null) {
      // Remove query params if URL
      if (path.contains('?')) path = path.split('?').first;
      final ext = path.split('.').last.toLowerCase();
      // 🎯 Only return TRUE if extension is explicitly an image
      return ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);
    }

    return false; // Default to File View
  }

  // ... (Keep _buildImageContent, _buildFileContent, _buildRequestHeader from previous optimized version) ...
  Widget _buildImageContent(BuildContext context, ChatMessageModel msg) {
    List<String> images = [];
    bool isLocal = false;
    if (msg.localFilePaths?.isNotEmpty ?? false) { images = msg.localFilePaths!; isLocal = true; }
    else if (msg.attachmentUrls?.isNotEmpty ?? false) { images = msg.attachmentUrls!; }
    else if (msg.localFilePath != null) { images = [msg.localFilePath!]; isLocal = true; }
    else if (msg.attachmentUrl != null) { images = [msg.attachmentUrl!]; }

    if(images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(spacing: 4, runSpacing: 4, children: images.map((path) {
        return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: isLocal ? null : path, localPath: isLocal ? path : null))),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: images.length > 1 ? 100 : 200, height: 150, child: isLocal ? Image.file(File(path), fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_,__,___)=>const Icon(Icons.broken_image)) : CachedNetworkImage(imageUrl: path, fit: BoxFit.cover, memCacheWidth: 300, placeholder: (_,__) => Container(color: Colors.grey[200]), errorWidget: (_,__,___) => const Icon(Icons.broken_image)))));
      }).toList()),
    );
  }

  Widget _buildFileContent(BuildContext context, ChatMessageModel msg) {
    return InkWell(onTap: () async { if (msg.attachmentUrl != null) await launchUrlString(msg.attachmentUrl!, mode: LaunchMode.externalApplication); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.description, color: Colors.red), const SizedBox(width: 8), Flexible(child: Text(msg.attachmentName ?? "Document", style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue)))])));
  }

  Widget _buildRequestHeader(ChatMessageModel msg) => Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Row(children: [const Icon(Icons.star, size: 14, color: Colors.deepOrange), const SizedBox(width: 4), Text(msg.requestType.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange))]));
}