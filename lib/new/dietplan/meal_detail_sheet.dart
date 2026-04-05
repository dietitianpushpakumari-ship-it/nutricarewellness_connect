import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutricare_connect/new/FlatClientDietPlanModel.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';

import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

import '../flat_diet_plan_model.dart';

class MealDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final String mealName;
  final FlatClientDietPlanModel activePlan; // 🚀 Flat Model
  final MealEntry? logToEdit;
  final List<FlatDietPlanItem> plannedItems; // 🚀 Flat Model List

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
  // We assume 'followed' by default to save clicks.
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

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() {
        _selectedPhotos.add(image);
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
            content: Text("📸 Please snap a quick photo of your meal!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
        // Rely purely on the photo and the status!
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                  Text(widget.mealName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
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
                    // 📸 1. MASSIVE PHOTO UPLOAD ZONE
                    _buildMassivePhotoZone(colorScheme),

                    const SizedBox(height: 24),

                    // ⚠️ 2. ONLY SHOW "DEVIATED" TOGGLE IF THEY HAVE UPLOADED A PHOTO
                    if (hasPhotos) ...[
                      _buildDeviationToggle(colorScheme,theme),
                      const SizedBox(height: 16),
                    ],

                    // 📝 3. ON-DEMAND NOTES (Hidden by default)
                    _buildNoteSection(colorScheme,theme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 💾 4. BIG SAVE BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveLog(forceSkip: false),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SAVE MEAL LOG", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0)),
                ),
              ),
            ),

            // ⏭️ 5. SUBTLE SKIP BUTTON AT THE VERY BOTTOM
            TextButton(
              onPressed: _isSaving ? null : () => _saveLog(forceSkip: true),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text("I skipped this meal", style: TextStyle(fontWeight: FontWeight.w600)),
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
          height: 160,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.primary.withOpacity(0.3), style: BorderStyle.solid, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_rounded, size: 48, color: colorScheme.primary.withOpacity(0.7)),
              const SizedBox(height: 12),
              Text("Tap to snap a photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          ...remotePhotos.map((url) => _buildImagePreview(
            source: url,
            child: Image.network(url, fit: BoxFit.cover),
            onDelete: () => setState(() => _photosToDelete.add(url)),
          )),
          ..._selectedPhotos.map((file) => _buildImagePreview(
            source: file,
            child: Image.file(File(file.path), fit: BoxFit.cover),
            onDelete: () => setState(() => _selectedPhotos.remove(file)),
          )),
          GestureDetector(
            onTap: () => _pickPhoto(ImageSource.camera),
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.add_a_photo_rounded, color: colorScheme.primary, size: 32),
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
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "ADHERENCE",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: theme.hintColor.withOpacity(0.6),
            ),
          ),
        ),
        Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatusSegment(
                  label: "Followed",
                  icon: Icons.check_circle_rounded,
                  isSelected: !isDeviated,
                  selectedColor: Colors.green.shade600,
                  onTap: () => setState(() => _status = LogStatus.followed),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _StatusSegment(
                  label: "Deviated",
                  icon: Icons.error_outline_rounded,
                  isSelected: isDeviated,
                  selectedColor: Colors.orange.shade800,
                  onTap: () => setState(() => _status = LogStatus.deviated),
                ),
              ),
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
          icon: Icon(Icons.edit_note_rounded, size: 20, color: colorScheme.primary),
          label: Text("Add a note", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      )
          : Column(
        key: const ValueKey("note_field"),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 16, color: theme.hintColor),
              const SizedBox(width: 8),
              Text("NOTES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: theme.hintColor)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                onPressed: () => setState(() {
                  _showNoteField = false;
                  _notesController.clear();
                }),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              )
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 3,
            autofocus: true,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: "E.g. Extra portion of protein...",
              hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
              filled: true,
              fillColor: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview({required dynamic source, required Widget child, required VoidCallback onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 120, height: 120, child: child)),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: CircleAvatar(radius: 14, backgroundColor: Colors.black.withOpacity(0.6), child: const Icon(Icons.close, size: 16, color: Colors.white)),
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

  const _StatusSegment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}