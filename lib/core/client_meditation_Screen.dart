import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nutricare_connect/core/clinical_master_service.dart';
import 'package:nutricare_connect/core/clinical_model.dart';
// 🎯 IMPORT COMPRESSOR
import 'package:nutricare_connect/core/utils/image_compressor.dart';
import 'package:nutricare_connect/core/utils/local_reminder_service.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';

class ClientMedicationScreen extends ConsumerStatefulWidget {
  final String clientId;
  const ClientMedicationScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientMedicationScreen> createState() => _ClientMedicationScreenState();
}

class _ClientMedicationScreenState extends ConsumerState<ClientMedicationScreen> {
  // ... (Keep existing state variables: _masterService, _isSaving, _latestRecord, _currentMeds)
  final ClinicalMasterService _masterService = ClinicalMasterService();
  bool _isSaving = false;
  VitalsModel? _latestRecord;
  List<PrescribedMedication> _currentMeds = [];

  @override
  Widget build(BuildContext context) {
    final vitalsAsync = ref.watch(vitalsHistoryProvider(widget.clientId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Stack(
        children: [
          Positioned(top: -100, right: -80, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 80, spreadRadius: 30)]))),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: vitalsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Error: $e")),
                    data: (history) {
                      if (_latestRecord == null && history.isNotEmpty) {
                        final sorted = List<VitalsModel>.from(history)..sort((a, b) => b.date.compareTo(a.date));
                        _latestRecord = sorted.first;
                        _currentMeds = List.from(_latestRecord!.prescribedMedications);
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentMeds.isEmpty) _buildEmptyState()
                            else ..._currentMeds.asMap().entries.map((e) => _buildMedCard(e.key, e.value)).toList(),

                            const SizedBox(height: 24),
                            const Text("Add New Medication", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                              child: _ClientMedicationEntryRow(
                                masterService: _masterService,
                                clientId: widget.clientId,
                                onAdd: (med) => _addMedication(med),
                              ),
                            ),
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

  // ... (Keep _addMedication, _removeMedication, _toggleReminder, _saveChanges, _buildHeader, _buildEmptyState, _buildMedCard EXACTLY as they were)
  // To save space, I am only showing the MODIFIED Entry Row below.

  Future<void> _addMedication(PrescribedMedication med) async {
    setState(() { _currentMeds.add(med); _saveChanges(); });
  }
  Future<void> _removeMedication(int index) async {
    setState(() { _currentMeds.removeAt(index); _saveChanges(); });
  }
  Future<void> _toggleReminder(int index, PrescribedMedication med) async {
    final updated = med.copyWith(isReminderEnabled: !med.isReminderEnabled);
    setState(() { _currentMeds[index] = updated; _saveChanges(); });
  }
  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final base = _latestRecord ?? VitalsModel(id: '', clientId: widget.clientId, date: DateTime.now(), weightKg: 0, heightCm: 0, bmi: 0, idealBodyWeightKg: 0, bodyFatPercentage: 0, isFirstConsultation: false);
      final updatedRecord = base.copyWith(prescribedMedications: _currentMeds);
      await VitalsService().saveVitals(updatedRecord);
      await LocalReminderService().scheduleMedicationReminders(_currentMeds);
      ref.refresh(vitalsHistoryProvider(widget.clientId));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }


  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1)))),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: const Icon(Icons.arrow_back, size: 20))),
            const SizedBox(width: 16),
            const Expanded(child: Text("My Medications", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)))),
            if (_isSaving) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          ]),
        ),
      ),
    );
  }

  Widget _buildMedCard(int index, PrescribedMedication med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
            child: med.photoUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: med.photoUrl!, fit: BoxFit.cover))
                : const Icon(Icons.medication, color: Colors.teal),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(med.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("${med.frequency} • ${med.timing}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
          IconButton(icon: Icon(med.isReminderEnabled ? Icons.notifications_active : Icons.notifications_none, color: med.isReminderEnabled ? Colors.orange : Colors.grey), onPressed: () => _toggleReminder(index, med)),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeMedication(index))
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Container(padding: const EdgeInsets.all(20), width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: const Column(children: [Icon(Icons.medication_liquid, size: 40, color: Colors.grey), SizedBox(height: 8), Text("No medications listed.", style: TextStyle(color: Colors.grey))]));
}

// --- UPDATED ENTRY ROW ---
class _ClientMedicationEntryRow extends StatefulWidget {
  final ClinicalMasterService masterService;
  final String clientId;
  final Function(PrescribedMedication) onAdd;

  const _ClientMedicationEntryRow({required this.masterService, required this.clientId, required this.onAdd});

  @override
  State<_ClientMedicationEntryRow> createState() => _ClientMedicationEntryRowState();
}

class _ClientMedicationEntryRowState extends State<_ClientMedicationEntryRow> {
  final _nameCtrl = TextEditingController();
  String _freq = "1-0-1";
  String _time = "After Food";
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    // 1. Pick High Quality
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      // 🎯 2. COMPRESS IT
      File? compressed = await ImageCompressor.compressAndGetFile(File(picked.path));
      setState(() => _selectedImage = compressed ?? File(picked.path));
    }
  }

  Future<void> _handleAdd() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _isUploading = true);
    String? photoUrl;

    if (_selectedImage != null) {
      try {
        // Upload Compressed Image
        final ref = FirebaseStorage.instance.ref().child('meds/${widget.clientId}/${DateTime.now().millisecondsSinceEpoch}.webp');
        await ref.putFile(_selectedImage!);
        photoUrl = await ref.getDownloadURL();
      } catch (e) {
        print("Image upload error: $e");
      }
    }

    widget.onAdd(PrescribedMedication(
      medicineName: _nameCtrl.text,
      frequency: _freq,
      timing: _time,
      photoUrl: photoUrl,
    ));

    setState(() { _nameCtrl.clear(); _selectedImage = null; _isUploading = false; });
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
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  image: _selectedImage != null ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover) : null,
                ),
                child: _selectedImage == null ? const Icon(Icons.camera_alt, color: Colors.grey) : null,
              ),
            ),
            const SizedBox(width: 12),
            // Name Input
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: widget.masterService.streamItemNames(ClinicalMasterService.colMedicines),
                builder: (context, snapshot) {
                  final options = snapshot.data ?? [];
                  return RawAutocomplete<String>(
                    optionsBuilder: (val) => val.text.isEmpty ? const Iterable<String>.empty() : options.where((opt) => opt.toLowerCase().contains(val.text.toLowerCase())),
                    onSelected: (val) => _nameCtrl.text = val,
                    fieldViewBuilder: (ctx, controller, node, onSubmitted) {
                      controller.addListener(() => _nameCtrl.text = controller.text);
                      return TextField(controller: controller, focusNode: node, decoration: InputDecoration(labelText: "Medicine Name", prefixIcon: const Icon(Icons.search, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)));
                    },
                    optionsViewBuilder: (ctx, onSelected, opts) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, child: SizedBox(width: 200, height: 200, child: ListView.builder(itemCount: opts.length, itemBuilder: (c, i) => ListTile(title: Text(opts.elementAt(i)), onTap: () => onSelected(opts.elementAt(i))))))),
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
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10), border: OutlineInputBorder()),
                items: ["1-0-0", "0-1-0", "0-0-1", "1-0-1", "1-1-1", "SOS"].map((e)=>DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _freq = v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _time,
                isExpanded: true,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10), border: OutlineInputBorder()),
                items: ["Before Food", "After Food", "Empty Stomach"].map((e)=>DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _time = v!),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _isUploading ? null : _handleAdd, icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add), style: IconButton.styleFrom(backgroundColor: Colors.teal))
          ],
        )
      ],
    );
  }
}