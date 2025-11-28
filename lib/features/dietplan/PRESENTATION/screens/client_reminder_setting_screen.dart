import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:nutricare_connect/main.dart';

import 'package:nutricare_connect/services/client_service.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart' hide clientServiceProvider;

class ClientReminderSettingsScreen extends ConsumerStatefulWidget {
  final ClientModel client;

  const ClientReminderSettingsScreen({super.key, required this.client});

  @override
  ConsumerState<ClientReminderSettingsScreen> createState() =>
      _ClientReminderSettingsScreenState();
}

class _ClientReminderSettingsScreenState extends ConsumerState<ClientReminderSettingsScreen> {
  late ClientReminderConfig _config;
  bool _isSaving = false;

  // 🎯 Map<Key, Value>
  // Key = 'male_coach_en' (the value to save)
  // Value = 'Male Coach (English)' (the value to display)
  final Map<String, String> _voiceProfiles = {
    'male_coach_en': 'Male Coach (English)',
    'female_coach_en': 'Female Coach (English)',
    'male_coach_hi': 'Male Coach (Hindi)',
    'female_child_en': 'Female Child (English)',
  };

  final Map<String, String> _languageCodes = {
    'en-US': 'English (US)',
    'en-IN': 'English (India)',
    'hi-IN': 'Hindi (India)',
  };

  @override
  void initState() {
    super.initState();
    _config = widget.client.reminderConfig!;
  }

  Future<void> _onSave() async {
    setState(() { _isSaving = true; });
    try {
      final updatedClient = widget.client.copyWith(reminderConfig: _config);

      await ref.read(clientServiceProvider).updateClient(updatedClient);

      // Invalidate the auth provider to get the new client model
      ref.invalidate(clientProfileFutureProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving
                ? const Center(child: Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ))
                : IconButton(icon: const Icon(Icons.save), onPressed: _onSave, tooltip: 'Save Settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- 1. Master Settings (FR-DAT-02) ---
        
            _buildSectionHeader(context, 'Test Voice'),
          Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Tap the button to hear a test message using the currently selected voice profile and language.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.record_voice_over),
                      label: const Text('Play Test Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // 🎯 This calls the global ttsService instance from main.dart
                        ttsService.speak(
                          text: "This is a test of the empathetic reminder system.",
                          languageCode :_config.languageCode,
                          //voice : _config.voiceProfile,
                        );
                      },
                    )]))),
            _buildSectionHeader(context, 'Master Settings'),
            SwitchListTile(
              title: const Text('Enable All Reminders'),
              subtitle: const Text('Master On/Off switch for all notifications.'),
              value: _config.isActive,
              onChanged: (val) => setState(() => _config = _config.copyWith(isActive: val)),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
        
            const Divider(),
        
            // --- 2. Voice Settings (FR-DAT-03, 05, 06 & US-ADM-04) ---
            _buildSectionHeader(context, 'Voice Configuration'),
            SwitchListTile(
              title: const Text('Enable Voice Component'),
              subtitle: const Text('Play reminders out loud (if available).'),
              value: _config.isVoiceActive,
              onChanged: (val) => setState(() => _config = _config.copyWith(isVoiceActive: val)),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            _buildDropdown<String>(
              label: 'Voice Profile (FR-DAT-05)',
              value: _config.voiceProfile,
              items: _voiceProfiles,
              isEnabled: _config.isVoiceActive,
              onChanged: (val) => setState(() => _config = _config.copyWith(voiceProfile: val)),
            ),
            _buildDropdown<String>(
              label: 'Language / Accent (FR-DAT-06)',
              value: _config.languageCode,
              items: _languageCodes,
              isEnabled: _config.isVoiceActive,
              onChanged: (val) => setState(() => _config = _config.copyWith(languageCode: val)),
            ),
        
            const Divider(),
        
            // --- 3. Goal-Based Reminders (FR-GOAL) ---
            _buildSectionHeader(context, 'Goal-Based Reminders'),
            _buildGoalReminderCard(
              title: 'Hydration Reminders (US-ADM-01)',
              settings: _config.hydrationReminder,
              onActiveChanged: (val) {
                setState(() => _config = _config.copyWith(
                    hydrationReminder: _config.hydrationReminder.copyWith(isActive: val)
                ));
              },
              onLevelChanged: (val) {
                setState(() => _config = _config.copyWith(
                    hydrationReminder: _config.hydrationReminder.copyWith(escalationLevel: val)
                ));
              },
            ),
            _buildGoalReminderCard(
              title: 'Step Reminders (US-ADM-03)',
              settings: _config.stepReminder,
              onActiveChanged: (val) {
                setState(() => _config = _config.copyWith(
                    stepReminder: _config.stepReminder.copyWith(isActive: val)
                ));
              },
              onLevelChanged: (val) {
                setState(() => _config = _config.copyWith(
                    stepReminder: _config.stepReminder.copyWith(escalationLevel: val)
                ));
              },
            ),
        
            const Divider(),
        
            // --- 4. Time-Based Reminders (FR-TIME) ---
            _buildSectionHeader(context, 'Time-Based Reminders'),
            _buildTimeReminderCard(
              title: 'Medicine Reminder',
              settings: _config.medicineReminder,
              onActiveChanged: (val) {
                setState(() => _config = _config.copyWith(
                    medicineReminder: _config.medicineReminder.copyWith(isActive: val)
                ));
              },
              onTimeChanged: (newTime) {
                setState(() => _config = _config.copyWith(
                    medicineReminder: _config.medicineReminder.copyWith(time: newTime)
                ));
              },
            ),
            _buildTimeReminderCard(
              title: 'End-of-Day Log Reminder',
              settings: _config.dietRoutineReminder,
              onActiveChanged: (val) {
                setState(() => _config = _config.copyWith(
                    dietRoutineReminder: _config.dietRoutineReminder.copyWith(isActive: val)
                ));
              },
              onTimeChanged: (newTime) {
                setState(() => _config = _config.copyWith(
                    dietRoutineReminder: _config.dietRoutineReminder.copyWith(time: newTime)
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Widgets ---

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 🎯 CRITICAL FIX: Swapped entry.key and entry.value
  Widget _buildDropdown<T>(
      {required String label, required T value, required Map<T, String> items, required bool isEnabled, required ValueChanged<T?> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          disabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        // Ensure the value exists in the map keys, otherwise provide a fallback
        value: items.containsKey(value) ? value : items.keys.first,
        items: items.entries.map((entry) {
          return DropdownMenuItem<T>(
            value: entry.key, // ⬅️ FIX: The value is the Key (e.g., 'male_coach_en')
            child: Text(entry.value), // ⬅️ FIX: The child is the Value (e.g., 'Male Coach (English)')
          );
        }).toList(),
        onChanged: isEnabled ? onChanged : null,
      ),
    );
  }

  Widget _buildGoalReminderCard({
    required String title,
    required GoalReminderSettings settings,
    required ValueChanged<bool> onActiveChanged,
    required ValueChanged<ReminderEscalation> onLevelChanged,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              value: settings.isActive,
              onChanged: onActiveChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: DropdownButtonFormField<ReminderEscalation>(
                decoration: const InputDecoration(
                  labelText: 'Persistence Level',
                  border: OutlineInputBorder(),
                ),
                value: settings.escalationLevel,
                items: ReminderEscalation.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level.name.capitalize()),
                  );
                }).toList(),
                onChanged: settings.isActive ? (val) {
                  if (val != null) onLevelChanged(val);
                } : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeReminderCard({
    required String title,
    required TimeReminderSettings settings,
    required ValueChanged<bool> onActiveChanged,
    required ValueChanged<TimeOfDay> onTimeChanged,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              value: settings.isActive,
              onChanged: onActiveChanged,
            ),
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('Reminder Time'),
              trailing: Text(settings.time.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: settings.isActive ? () async {
                final newTime = await showTimePicker(
                  context: context,
                  initialTime: settings.time,
                );
                if (newTime != null) {
                  onTimeChanged(newTime);
                }
              } : null,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper extension
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}