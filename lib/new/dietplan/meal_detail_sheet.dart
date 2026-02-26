import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutricare_connect/new/models/diet_plan_item_model.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';

class MealDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final String mealName;
  final ClientDietPlanModel activePlan;
  final MealEntry? logToEdit; // 🎯 FIXED: Now expects MealEntry instead of ClientLogModel
  final List<DietPlanItemModel> plannedItems;

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
  final List<TextEditingController> _foodControllers = [];
  final TextEditingController _notesController = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  bool _isSaving = false;
  List<String> _photosToDelete = [];

  @override
  void initState() {
    super.initState();
    _status = widget.logToEdit?.status ?? LogStatus.followed; // 🎯 Reads from MealEntry
    _notesController.text = widget.logToEdit?.clientQuery ?? '';

    if (widget.logToEdit != null && widget.logToEdit!.actualFoodEaten.isNotEmpty) {
      for (var food in widget.logToEdit!.actualFoodEaten) {
        _foodControllers.add(TextEditingController(text: food));
      }
    }
  }

  @override
  void dispose() {
    for (var c in _foodControllers) c.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 🔐 CORE LOGIC
  // ---------------------------------------------------------------------------

  void _addFoodField() {
    setState(() => _foodControllers.add(TextEditingController()));
  }

  void _removeFoodField(int index) {
    setState(() {
      _foodControllers[index].dispose();
      _foodControllers.removeAt(index);
    });
  }

  Color _getStatusColor(LogStatus status) {
    switch (status) {
      case LogStatus.followed: return Colors.green;
      case LogStatus.deviated: return Colors.orange;
      case LogStatus.skipped: return Colors.blueGrey;
      default: return Colors.blue;
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) setState(() => _selectedPhotos.add(image));
  }

  // 🎯 ATOMIC MEAL SAVE LOGIC
  Future<void> _saveLog() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Determine what was eaten based on the status
      List<String> foodList;
      if (_status == LogStatus.skipped) {
        foodList = ["Skipped"];
      } else if (_status == LogStatus.followed && _foodControllers.isEmpty) {
        foodList = widget.plannedItems.map((e) => e.foodItemName).toList();
      } else {
        foodList = _foodControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }

      // 2. Filter out photos marked for deletion from existing server URLs
      final List<String> remainingUrls = (widget.logToEdit?.mealPhotoUrls ?? [])
          .where((url) => !_photosToDelete.contains(url))
          .toList();

      // 3. 🎯 Build the new MealEntry map
      final Map<String, dynamic> mealEntryMap = {
        'status': _status.name,
        'actualFoodEaten': foodList,
        'mealPhotoUrls': remainingUrls, // Handled correctly in Notifier
        'clientQuery': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'isDeviation': _status == LogStatus.deviated,
        'loggedAt': DateTime.now().toIso8601String(), // Timestamp for precise logging
      };

      // 4. 🎯 Execute Atomic Update via Notifier
      await widget.notifier.updateDailyRecord(
        data: {
          'mealLogs.${widget.mealName}': mealEntryMap, // Target the specific map key
        },
        newPhotos: _selectedPhotos,
        mealNameForPhotos: widget.mealName,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Meal Logged Successfully"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🎨 UI COMPONENTS
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🎯 FORCE OPAQUE COLOR
    final solidBgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: solidBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            _buildHandle(theme),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildHeader(widget.mealName, colorScheme),
                  const SizedBox(height: 20),
                  _buildStatusToggle(colorScheme),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (_status == LogStatus.skipped)
                      _buildSimpleMessage("Marking this meal as skipped.")
                    else if (_status == LogStatus.followed && _foodControllers.isEmpty)
                      _buildPlanSummary(colorScheme)
                    else
                      _buildDynamicFoodList(colorScheme),

                    const SizedBox(height: 20),
                    _buildPhotoAndNotes(theme, colorScheme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            _buildSaveButton(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(ThemeData theme) => Container(
    width: 40, height: 4,
    decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
  );

  Widget _buildHeader(String title, ColorScheme colorScheme) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text("Track your nutrition intake", style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
    ],
  );

  Widget _buildStatusToggle(ColorScheme colorScheme) => Container(
    decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: LogStatus.values.map((s) {
        final isSelected = _status == s;
        // Skip "reviewed" since that is for admins
        if (s == LogStatus.reviewed) return const SizedBox.shrink();

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _status = s);
              if (s == LogStatus.deviated && _foodControllers.isEmpty) {
                for (var item in widget.plannedItems) {
                  _foodControllers.add(TextEditingController(text: item.foodItemName));
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: isSelected ? _getStatusColor(s) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Text(s.name.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : colorScheme.onSurfaceVariant)),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildPlanSummary(ColorScheme colorScheme) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: colorScheme.primary.withOpacity(0.1))),
    child: Row(
      children: [
        Icon(Icons.auto_awesome_rounded, color: colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        const Expanded(child: Text("Logged exactly as planned.", style: TextStyle(fontSize: 13))),
        TextButton(
            onPressed: () {
              setState(() => _status = LogStatus.deviated);
              for (var item in widget.plannedItems) {
                _foodControllers.add(TextEditingController(text: item.foodItemName));
              }
            },
            child: const Text("Edit Items")
        ),
      ],
    ),
  );

  Widget _buildDynamicFoodList(ColorScheme colorScheme) => Column(
    children: [
      ..._foodControllers.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: e.value,
          decoration: InputDecoration(
            hintText: "Item ${e.key + 1}",
            filled: true, fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixIcon: IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => _removeFoodField(e.key)),
          ),
        ),
      )),
      TextButton.icon(onPressed: _addFoodField, icon: const Icon(Icons.add_circle_outline, size: 18), label: const Text("Add Item")),
    ],
  );

  Widget _buildPhotoAndNotes(ThemeData theme, ColorScheme colorScheme) {
    final List<String> remotePhotos = (widget.logToEdit?.mealPhotoUrls ?? [])
        .where((url) => !_photosToDelete.contains(url))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Photos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _pickPhoto(ImageSource.camera),
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_a_photo_rounded, color: colorScheme.primary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(
            hintText: "Add notes or questions...",
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleMessage(String msg) => Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(msg, style: const TextStyle(color: Colors.grey)));

  Widget _buildSaveButton(ColorScheme colorScheme) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    child: SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveLog,
        style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Confirm & Save", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ),
  );

  void _showFullScreenPreview(dynamic photo) {
    final bool isLocal = photo is XFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      Center(
                        child: Hero(
                          tag: photo.toString(),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: isLocal
                                ? Image.file(File(photo.path), fit: BoxFit.contain)
                                : Image.network(photo, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 50,
                        left: 0, right: 0,
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? newImage = await picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 70
                              );

                              if (newImage != null) {
                                setState(() {
                                  if (isLocal) {
                                    final index = _selectedPhotos.indexOf(photo);
                                    if (index != -1) _selectedPhotos[index] = newImage;
                                  } else {
                                    _photosToDelete.add(photo);
                                    _selectedPhotos.add(newImage);
                                  }
                                });
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                            label: const Text("Retake Photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.6),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 60, right: 20,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
      ),
    );
  }

  Widget _buildImagePreview({required dynamic source, required Widget child, required VoidCallback onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showFullScreenPreview(source),
            child: Hero(
              tag: source.toString(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 60, height: 60, child: child),
              ),
            ),
          ),
          Positioned(
            top: -2, right: -2,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}