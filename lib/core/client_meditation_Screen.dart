import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nutricare_connect/core/clinical_master_service.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/utils/image_compressor.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart' hide vitalsServiceProvider;

import 'package:nutricare_connect/features/auth/auth_provider.dart';
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
  List<PrescribedMedicine> _currentMeds = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final currentClient = ref.watch(currentClientProvider);
    final tenantId = currentClient?.tenantId ?? '';

    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Decor Glow
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
                            color: colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05),
                            blurRadius: 80,
                            spreadRadius: 30
                        )
                      ]
                  )
              )
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, theme, colorScheme, isDark),
                Expanded(
                  child: vitalsAsync.when(
                    loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
                    error: (e, s) => Center(child: Text("Error: $e", style: TextStyle(color: colorScheme.error))),
                    data: (history) {
                      if (_latestRecord == null && history.isNotEmpty) {
                        final sorted = List<VitalsModel>.from(history)
                          ..sort((a, b) => b.date.compareTo(a.date));
                        _latestRecord = sorted.first;
                        _currentMeds = List.from(_latestRecord!.medications);
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentMeds.isEmpty)
                              _buildEmptyState(theme)
                            else
                              ..._currentMeds
                                  .asMap()
                                  .entries
                                  .map((e) => _buildMedCard(e.key, e.value, theme, colorScheme, isDark))
                                  .toList(),

                            const SizedBox(height: 24),

                            // 🎯 COMPACT ADD BUTTON
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddMedicationSheet(context, tenantId),
                                icon: const Icon(Icons.add_circle_outline_rounded),
                                label: const Text("Add New Medication", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: colorScheme.primaryContainer.withOpacity(isDark ? 0.2 : 0.5),
                                    foregroundColor: colorScheme.primary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: colorScheme.primary.withOpacity(0.3), width: 1.5)
                                    )
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
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

  void _showAddMedicationSheet(BuildContext context, String tenantId) {
    showModalBottomSheet(
      isDismissible: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMedicationSheet(
        masterService: _masterService,
        clientId: widget.clientId,
        tenantId: tenantId,
        onAdd: (med) {
          _addMedication(med);
          Navigator.pop(context);
        },
      ),
    );
  }

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

      final vitalsService = ref.read(vitalsServiceProvider);
      await vitalsService.saveVitals(updatedRecord);

      ref.refresh(vitalsHistoryProvider(widget.clientId));
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error saving: $e"),
              backgroundColor: theme.colorScheme.error,
            )
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- WIDGETS ---

  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.8),
              border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)))
          ),
          child: Row(children: [
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)]
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.iconTheme.color))),
            const SizedBox(width: 16),
            Expanded(
                child: Text("My Medications",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
            if (_isSaving)
              SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
          ]),
        ),
      ),
    );
  }

  // 🎯 REPLACED DELETE BUTTON WITH SWIPE-TO-DELETE DISMISSIBLE WIDGET
  Widget _buildMedCard(int index, PrescribedMedicine med, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Dismissible(
      key: UniqueKey(), // Must be unique so Flutter knows which item is removed
      direction: DismissDirection.endToStart, // Swipe right-to-left
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_sweep_rounded, color: colorScheme.onError, size: 30),
      ),
      confirmDismiss: (direction) async {
        // 🎯 Show beautifully themed confirmation dialog
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.5))
              ),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                  const SizedBox(width: 10),
                  Text("Delete Medication?", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Text(
                "Are you sure you want to remove ${med.name} from your list?",
                style: TextStyle(color: theme.hintColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("Cancel", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _removeMedication(index);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 10)
            ]),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.medication_rounded, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                      Text("${med.frequency} • ${med.instruction}",
                          style: TextStyle(color: theme.hintColor, fontSize: 12))
                    ])),
            // Removed trailing icon button as requested
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.5))),
        child: Column(children: [
          Icon(Icons.medication_liquid_rounded, size: 40, color: theme.disabledColor),
          const SizedBox(height: 8),
          Text("No medications listed.", style: TextStyle(color: theme.hintColor))
        ])
    );
  }
}

// -----------------------------------------------------------------------------
// 🎯 BOTTOM SHEET FOR ADDING MEDICATION
// -----------------------------------------------------------------------------

class _AddMedicationSheet extends StatefulWidget {
  final ClinicalMasterService masterService;
  final String clientId;
  final String tenantId;
  final Function(PrescribedMedicine) onAdd;

  const _AddMedicationSheet({
    required this.masterService,
    required this.clientId,
    required this.tenantId,
    required this.onAdd
  });

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
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
      File? compressed = await ImageCompressor.compressAndGetFile(file);
      setState(() => _selectedImage = compressed ?? file);
    }
  }

  Future<void> _handleAdd() async {
    if (_manualController.text.isEmpty && _selectedMedicineName.isEmpty) return;

    final medName = _manualController.text.isNotEmpty
        ? _manualController.text
        : _selectedMedicineName;

    if (medName.isEmpty) return;

    setState(() => _isUploading = true);

    String? photoUrl;

    if (_selectedImage != null) {
      try {
        final ref = FirebaseStorage.instance.ref().child(
            'tenants/${widget.tenantId}/meds/${widget.clientId}/${DateTime.now().millisecondsSinceEpoch}.webp');
        await ref.putFile(_selectedImage!);
        photoUrl = await ref.getDownloadURL();
      } catch (e) {
        debugPrint("Image upload error: $e");
      }
    }

    widget.onAdd(PrescribedMedicine(
      name: medName,
      frequency: _freq,
      instruction: _time,
      // photoUrl: photoUrl // Uncomment if your model supports it
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final inputFillColor = isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100;

    return Container(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20
      ),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Add Medication", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                IconButton(
                    icon: Icon(Icons.close, color: theme.iconTheme.color),
                    onPressed: () => Navigator.pop(context)
                )
              ],
            ),
            Divider(color: theme.dividerColor.withOpacity(0.5)),
            const SizedBox(height: 16),

            // Name and Image Row
            Row(
              children: [
                // Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: inputFillColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                      image: _selectedImage != null
                          ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _selectedImage == null
                        ? Icon(Icons.camera_alt_rounded, color: theme.iconTheme.color?.withOpacity(0.5))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Autocomplete Field
                Expanded(
                  child: StreamBuilder<List<String>>(
                    stream: widget.masterService.streamItemNames(ClinicalMasterService.colMedicines),
                    builder: (context, snapshot) {
                      final options = snapshot.data ?? [];

                      return RawAutocomplete<String>(
                        key: ValueKey(_isUploading),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                          return options.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String selection) {
                          setState(() {
                            _selectedMedicineName = selection;
                            _manualController.text = selection;
                          });
                        },
                        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                          if (_manualController.text.isEmpty && textController.text.isNotEmpty) {
                            textController.clear();
                          }
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                            onChanged: (val) => _manualController.text = val,
                            decoration: InputDecoration(
                                labelText: "Medicine Name",
                                labelStyle: TextStyle(color: theme.hintColor),
                                prefixIcon: Icon(Icons.search_rounded, size: 18, color: theme.hintColor),
                                filled: true,
                                fillColor: inputFillColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.primary)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16)
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8.0,
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 200.0,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8.0),
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option, style: TextStyle(color: colorScheme.onSurface)),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Frequency and Timing Dropdowns
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _freq,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: "Frequency",
                      labelStyle: TextStyle(color: theme.hintColor),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: ["1-0-0", "0-1-0", "0-0-1", "1-0-1", "1-1-1", "SOS"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _freq = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _time,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: "Timing",
                      labelStyle: TextStyle(color: theme.hintColor),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: ["Before Food", "After Food", "Empty Stomach"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _time = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _handleAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isUploading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2))
                    : const Text("Save Medication", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}