// lib/features/diet_plan/presentation/screens/diet_plan_dashboard_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart' hide clientServiceProvider;
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_log_history_screen.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import '../providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/meal_log_entry_dialog.dart';

class DietPlanDashboardScreen extends ConsumerWidget {
  const DietPlanDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeDietPlanProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    // Safety check for notifier access: Only access if a client ID is available
    final clientId = ref.watch(currentClientIdProvider);
    final notifier = clientId != null
        ? ref.read(dietPlanNotifierProvider(clientId).notifier)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Daily Plan'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Log History',
            onPressed: () {
              // Navigate to the new history screen
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ClientLogHistoryScreen(),
              ));
            },
          ),
          IconButton(
            onPressed: () => authNotifier.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
          if (notifier != null)
            IconButton(
              onPressed: () => notifier.loadInitialData(state.selectedDate),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : state.error != null
          ? Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)))
          : _buildContent(context, state, notifier),
    );
  }

  Widget _buildContent(
      BuildContext context,
      DietPlanState state,
      DietPlanNotifier? notifier,
      ) {
    if (state.activePlan == null) {
      return const Center(child: Text('No active diet plan found.', style: TextStyle(fontSize: 16)));
    }

    // We assume the plan object is valid if we reached here
    final dayPlan = state.activePlan!.days.isNotEmpty ? state.activePlan!.days.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Active Plan: ${state.activePlan!.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ),
        Expanded(
          child: dayPlan == null
              ? const Center(child: Text('No meal details for today.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            itemCount: dayPlan.meals.length,
            itemBuilder: (context, index) {
              final meal = dayPlan.meals[index];
              final logs = state.dailyLogs.where((log) => log.mealName == meal.mealName).toList();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                child: ExpansionTile(
                  leading: Icon(Icons.restaurant_menu, color: logs.isEmpty ? Colors.grey : Colors.green.shade700),
                  title: Text(meal.mealName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${meal.items.length} items planned. ${logs.length} logged.'),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ...meal.items.map((item) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.arrow_right, color: Colors.teal),
                      title: Text(item.foodItemName),
                      trailing: Text('${item.quantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    )),
                    const Divider(height: 10),
                    if (logs.isNotEmpty)
                      ...logs.map((log) => ListTile(
                        dense: true,
                        leading: log.isDeviation ? const Icon(Icons.warning, color: Colors.red) : const Icon(Icons.done_all, color: Colors.blue),
                        title: Text(log.actualFoodEaten, style: TextStyle(color: log.isDeviation ? Colors.red.shade700 : Colors.black)),
                        subtitle: Text('Calories: ${log.caloriesEstimate}', style: const TextStyle(fontSize: 12)),
                      )),
                    // Log Button
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: notifier != null ? () => _showLogMealDialog(context, notifier, meal.mealName,state.activePlan!) : null,
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: Text('Log ${meal.mealName}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade50,
                          foregroundColor: Colors.teal.shade700,
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- Helper for Logging ---
void _showLogMealDialog(BuildContext context, DietPlanNotifier notifier, String mealName, ClientDietPlanModel activePlan) {
  showDialog(
    context: context,
    builder: (context) {
      return _MealLogEntryDialog(
        notifier: notifier,
        mealName: mealName,
        activePlan: activePlan,
      );
    },
  );
}

// --- The Stateful Dialog Content Widget ---
class _MealLogEntryDialog extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final String mealName;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? logToEdit;

  const _MealLogEntryDialog({
    required this.notifier,
    required this.mealName,
    required this.activePlan,
    this.logToEdit,
  });

  @override
  ConsumerState<_MealLogEntryDialog> createState() => _MealLogEntryDialogState();
}

class _MealLogEntryDialogState extends ConsumerState<_MealLogEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _foodController = TextEditingController();
  final _queryController = TextEditingController();
  List<XFile> _selectedPhotos = []; // 🎯 CRITICAL CHANGE 6: Now a List of files
  TimeOfDay? _deviationTime;
  double _totalPhotoSizeKB = 0.0;
  LogStatus _selectedStatus = LogStatus.followed;
  XFile? _selectedPhoto;
  double _photoSizeKB = 0.0; // Stores original size for preview
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 🎯 INITIALIZATION FOR EDIT MODE
    if (widget.logToEdit != null) {
      _initializeForEdit(widget.logToEdit!);
    }
  }

  void _initializeForEdit(ClientLogModel log) {
    _foodController.text = log.actualFoodEaten;
    _queryController.text = log.clientQuery ?? '';
    _selectedStatus = log.logStatus;

    // Deviation Time
    if (log.deviationTime != null) {
      _deviationTime = TimeOfDay.fromDateTime(log.deviationTime!);
    }
    // NOTE: _selectedPhotos list is intentionally left empty; user must re-upload/confirm photos.
  }

  @override
  void dispose() {
    _foodController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    List<XFile> pickedImages = [];

    if (source == ImageSource.camera) {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) pickedImages = [image];
    } else {
      // Allow multiple file selection from gallery
      pickedImages = await picker.pickMultiImage();
    }

    if (pickedImages.isNotEmpty) {
      // Calculate total size asynchronously
      double totalSize = 0;
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
    final size = await fileToRemove.length() / 1024.0;
    setState(() {
      _selectedPhotos.remove(fileToRemove);
      _totalPhotoSizeKB -= size;
      _totalPhotoSizeKB = _totalPhotoSizeKB.clamp(0.0, double.infinity);
    });
  }

  void _clearPhoto() {
    setState(() {
      _selectedPhoto = null;
      _photoSizeKB = 0.0;
    });
  }



  // --- Submission Handler ---
  Future<void> _handleLogSubmission() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    final String food = _foodController.text.trim();
    final String query = _queryController.text.trim();

    if (_selectedStatus == LogStatus.deviated && _deviationTime == null) {
      _showMessage('Please select the time the deviation occurred.', isError: true);
      return;
    }

    setState(() { _isSaving = true; });

    try {
      // 1. Get the base log model: Use existing log data if editing, otherwise new.
      final baseLog = widget.logToEdit ??
          ClientLogModel(
            clientId: widget.notifier.state.activePlan!.clientId,
            dietPlanId: widget.activePlan.id,
            date: widget.notifier.state.selectedDate,
            mealName: widget.mealName,
            logStatus: _selectedStatus, actualFoodEaten: '',
          );

      // 2. Create the final log model with user inputs
      final logToSave = baseLog.copyWith(
        // 🎯 CRITICAL: Preserve existing ID if updating
        // 🎯 NOTE: Pass null for deviationTime if status is not deviated
        deviationTime: _selectedStatus == LogStatus.deviated && _deviationTime != null ? DateTime(
            widget.notifier.state.selectedDate.year,
            widget.notifier.state.selectedDate.month,
            widget.notifier.state.selectedDate.day,
            _deviationTime!.hour,
            _deviationTime!.minute
        ) : null,
        actualFoodEaten: food.isEmpty && _selectedStatus == LogStatus.skipped ? 'Meal Skipped' : food,
        logStatus: _selectedStatus,
        isDeviation: _selectedStatus == LogStatus.deviated,
        clientQuery: query.isEmpty ? null : query,

        // Preserve existing URLs if no new files were uploaded
        mealPhotoUrls: _selectedPhotos.isEmpty ? widget.logToEdit?.mealPhotoUrls : null,
      );

      // 3. Delegate to the ClientService method which handles creation or update
      await ref.read(clientServiceProvider).createOrUpdateLog(
        log: logToSave,
        mealPhotoFiles: _selectedPhotos, // Pass the list of files
      );

      // 4. Refresh the active day's logs and history
      await widget.notifier.loadInitialData(widget.notifier.state.selectedDate);

      if (mounted) {
        _showMessage('Log recorded successfully!', isError: false);
        Navigator.of(context).pop();
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
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        // Force LTR direction for time picker if needed
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _deviationTime = picked;
      });
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    final actionText = widget.logToEdit != null ? 'Update Log' : 'Record Log';

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
                    // Capitalize first letter for display
                    child: Text(status.name[0].toUpperCase() + status.name.substring(1)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedStatus = val!;
                    if (val == LogStatus.skipped) _foodController.clear();
                  });
                },
              ),
              const SizedBox(height: 15),
              if (_selectedStatus == LogStatus.deviated)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.orange),
                    title: Text(_deviationTime == null
                        ? 'Select Deviation Time *'
                        : 'Deviation Time: ${_deviationTime!.format(context)}'),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _selectDeviationTime(context),
                  ),
                ),
              const SizedBox(height: 15),
              // 2. Food Eaten Input
              if (_selectedStatus != LogStatus.skipped)
                TextFormField(
                  controller: _foodController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _selectedStatus == LogStatus.deviated
                        ? 'Actual Food Eaten (Mandatory)'
                        : 'Food Eaten (e.g., 2 eggs, 1 toast)',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_selectedStatus != LogStatus.skipped && (value == null || value.trim().isEmpty)) {
                      return 'Food entry is required.';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 15),

              // 3. Client Query / Question
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

              // 4. Photo Capture/Upload Section
              const Text('Meal Photo (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- Capture Button ---
                  _selectedPhoto == null
                      ? Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Photo'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade600),
                    ),
                  )
                      : const SizedBox.shrink(),

                  // --- Upload Button ---
                  _selectedPhoto == null ? const SizedBox(width: 8) : const SizedBox.shrink(),
                  _selectedPhoto == null
                      ? Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload'),
                    ),
                  )
                      : const SizedBox.shrink(),
                ],
              ),

              // 5. Preview & Status
              if (_selectedPhotos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected: ${_selectedPhotos.length} images', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Total Size: ${_totalPhotoSizeKB.toStringAsFixed(1)} KB (Originals)', style: TextStyle(color: Colors.orange.shade700, fontSize: 13)),
                      Text('Will be compressed to ~20KB each.', style: TextStyle(color: Colors.green.shade700, fontSize: 11)),
                      const SizedBox(height: 10),

                      // --- Image Preview Row ---
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _selectedPhotos.map((photo) {
                          return GestureDetector(
                            onTap: () => _showEnlargedPreview(context, photo), // 🎯 Tap to Enlarge
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
                )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleLogSubmission,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Record Log'),
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

void showLogModificationDialog(BuildContext context, DietPlanNotifier notifier, String mealName, ClientDietPlanModel activePlan, {ClientLogModel? logToEdit}) {
  showDialog(
    context: context,
    builder: (context) {
      return _MealLogEntryDialog(
        notifier: notifier,
        mealName: mealName,
        activePlan: activePlan,
        logToEdit: logToEdit,
      );
    },
  );
}