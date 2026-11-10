import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/new/utils/image_compressor.dart';

class MealDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final String dbKey;
  final FlatClientDietPlanModel activePlan;
  final MealEntry? logToEdit;

  const MealDetailSheet({
    super.key,
    required this.notifier,
    required this.dbKey,
    required this.activePlan,
    this.logToEdit,
  });

  @override
  ConsumerState<MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends ConsumerState<MealDetailSheet> {
  final TextEditingController _notesController = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  bool _isSaving = false;
  final List<String> _photosToDelete = [];
  bool _showNoteField = false;

  late TimeOfDay _loggedTime;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.logToEdit?.clientQuery ?? '';
    if (_notesController.text.isNotEmpty) _showNoteField = true;

    final logDt = widget.logToEdit?.loggedAt;
    if (logDt != null) {
      _loggedTime = TimeOfDay.fromDateTime(logDt.toLocal());
    } else {
      _loggedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _loggedTime,
    );
    if (picked != null) {
      setState(() {
        _loggedTime = picked;
      });
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (image != null) {
      File originalFile = File(image.path);
      File? compressedFile = await ImageCompressor.compressAndGetFile(originalFile);
      final finalFile = compressedFile ?? originalFile;

      setState(() {
        _selectedPhotos.add(XFile(finalFile.path));
      });
    }
  }

  Future<void> _saveLog() async {
    if (_isSaving) return;

    final List<String> remainingUrls = (widget.logToEdit?.mealPhotoUrls ?? [])
        .where((url) => !_photosToDelete.contains(url))
        .toList();

    if (_selectedPhotos.isEmpty && remainingUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Snap a quick photo of your meal!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final finalLogDt = DateTime(now.year, now.month, now.day, _loggedTime.hour, _loggedTime.minute);

      final Map<String, dynamic> mealEntryMap = {
        'status': LogStatus.followed.name,
        'actualFoodEaten': [],
        'mealPhotoUrls': remainingUrls,
        'clientQuery': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'isDeviation': false,
        'loggedAt': finalLogDt.toUtc().toIso8601String(),
      };

      await widget.notifier.updateDailyRecord(
        data: {
          'mealLogs': {
            widget.dbKey: mealEntryMap
          }
        },
        newPhotos: _selectedPhotos,
        mealNameForPhotos: widget.dbKey,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e", style: const TextStyle(fontSize: 12)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openFullScreenViewer(List<dynamic> allPhotos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          images: allPhotos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final solidBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: solidBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("JOURNAL ENTRY", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_filled_rounded, size: 14, color: colorScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  "Logged at ${_loggedTime.format(context)}",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colorScheme.primary),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.edit_rounded, size: 14, color: colorScheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMassivePhotoZone(colorScheme),
                    const SizedBox(height: 24),
                    _buildNoteSection(colorScheme, theme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveLog(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SAVE TO JOURNAL", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMassivePhotoZone(ColorScheme colorScheme) {
    final List<String> remotePhotos = (widget.logToEdit?.mealPhotoUrls ?? [])
        .where((url) => !_photosToDelete.contains(url)).toList();

    final bool hasPhotos = _selectedPhotos.isNotEmpty || remotePhotos.isNotEmpty;

    if (!hasPhotos) {
      return GestureDetector(
        onTap: () => _pickPhoto(ImageSource.camera),
        child: Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.primary.withOpacity(0.3), style: BorderStyle.solid, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_rounded, size: 42, color: colorScheme.primary.withOpacity(0.7)),
              const SizedBox(height: 12),
              Text("Tap to snap a photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.primary)),
            ],
          ),
        ),
      );
    }

    final List<dynamic> combinedPhotos = [...remotePhotos, ..._selectedPhotos];

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          ...remotePhotos.asMap().entries.map((entry) => _buildImagePreview(
            child: CachedNetworkImage(imageUrl: entry.value, fit: BoxFit.cover),
            onTap: () => _openFullScreenViewer(combinedPhotos, entry.key),
            onDelete: () => setState(() => _photosToDelete.add(entry.value)),
          )),
          ..._selectedPhotos.asMap().entries.map((entry) => _buildImagePreview(
            child: Image.file(File(entry.value.path), fit: BoxFit.cover),
            onTap: () => _openFullScreenViewer(combinedPhotos, remotePhotos.length + entry.key),
            onDelete: () => setState(() => _selectedPhotos.remove(entry.value)),
          )),
          GestureDetector(
            onTap: () => _pickPhoto(ImageSource.camera),
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.add_a_photo_rounded, color: colorScheme.primary, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview({required Widget child, required VoidCallback onTap, required VoidCallback onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 100, height: 100, child: child)),
          ),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: CircleAvatar(radius: 12, backgroundColor: Colors.black.withOpacity(0.6), child: const Icon(Icons.close, size: 14, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(ColorScheme colorScheme, ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: !_showNoteField
          ? SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () => setState(() => _showNoteField = true),
          icon: Icon(Icons.edit_note_rounded, size: 18, color: colorScheme.primary),
          label: Text("Add a quick note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primary)),
          style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), backgroundColor: colorScheme.primary.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      )
          : Column(
        key: const ValueKey("note_field"),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 14, color: theme.hintColor),
              const SizedBox(width: 6),
              Text("JOURNAL NOTES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: theme.hintColor)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() { _showNoteField = false; _notesController.clear(); }), constraints: const BoxConstraints(), padding: EdgeInsets.zero)
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController, maxLines: 3, autofocus: true, style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: "E.g. Extra portion of protein, felt a bit hungry...", hintStyle: TextStyle(fontSize: 12, color: theme.hintColor.withOpacity(0.5)),
              filled: true, fillColor: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
            ),
          ),
        ],
      ),
    );
  }
}

// 🚀 CRITICAL: Fully closed the state class before opening the new one.

class FullScreenImageViewer extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_currentIndex + 1} / ${widget.images.length}",
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            child: Center(
              child: image is String
                  ? CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
              )
                  : Image.file(
                File((image as XFile).path),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}