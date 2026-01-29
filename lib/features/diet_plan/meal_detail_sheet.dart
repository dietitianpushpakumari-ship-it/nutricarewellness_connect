import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart'; // For access to meal items if needed

class MealDetailSheet extends ConsumerStatefulWidget {
  final DietPlanNotifier notifier;
  final String mealName;
  final ClientDietPlanModel activePlan;
  final ClientLogModel? logToEdit;

  // Optional: Pass planned items to pre-fill "Ate Plan"
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

  List<XFile> _selectedPhotos = [];
  TimeOfDay? _deviationTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.logToEdit != null) {
      _initEditMode(widget.logToEdit!);
    } else {
      // Default: Pre-fill with planned items if available, else empty slot
      _initCreationMode();
    }
  }

  void _initEditMode(ClientLogModel log) {
    _status = log.logStatus;
    _notesController.text = log.clientQuery ?? '';

    if (log.deviationTime != null) {
      _deviationTime = TimeOfDay.fromDateTime(log.deviationTime!);
    }

    if (log.actualFoodEaten.isNotEmpty) {
      for (var food in log.actualFoodEaten) {
        _foodControllers.add(TextEditingController(text: food));
      }
    } else {
      _foodControllers.add(TextEditingController());
    }
  }

  void _initCreationMode() {
    if (widget.plannedItems.isNotEmpty) {
      // Pre-fill with planned items for convenience
      for (var item in widget.plannedItems) {
        _foodControllers.add(TextEditingController(text: item.foodItemName));
      }
    } else {
      _foodControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (var c in _foodControllers) c.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  void _addFoodField() {
    setState(() => _foodControllers.add(TextEditingController()));
  }

  void _removeFoodField(int index) {
    if (_foodControllers.length > 1) {
      setState(() {
        _foodControllers[index].dispose();
        _foodControllers.removeAt(index);
      });
    } else {
      _foodControllers[index].clear();
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() => _selectedPhotos.add(image));
    }
  }

  Future<void> _saveLog() async {
    setState(() => _isSaving = true);

    try {
      // 1. Collect Food List
      List<String> foodList = [];
      if (_status == LogStatus.skipped) {
        foodList = ["Skipped"];
      } else {
        foodList = _foodControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }

      if (foodList.isEmpty && _status != LogStatus.skipped) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter at least one food item.")));
        setState(() => _isSaving = false);
        return;
      }

      // 2. Prepare Model
      final baseLog = widget.logToEdit ?? ClientLogModel(
        id: '',
        clientId: widget.activePlan.clientId,
        dietPlanId: widget.activePlan.id,
        mealName: widget.mealName,
        actualFoodEaten: [],
        date: widget.notifier.state.selectedDate,
      );

      final logToSave = baseLog.copyWith(
        logStatus: _status,
        isDeviation: _status == LogStatus.deviated,
        actualFoodEaten: foodList,
        clientQuery: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        deviationTime: _deviationTime != null ? DateTime(
            widget.notifier.state.selectedDate.year,
            widget.notifier.state.selectedDate.month,
            widget.notifier.state.selectedDate.day,
            _deviationTime!.hour,
            _deviationTime!.minute
        ) : null,
        // Keep existing URLs if no new photos added, logic handled in provider/service usually
        mealPhotoUrls: _selectedPhotos.isEmpty ? baseLog.mealPhotoUrls : [],
      );

      // 3. Save
      await widget.notifier.createOrUpdateLog(log: logToSave, mealPhotoFiles: _selectedPhotos);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meal Logged!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // 1. Header
            const SizedBox(height: 16),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.mealName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text("Log your intake", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        _status.name.toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(_status))
                    ),
                  ),
                ],
              ),
            ),
      
            // 2. Status Selector (The 3 Paths)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _buildStatusBtn(LogStatus.followed, "Ate Plan", Icons.check_circle)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusBtn(LogStatus.deviated, "Deviated", Icons.warning_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusBtn(LogStatus.skipped, "Skipped", Icons.block)),
                ],
              ),
            ),
            const Divider(height: 40),
      
            // 3. Dynamic Content Area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  if (_status == LogStatus.skipped)
                    _buildSkippedView()
                  else
                    _buildFoodInputView(),
      
                  const SizedBox(height: 20),
      
                  // Notes / Query
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: "Notes or Questions?",
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    maxLines: 2,
                  ),
      
                  const SizedBox(height: 20),
      
                  // Photos
                  if (_status != LogStatus.skipped)
                    _buildPhotoSection(),
      
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
      
            // 4. Floating Save Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildStatusBtn(LogStatus status, String label, IconData icon) {
    final isSelected = _status == status;
    final color = _getStatusColor(status);

    return GestureDetector(
      onTap: () => setState(() => _status = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0,4))] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkippedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          "No worries! Consistency is key. Just let us know if there was a specific reason below.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildFoodInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_status == LogStatus.deviated)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if(t != null) setState(() => _deviationTime = t);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Time of Deviation",
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  prefixIcon: Icon(Icons.access_time, color: Colors.orange),
                ),
                child: Text(_deviationTime?.format(context) ?? "Select Time"),
              ),
            ),
          ),

        const Text("What did you eat?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),

        ..._foodControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Item ${index + 1}",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                if (_foodControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _removeFoodField(index),
                  ),
              ],
            ),
          );
        }).toList(),

        TextButton.icon(
          onPressed: _addFoodField,
          icon: const Icon(Icons.add),
          label: const Text("Add Item"),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Add Photo (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Camera Button
              GestureDetector(
                onTap: () => _pickPhoto(ImageSource.camera),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
                  child: const Icon(Icons.camera_alt, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 10),
              // Gallery Button
              GestureDetector(
                onTap: () => _pickPhoto(ImageSource.gallery),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: const Icon(Icons.photo_library, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 10),
              // Previews
              ..._selectedPhotos.map((file) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(file.path), width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPhotos.remove(file)),
                        child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(LogStatus status) {
    switch (status) {
      case LogStatus.followed: return Colors.green;
      case LogStatus.deviated: return Colors.orange;
      case LogStatus.skipped: return Colors.grey;
      default: return Colors.blue;
    }
  }
}