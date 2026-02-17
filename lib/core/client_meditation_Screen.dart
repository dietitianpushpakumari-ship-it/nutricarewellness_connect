import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nutricare_connect/core/clinical_master_service.dart';
// Ensure this path is correct for your project structure
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/core/utils/image_compressor.dart';
import 'package:nutricare_connect/core/utils/local_reminder_service.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart';

import '../new/models/prescription_model.dart';

class ClientMedicationScreen extends ConsumerStatefulWidget {
  final String clientId;
  const ClientMedicationScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientMedicationScreen> createState() => _ClientMedicationScreenState();
}

class _ClientMedicationScreenState extends ConsumerState<ClientMedicationScreen> {
  final ClinicalMasterService _masterService = ClinicalMasterService();
  bool _isSaving = false;
  VitalsModel? _latestRecord;
  List<PrescribedMedicine> _currentMeds = []; // Used PrescribedMedicine based on your VitalsModel

  @override
  Widget build(BuildContext context) {
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Stack(
        children: [
          // Background Decor
          Positioned(
              top: -100,
              right: -80,
              child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.teal.withOpacity(0.1),
                            blurRadius: 80,
                            spreadRadius: 30)
                      ]))),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: vitalsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: $e")),
                    data: (history) {
                      // Initialize data once when history is loaded
                      if (_latestRecord == null && history.isNotEmpty) {
                        final sorted = List<VitalsModel>.from(history)
                          ..sort((a, b) => b.date.compareTo(a.date));
                        _latestRecord = sorted.first;
                        _currentMeds = List.from(_latestRecord!.medications); // Use medications list
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentMeds.isEmpty)
                              _buildEmptyState()
                            else
                              ..._currentMeds
                                  .asMap()
                                  .entries
                                  .map((e) => _buildMedCard(e.key, e.value))
                                  .toList(),

                            const SizedBox(height: 24),
                            const Text("Add New Medication",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10)
                                  ]),
                              child: _ClientMedicationEntryRow(
                                masterService: _masterService,
                                clientId: widget.clientId,
                                onAdd: (med) => _addMedication(med),
                              ),
                            ),
                            const SizedBox(height: 40), // Bottom padding
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ACTIONS ---

  Future<void> _addMedication(PrescribedMedicine med) async {
    setState(() {
      _currentMeds.add(med);
    });
    await _saveChanges();
  }

  Future<void> _removeMedication(int index) async {
    setState(() {
      _currentMeds.removeAt(index);
    });
    await _saveChanges();
  }

  Future<void> _toggleReminder(int index, PrescribedMedicine med) async {
    // Note: Assuming PrescribedMedicine has 'isReminderEnabled'.
    // If not, you need to add it to the model or handle reminders separately.
    // For now, I'll assume standard model structure:
    /*
    final updated = med.copyWith(isReminderEnabled: !med.isReminderEnabled);
    setState(() {
      _currentMeds[index] = updated;
    });
    await _saveChanges();
    */
    // Placeholder if property doesn't exist yet:
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder toggled (Model update required)")));
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final base = _latestRecord ??
          VitalsModel(
              id: '',
              clientId: widget.clientId,
              date: DateTime.now(),
              weightKg: 0,
              heightCm: 0,
              bmi: 0,
              idealBodyWeightKg: 0,
              bodyFatPercentage: 0,
              medications: []);

      final updatedRecord = base.copyWith(medications: _currentMeds);

      await VitalsService().saveVitals(updatedRecord);

      // Update local reminders (Assuming you have logic to map meds to notifications)
      // await LocalReminderService().scheduleMedicationReminders(_currentMeds);

      ref.refresh(vitalsHistoryProvider(widget.clientId));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error saving: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- WIDGETS ---

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.1)))),
          child: Row(children: [
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10)
                        ]),
                    child: const Icon(Icons.arrow_back, size: 20))),
            const SizedBox(width: 16),
            const Expanded(
                child: Text("My Medications",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A)))),
            if (_isSaving)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
          ]),
        ),
      ),
    );
  }

  Widget _buildMedCard(int index, PrescribedMedicine med) {
    // Assuming model has photoUrl or similar field. If not, remove checks.
    // PrescribedMedicine usually has: name, dosage, frequency, instruction...
    // Adjust fields below based on your specific 'PrescribedMedicine' model definition.

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
          ]),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.medication, color: Colors.teal),
            // If you have photoUrl:
            // child: med.photoUrl != null
            //    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: med.photoUrl!, fit: BoxFit.cover))
            //    : const Icon(Icons.medication, color: Colors.teal),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, // Changed from medicineName to name (common convention)
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("${med.frequency} • ${med.instruction}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                  ])),
          // Reminder Toggle
          // IconButton(icon: Icon(med.isReminderEnabled ? Icons.notifications_active : Icons.notifications_none, color: med.isReminderEnabled ? Colors.orange : Colors.grey), onPressed: () => _toggleReminder(index, med)),

          IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _removeMedication(index))
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: const Column(children: [
        Icon(Icons.medication_liquid, size: 40, color: Colors.grey),
        SizedBox(height: 8),
        Text("No medications listed.", style: TextStyle(color: Colors.grey))
      ]));
}

// -----------------------------------------------------------------------------
// 🎯 UPDATED ENTRY ROW WITH FIXES
// -----------------------------------------------------------------------------

class _ClientMedicationEntryRow extends StatefulWidget {
  final ClinicalMasterService masterService;
  final String clientId;
  final Function(PrescribedMedicine) onAdd;

  const _ClientMedicationEntryRow(
      {required this.masterService,
        required this.clientId,
        required this.onAdd});

  @override
  State<_ClientMedicationEntryRow> createState() =>
      _ClientMedicationEntryRowState();
}

class _ClientMedicationEntryRowState extends State<_ClientMedicationEntryRow> {
  // We use a TextEditingController for the TextField inside Autocomplete
  // Note: Autocomplete creates its own controller, but we can capture the text via onSelected or onChanged.
  String _selectedMedicineName = "";
  final TextEditingController _manualController = TextEditingController();

  String _freq = "1-0-1";
  String _time = "After Food";
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      File file = File(picked.path);
      // 🎯 Compress
      File? compressed = await ImageCompressor.compressAndGetFile(file);
      setState(() => _selectedImage = compressed ?? file);
    }
  }

  Future<void> _handleAdd() async {
    if (_manualController.text.isEmpty && _selectedMedicineName.isEmpty) return;

    // Use the manual text if available (handles user typing a name not in list)
    final medName = _manualController.text.isNotEmpty
        ? _manualController.text
        : _selectedMedicineName;

    if (medName.isEmpty) return;

    setState(() => _isUploading = true);
    String? photoUrl;

    if (_selectedImage != null) {
      try {
        final ref = FirebaseStorage.instance.ref().child(
            'meds/${widget.clientId}/${DateTime.now().millisecondsSinceEpoch}.webp');
        await ref.putFile(_selectedImage!);
        photoUrl = await ref.getDownloadURL();
      } catch (e) {
        print("Image upload error: $e");
      }
    }

    widget.onAdd(PrescribedMedicine(
      name: medName,
      frequency: _freq,
      instruction: _time,
      // Add other fields like duration/dosage if your UI supports it
      // photoUrl: photoUrl, // If your model supports it
    ));

    // Reset State
    setState(() {
      _manualController.clear();
      _selectedMedicineName = "";
      _selectedImage = null;
      _isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  image: _selectedImage != null
                      ? DecorationImage(
                      image: FileImage(_selectedImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: _selectedImage == null
                    ? const Icon(Icons.camera_alt, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // 🎯 Fixed Autocomplete
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: widget.masterService
                    .streamItemNames(ClinicalMasterService.colMedicines),
                builder: (context, snapshot) {
                  final options = snapshot.data ?? [];

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return RawAutocomplete<String>(
                        key: ValueKey(_isUploading), // Force rebuild on upload complete to clear text
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return options.where((String option) {
                            return option
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          setState(() {
                            _selectedMedicineName = selection;
                            _manualController.text = selection; // Sync manual controller
                          });
                        },
                        // Custom Input Field
                        fieldViewBuilder: (BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted) {

                          // Sync internal controller with our external one if it was cleared
                          if (_manualController.text.isEmpty && textEditingController.text.isNotEmpty) {
                            textEditingController.clear();
                          }

                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            onChanged: (val) {
                              // Capture text as it is typed
                              _manualController.text = val;
                            },
                            decoration: InputDecoration(
                                labelText: "Medicine Name",
                                prefixIcon: const Icon(Icons.search, size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16)
                            ),
                          );
                        },
                        // Custom Options View (Prevents UI Overflow)
                        optionsViewBuilder: (BuildContext context,
                            AutocompleteOnSelected<String> onSelected,
                            Iterable<String> options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: constraints.maxWidth, // Limit width to parent
                                height: 200.0,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8.0),
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final String option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _freq,
                isExpanded: true,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder()),
                items: ["1-0-0", "0-1-0", "0-0-1", "1-0-1", "1-1-1", "SOS"]
                    .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _freq = v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _time,
                isExpanded: true,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder()),
                items: ["Before Food", "After Food", "Empty Stomach"]
                    .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _time = v!),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
                onPressed: _isUploading ? null : _handleAdd,
                icon: _isUploading
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: Colors.teal))
          ],
        )
      ],
    );
  }
}