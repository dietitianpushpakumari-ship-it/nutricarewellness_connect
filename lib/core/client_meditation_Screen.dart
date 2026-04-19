import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_shift/core/clinical_master_service.dart';
import 'package:pure_shift/core/utils/CloudinaryService.dart';
import 'package:pure_shift/new/models/vitals_model.dart';
import 'package:pure_shift/new/utils/image_compressor.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/dATA/services/vitals_service.dart' hide vitalsServiceProvider;
import 'package:pure_shift/features/auth/auth_provider.dart';
import '../new/models/prescription_model.dart';

// 🚀 IMPORT CLOUDINARY SERVIC

// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

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
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final currentClient = ref.watch(currentClientProvider);
    final tenantId = currentClient?.tenantId ?? '';

    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
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
                            color: cs.primary.withOpacity(isDark ? 0.1 : 0.05),
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
                _buildHeader(context, theme, cs, isDark),
                Expanded(
                  child: vitalsAsync.when(
                    loading: () => Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2)),
                    error: (e, s) => Center(child: Text("Error: $e", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: cs.error))),
                    data: (history) {
                      if (_latestRecord == null && history.isNotEmpty) {
                        final sorted = List<VitalsModel>.from(history)
                          ..sort((a, b) => b.date.compareTo(a.date));
                        _latestRecord = sorted.first;
                        _currentMeds = List.from(_latestRecord!.medications);
                      }

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentMeds.isEmpty)
                              _buildEmptyState(theme, cs)
                            else
                              ..._currentMeds
                                  .asMap()
                                  .entries
                                  .map((e) => _buildMedCard(e.key, e.value, theme, cs, isDark))
                                  .toList(),

                            const SizedBox(height: 24),

                            // 🎯 COMPACT ADD BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _showAddMedicationSheet(context, tenantId);
                                },
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: const Text("ADD NEW MEDICATION", style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primaryContainer.withOpacity(isDark ? 0.2 : 0.5),
                                    foregroundColor: cs.primary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: cs.primary.withOpacity(0.2), width: 1.5)
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
    setState(() => _currentMeds.add(med));
    await _saveChanges();
  }

  Future<void> _removeMedication(int index) async {
    setState(() => _currentMeds.removeAt(index));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- WIDGETS ---

  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme cs, bool isDark) {
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
                onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: theme.iconTheme.color))),
            const SizedBox(width: 16),
            Expanded(
                child: Text("MY MEDICATIONS",
                    style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: cs.onSurface))),
            if (_isSaving)
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
          ]),
        ),
      ),
    );
  }

  Widget _buildMedCard(int index, PrescribedMedicine med, ThemeData theme, ColorScheme cs, bool isDark) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.delete_sweep_rounded, color: cs.onError, size: 24),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
                  const SizedBox(width: 10),
                  Text("Delete Medication?", style: TextStyle(fontFamily: kDisplayFont, color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              content: Text("Are you sure you want to remove ${med.name} from your list?", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, height: 1.5)),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("CANCEL", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, color: theme.hintColor, fontWeight: FontWeight.w700))),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError, elevation: 0),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("DELETE", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) => _removeMedication(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.primaryContainer.withOpacity(isDark ? 0.3 : 0.5), shape: BoxShape.circle),
              child: Icon(Icons.medication_rounded, color: cs.primary, size: 16),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name, style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w700, fontSize: 12, color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text("${med.frequency} • ${med.instruction}", style: TextStyle(fontFamily: kBodyFont, color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.w500))
                    ])),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
        child: Column(children: [
          Icon(Icons.medication_liquid_rounded, size: 40, color: theme.dividerColor),
          const SizedBox(height: 16),
          Text("No medications listed.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor))
        ])
    );
  }
}

// -----------------------------------------------------------------------------
// 🎯 BOTTOM SHEET FOR ADDING MEDICATION
// -----------------------------------------------------------------------------
// 🚀 Converted to ConsumerStatefulWidget to access Cloudinary Service
class _AddMedicationSheet extends ConsumerStatefulWidget {
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
  ConsumerState<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends ConsumerState<_AddMedicationSheet> {
  String _selectedMedicineName = "";
  final TextEditingController _manualController = TextEditingController();

  String _freq = "1-0-1";
  String _time = "After Food";
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    HapticFeedback.mediumImpact();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      File file = File(picked.path);
      File? compressed = await ImageCompressor.compressAndGetFile(file);
      setState(() => _selectedImage = compressed ?? file);
    }
  }

  Future<void> _handleAdd() async {
    if (_manualController.text.isEmpty && _selectedMedicineName.isEmpty) return;

    final medName = _manualController.text.isNotEmpty ? _manualController.text : _selectedMedicineName;
    if (medName.isEmpty) return;

    HapticFeedback.heavyImpact();
    setState(() => _isUploading = true);

    String? photoUrl;

    if (_selectedImage != null) {
      try {
        // 🚀 IMPLEMENTED CLOUDINARY
        photoUrl = await ref.read(cloudinaryServiceProvider).uploadFile(
          file: _selectedImage!,
          folderName: 'medications',
        );
      } catch (e) {
        debugPrint("Cloudinary upload error: $e");
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
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final inputFillColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50;

    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1))
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("PRESCRIPTION LOG", style: TextStyle(fontFamily: kDisplayFont, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: theme.hintColor.withOpacity(0.6))),
                    const SizedBox(height: 2),
                    Text("Add Medication", style: TextStyle(fontFamily: kDisplayFont, fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  ],
                ),
                IconButton(icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20), onPressed: () => Navigator.pop(context))
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: inputFillColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                      image: _selectedImage != null ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover) : null,
                    ),
                    child: _selectedImage == null ? Icon(Icons.camera_alt_rounded, size: 18, color: theme.hintColor.withOpacity(0.5)) : null,
                  ),
                ),
                const SizedBox(width: 12),

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
                          if (_manualController.text.isEmpty && textController.text.isNotEmpty) textController.clear();
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w600),
                            onChanged: (val) => _manualController.text = val,
                            decoration: InputDecoration(
                              labelText: "MEDICINE NAME",
                              labelStyle: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1.0),
                              prefixIcon: Icon(Icons.search_rounded, size: 16, color: theme.hintColor.withOpacity(0.5)),
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.05))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              color: theme.cardColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
                              child: SizedBox(
                                height: 200.0,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8.0),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option, style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurface)),
                                      onTap: () { HapticFeedback.selectionClick(); onSelected(option); },
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

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _freq,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: theme.hintColor),
                    style: TextStyle(fontFamily: kBodyFont, color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "FREQUENCY",
                      labelStyle: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1.0),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.05))),
                    ),
                    items: ["1-0-0", "0-1-0", "0-0-1", "1-0-1", "1-1-1", "SOS"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _freq = v!); },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _time,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: theme.hintColor),
                    style: TextStyle(fontFamily: kBodyFont, color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "TIMING",
                      labelStyle: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1.0),
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.05))),
                    ),
                    items: ["Before Food", "After Food", "Empty Stomach"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _time = v!); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isUploading ? null : _handleAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isUploading
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2))
                    : const Text("SAVE MEDICATION", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            )
          ],
        ),
      ),
    );
  }
}