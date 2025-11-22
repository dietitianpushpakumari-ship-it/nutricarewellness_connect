import 'dart:io';


import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // 🎯 Ensure this is imported
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutricare_connect/core/utils/smart_dialogs.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart'; // Required for clientServiceProvider

// --- Global Dialog Launcher Function ---
void showLogModificationDialog(BuildContext context, DietPlanNotifier notifier, String mealName, ClientDietPlanModel activePlan, {ClientLogModel? logToEdit}) {
  showDialog(
    context: context,
    builder: (context) {
      return MealLogEntryDialog(
        notifier: notifier,
        mealName: mealName,
        activePlan: activePlan,
        logToEdit: logToEdit,
      );
    },
  );
}


// --- The Stateful Dialog Widget ---
class MealLogEntryDialog extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final String mealName;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? logToEdit;

  const MealLogEntryDialog({
    super.key,
    required this.notifier,
    required this.mealName,
    required this.activePlan,
    this.logToEdit,
  });

  @override
  ConsumerState<MealLogEntryDialog> createState() => _MealLogEntryDialogState();
}

class _MealLogEntryDialogState extends ConsumerState<MealLogEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  // 🎯 DYNAMIC FOOD CONTROLLERS
  List<TextEditingController> _foodControllers = [];

  final _queryController = TextEditingController();

  List<XFile> _selectedPhotos = [];
  TimeOfDay? _deviationTime;
  double _totalPhotoSizeKB = 0.0;
  LogStatus _selectedStatus = LogStatus.followed;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.logToEdit != null) {
      _initializeForEdit(widget.logToEdit!);
    } else {
      // Start with one empty text field
      _addFoodField();
    }
  }

  void _initializeForEdit(ClientLogModel log) {
    _queryController.text = log.clientQuery ?? '';
    _selectedStatus = log.logStatus;

    if (log.deviationTime != null) {
      _deviationTime = TimeOfDay.fromDateTime(log.deviationTime!);
    }

    // 🎯 Populate the dynamic controllers from the saved list
    _foodControllers = log.actualFoodEaten
        .map((foodItem) => TextEditingController(text: foodItem))
        .toList();

    if (_foodControllers.isEmpty) {
      _addFoodField();
    }
  }

  @override
  void dispose() {
    // 🎯 Dispose all dynamic controllers
    for (var controller in _foodControllers) {
      controller.dispose();
    }
    _queryController.dispose();
    super.dispose();
  }

  // --- 🎯 Dynamic Field Handlers ---
  void _addFoodField() {
    setState(() {
      _foodControllers.add(TextEditingController());
    });
  }

  void _removeFoodField(int index) {
    if (_foodControllers.length > 1) {
      setState(() {
        _foodControllers[index].dispose(); // Dispose the controller
        _foodControllers.removeAt(index);
      });
    } else {
      _foodControllers[index].clear();
    }
  }

  // --- Image Picker Logic (FIXED) ---
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    List<XFile> pickedImages = [];

    if (source == ImageSource.camera) {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) pickedImages = [image];
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        pickedImages = result.files.where((f) => f.path != null).map((f) => XFile(f.path!)).toList();
      }
    }

    if (pickedImages.isNotEmpty) {
      double totalSize = 0;
      // 🎯 FIX: Await the length calculation
      for (var image in pickedImages) {
        totalSize += (await image.length()) / 1024.0;
      }

      setState(() {
        _selectedPhotos.addAll(pickedImages); // Add to the existing list
        _totalPhotoSizeKB += totalSize;
      });
    }
  }

  void _removePhoto(XFile fileToRemove) async {
    // 🎯 FIX: Await the length calculation
    final size = (await fileToRemove.length()) / 1024.0;
    setState(() {
      _selectedPhotos.remove(fileToRemove);
      _totalPhotoSizeKB -= size;
      _totalPhotoSizeKB = _totalPhotoSizeKB.clamp(0.0, double.infinity);
    });
  }

  // --- Submission Handler ---
  Future<void> _handleLogSubmission() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    // 🎯 Get food list from dynamic controllers
    final List<String> foodList = _foodControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty) // Filter out empty fields
        .toList();

    final String query = _queryController.text.trim();

    // 🎯 Updated Validation
    if (foodList.isEmpty && _selectedStatus != LogStatus.skipped) {
      _showMessage('Please enter at least one food item, or select "Skipped".');
      return;
    }
    if (_selectedStatus == LogStatus.deviated && _deviationTime == null) {
      _showMessage('Please select the time the deviation occurred.', isError: true);
      return;
    }

    setState(() { _isSaving = true; });

    try {
      final baseLog = widget.logToEdit ??
          ClientLogModel(
            clientId: widget.notifier.state.activePlan!.clientId,
            dietPlanId: widget.activePlan.id,
            date: widget.notifier.state.selectedDate,
            mealName: widget.mealName,
            actualFoodEaten: [], // Default
          );

      final logToSave = baseLog.copyWith(
        actualFoodEaten: _selectedStatus == LogStatus.skipped ? ['Meal Skipped'] : foodList,
        logStatus: _selectedStatus,
        isDeviation: _selectedStatus == LogStatus.deviated,
        deviationTime: _selectedStatus == LogStatus.deviated && _deviationTime != null ? DateTime(
            widget.notifier.state.selectedDate.year,
            widget.notifier.state.selectedDate.month,
            widget.notifier.state.selectedDate.day,
            _deviationTime!.hour,
            _deviationTime!.minute
        ) : null,
        clientQuery: query.isEmpty ? null : query,
        mealPhotoUrls: _selectedPhotos.isEmpty ? widget.logToEdit?.mealPhotoUrls : [],
      );

      // 3. Delegate to the Notifier (which calls the service)
      await widget.notifier.createOrUpdateLog(
        log: logToSave,
        mealPhotoFiles: _selectedPhotos,
      );

      // 4. Manually refresh the dashboard data after save
      await widget.notifier.loadInitialData(widget.notifier.state.selectedDate);

      if (mounted) {
        _showMessage('Log recorded successfully!', isError: false);
        Navigator.of(context).pop();
        showContextualSuccessDialog(context, 'nutrition');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showMessage('Failed to record log: ${e.toString().split(':').last.trim()}', isError: true);
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  Future<void> _selectDeviationTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _deviationTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _deviationTime = picked;
      });
    }
  }

  // 🎯 FIX: Replaced _showMessage with SnackBar
  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    final actionText = widget.logToEdit != null ? 'Update Log' : 'Record Log';
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      title: Text(widget.logToEdit != null ? 'Edit Log Entry' : 'Log Your ${widget.mealName}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Log Status Dropdown
              DropdownButtonFormField<LogStatus>(
                decoration: const InputDecoration(
                  labelText: 'Meal Status',
                  border: OutlineInputBorder(),
                ),
                value: _selectedStatus,
                items: LogStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.name.capitalize()),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedStatus = val!;
                    if (val != LogStatus.deviated) _deviationTime = null;
                    if (val == LogStatus.skipped && _foodControllers.isNotEmpty) {
                      _foodControllers.forEach((c) => c.clear());
                    }
                  });
                },
              ),
              const SizedBox(height: 15),

              // 2. Deviation Time Picker
              if (_selectedStatus == LogStatus.deviated)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time, color: Colors.orange),
                    title: Text(_deviationTime == null
                        ? 'Select Deviation Time *'
                        : 'Deviation Time: ${_deviationTime!.format(context)}'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _selectDeviationTime(context),
                  ),
                ),

              // 3. 🎯 DYNAMIC FOOD EATEN INPUT
              if (_selectedStatus != LogStatus.skipped)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStatus == LogStatus.deviated
                          ? 'What did you eat instead? (Required)'
                          : 'What did you eat?',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _selectedStatus == LogStatus.deviated ? Colors.red.shade700 : primaryColor),
                    ),
                    const SizedBox(height: 8),
                    // Build the list of text fields
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _foodControllers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _foodControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Food Item ${index + 1}',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  validator: (value) {
                                    // Only validate if it's the *only* field
                                    if (index == 0 && _foodControllers.length == 1 && _selectedStatus != LogStatus.skipped && (value == null || value.trim().isEmpty)) {
                                      return 'Food entry is required.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                                onPressed: () => _removeFoodField(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // "Add More" Button
                    TextButton.icon(
                      onPressed: _addFoodField,
                      icon: Icon(Icons.add, color: primaryColor),
                      label: Text('Add Another Item', style: TextStyle(color: primaryColor)),
                    ),
                  ],
                ),
              const SizedBox(height: 15),

              // 4. Client Query / Question
              TextFormField(
                controller: _queryController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Questions for Dietitian (Optional)',
                  hintText: 'e.g., Is coffee allowed?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // 5. Photo Capture/Upload Section
              const Text('Meal Photo (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload'),
                    ),
                  ),
                ],
              ),

              // 6. Preview & Status (FIXED TEXT DISPLAY)
              if (_selectedPhotos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected: ${_selectedPhotos.length} images', style: const TextStyle(fontWeight: FontWeight.bold)),
                      // 🎯 FIX: Use the synchronous state variable
                      Text('Total Size: ${_totalPhotoSizeKB.toStringAsFixed(1)} KB (Originals)', style: TextStyle(color: Colors.orange.shade700, fontSize: 13)),
                      Text('Will be compressed to ~20KB each.', style: TextStyle(color: Colors.green.shade700, fontSize: 11)),
                      const SizedBox(height: 10),

                      // --- Image Preview Row ---
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _selectedPhotos.map((photo) {
                          return GestureDetector(
                            onTap: () => _showEnlargedPreview(context, photo),
                            child: Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(File(photo.path)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () => _removePhoto(photo),
                                    child: Icon(Icons.delete_forever, size: 18, color: Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleLogSubmission,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(actionText),
        ),
      ],
    );
  }
}


void _showEnlargedPreview(BuildContext context, XFile photo) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: FileImage(File(photo.path)),
              fit: BoxFit.contain,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}


extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}