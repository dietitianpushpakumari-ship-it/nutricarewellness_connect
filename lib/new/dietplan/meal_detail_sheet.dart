import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_shift/new/FlatClientDietPlanModel.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/domain/entities/client_log_model.dart';
import 'package:pure_shift/new/utils/image_compressor.dart';
import '../flat_diet_plan_model.dart';

// 🚀 Make sure you import your ImageCompressor utility here!
// import 'package:your_app/utils/image_compressor.dart';

class MealDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final String mealName;
  final FlatClientDietPlanModel activePlan;
  final MealEntry? logToEdit;
  final List<FlatDietPlanItem> plannedItems;

  const MealDetailSheet({
    super.key,
    required this.notifier,
    required this.mealName,
    required this.activePlan,
    this.logToEdit,
    this.plannedItems = const [],
  });

  @override
  ConsumerState<MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends ConsumerState<MealDetailSheet> {
  LogStatus _status = LogStatus.followed;
  final TextEditingController _notesController = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  bool _isSaving = false;
  List<String> _photosToDelete = [];
  bool _showNoteField = false;

  @override
  void initState() {
    super.initState();
    _status = widget.logToEdit?.status ?? LogStatus.followed;
    _notesController.text = widget.logToEdit?.clientQuery ?? '';
    if (_notesController.text.isNotEmpty) _showNoteField = true;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // 🚀 INTEGRATED SILENT COMPRESSION
  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    // We let the picker take the raw image first
    final image = await picker.pickImage(source: source);

    if (image != null) {
      File originalFile = File(image.path);

      // 🚀 Pass it through your WebP compressor silently
      // NOTE: Ensure your ImageCompressor class is imported and available!
      File? compressedFile = await ImageCompressor.compressAndGetFile(originalFile);

      // Fallback to original if compression somehow fails
      final finalFile = compressedFile ?? originalFile;

      setState(() {
        _selectedPhotos.add(XFile(finalFile.path));
        if (_status == LogStatus.skipped) _status = LogStatus.followed;
      });
    }
  }

  Future<void> _saveLog({bool forceSkip = false}) async {
    if (_isSaving) return;

    if (forceSkip) {
      setState(() => _status = LogStatus.skipped);
    }

    final List<String> remainingUrls = (widget.logToEdit?.mealPhotoUrls ?? [])
        .where((url) => !_photosToDelete.contains(url))
        .toList();

    // MANDATORY PHOTO CHECK
    if (_status != LogStatus.skipped && _selectedPhotos.isEmpty && remainingUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📸 Please snap a quick photo of your meal!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      List<String> foodList;
      if (_status == LogStatus.skipped) {
        foodList = ["Skipped"];
      } else if (_status == LogStatus.followed) {
        foodList = [];
      } else {
        foodList = ["Deviated from plan"];
      }

      final Map<String, dynamic> mealEntryMap = {
        'status': _status.name,
        'actualFoodEaten': foodList,
        'mealPhotoUrls': forceSkip ? [] : remainingUrls,
        'clientQuery': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'isDeviation': _status == LogStatus.deviated,
        'loggedAt': DateTime.now().toIso8601String(),
      };

      await widget.notifier.updateDailyRecord(
        data: {
          'mealLogs': {
            widget.mealName: mealEntryMap
          }
        },
        newPhotos: forceSkip ? [] : _selectedPhotos,
        mealNameForPhotos: widget.mealName,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e", style: const TextStyle(fontSize: 12)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🚀 OPENS FULL SCREEN SWIPEABLE VIEWER
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
    final hasPhotos = _selectedPhotos.isNotEmpty || (widget.logToEdit?.mealPhotoUrls.isNotEmpty ?? false);

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
                  Text(widget.mealName.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
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
                    const SizedBox(height: 20),

                    if (hasPhotos) ...[
                      _buildDeviationToggle(colorScheme,theme),
                      const SizedBox(height: 16),
                    ],

                    _buildNoteSection(colorScheme,theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveLog(forceSkip: false),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SAVE MEAL LOG", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.0)),
                ),
              ),
            ),

            TextButton(
              onPressed: _isSaving ? null : () => _saveLog(forceSkip: true),
              style: TextButton.styleFrom(foregroundColor: Colors.grey, minimumSize: const Size(0, 36)),
              child: const Text("I skipped this meal", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildMassivePhotoZone(ColorScheme colorScheme) {
    final List<String> remotePhotos = (widget.logToEdit?.mealPhotoUrls ?? [])
        .where((url) => !_photosToDelete.contains(url)).toList();

    final bool hasPhotos = _selectedPhotos.isNotEmpty || remotePhotos.isNotEmpty;

    if (!hasPhotos) {
      return GestureDetector(
        onTap: () => _pickPhoto(ImageSource.camera),
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.primary.withOpacity(0.3), style: BorderStyle.solid, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_rounded, size: 36, color: colorScheme.primary.withOpacity(0.7)),
              const SizedBox(height: 8),
              Text("Tap to snap a photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colorScheme.primary)),
            ],
          ),
        ),
      );
    }

    // Combine both remote and local photos for the swipe gallery
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

  // 🚀 Updated to support tapping the image
  Widget _buildImagePreview({required Widget child, required VoidCallback onTap, required VoidCallback onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap, // Tap image to open full screen
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

  Widget _buildDeviationToggle(ColorScheme colorScheme, ThemeData theme) {
    final bool isDeviated = _status == LogStatus.deviated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text("ADHERENCE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.6))),
        ),
        Container(
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(child: _StatusSegment(label: "Followed", icon: Icons.check_circle_rounded, isSelected: !isDeviated, selectedColor: Colors.green.shade600, onTap: () => setState(() => _status = LogStatus.followed))),
              const SizedBox(width: 4),
              Expanded(child: _StatusSegment(label: "Deviated", icon: Icons.error_outline_rounded, isSelected: isDeviated, selectedColor: Colors.orange.shade800, onTap: () => setState(() => _status = LogStatus.deviated))),
            ],
          ),
        ),
      ],
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
          icon: Icon(Icons.edit_note_rounded, size: 16, color: colorScheme.primary),
          label: Text("Add a note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.primary)),
          style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
              Text("NOTES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: theme.hintColor)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () => setState(() { _showNoteField = false; _notesController.clear(); }), constraints: const BoxConstraints(), padding: EdgeInsets.zero)
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController, maxLines: 3, autofocus: true, style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              hintText: "E.g. Extra portion of protein...", hintStyle: TextStyle(fontSize: 10, color: theme.hintColor.withOpacity(0.5)),
              filled: true, fillColor: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _StatusSegment({required this.label, required this.icon, required this.isSelected, required this.selectedColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(color: isSelected ? selectedColor : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 🚀 FULL SCREEN MULTI-PHOTO SLIDER
// ===========================================================================
class FullScreenImageViewer extends StatefulWidget {
  final List<dynamic> images; // Can be String (URL) or XFile (Local)
  final int initialIndex;

  const FullScreenImageViewer({Key? key, required this.images, required this.initialIndex}) : super(key: key);

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
          // InteractiveViewer gives you "pinch to zoom" for free!
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