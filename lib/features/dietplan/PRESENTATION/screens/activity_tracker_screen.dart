// =================================================================
// --- 🎯 TAB 2: REBUILT ACTIVITY TRACKER SCREEN (Input Hub) ---
// =================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';




// lib/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart

// =================================================================
// --- 🎯 TAB 2: REBUILT ACTIVITY TRACKER SCREEN (Input Hub) ---
// =================================================================

class ActivityTrackerScreen extends ConsumerStatefulWidget {
  final ClientModel client;
  const ActivityTrackerScreen({super.key, required this.client});

  @override
  ConsumerState<ActivityTrackerScreen> createState() => _ActivityTrackerScreenState();
}

class _ActivityTrackerScreenState extends ConsumerState<ActivityTrackerScreen> {

  // Admin-set
  List<String> _mandatoryTasks = [];
  int _stepGoal = 8000;

  // Sensor State
  Stream<StepCount>? _stepCountStream;
  int _sensorSteps = 0; // This is the phone's TOTAL steps
  bool _sensorActive = false;
  String _sensorStatus = "Initializing...";

  // Client-set
  final _personalGoalController = TextEditingController();
  List<String> _personalGoals = [];
  Set<String> _completedPersonalGoals = {};

  // Manual Input State
  final _manualStepsController = TextEditingController();
  Set<String> _completedMandatoryTasks = {};
  bool _isSaving = false;

  bool _isManualEntry = false; // Local toggle

  @override
  void initState() {
    super.initState();
    final bool sensorEnabled = ref.read(stepSensorEnabledProvider);
    if (sensorEnabled) {
      _initPedometer();
    } else {
      _sensorStatus = "Sensor is disabled in settings.";
      _isManualEntry = true;
    }

    // 🎯 CRITICAL FIX 1: Initial Load
    // Read the *initial* state from the provider in initState.
    final initialState = ref.read(activeDietPlanProvider);
    _updateStateFromLog(initialState, isInit: true);
  }

  // 🎯 This method is no longer needed
  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  // }

  /// Populates all local fields from the daily log
  void _updateStateFromLog(DietPlanState state, {bool isInit = false}) {
    final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');
    final activePlan = state.activePlan;

    // Use setState to update the local controllers and lists
    setState(() {
      _stepGoal = activePlan?.dailyStepGoal ?? 8000;
      _mandatoryTasks = activePlan?.mandatoryDailyTasks ?? [];

      final savedStepsText = dailyLog?.stepCount?.toString() ?? '';
      // Only update controller if it's init or the text doesn't match
      if (isInit || _manualStepsController.text != savedStepsText) {
        _manualStepsController.text = savedStepsText;
      }

      _completedMandatoryTasks = dailyLog?.completedMandatoryTasks.toSet() ?? {};
      _personalGoals = dailyLog?.createdPersonalGoals ?? [];
      _completedPersonalGoals = dailyLog?.completedPersonalGoals.toSet() ?? {};
    });
  }

  @override
  void dispose() {
    _manualStepsController.dispose();
    _personalGoalController.dispose();
    super.dispose();
  }

  // --- 🎯 Pedometer & Sensor Logic ---
  void _initPedometer() async {
    var status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((StepCount event) {
        if (mounted) {
          final bool sensorEnabled = ref.read(stepSensorEnabledProvider);
          final bool autoSync = !_isManualEntry && sensorEnabled;

          setState(() {
            _sensorSteps = event.steps; // Live update of TOTAL steps
            _sensorStatus = "Live Tracking: ${event.steps} steps";
            _sensorActive = true;
          });

          if (autoSync) {
            // Auto-sync logic
            final state = ref.read(activeDietPlanProvider);
            if (!DateUtils.isSameDay(state.selectedDate, DateTime.now())) return;

            final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');
            final int baseline = dailyLog?.sensorStepsBaseline ?? 0;

            if (baseline == 0) {
              _saveActivities(stepsToSave: 0, setBaseline: _sensorSteps);
            } else {
              final int calculatedDailySteps = _sensorSteps - baseline;
              final int savedSteps = dailyLog?.stepCount ?? 0;

              if (calculatedDailySteps > savedSteps && !_isSaving) {
                _saveActivities(stepsToSave: calculatedDailySteps);
              }
            }
          }
        }
      }).onError((error) {
        if (mounted) setState(() { _sensorStatus = "Sensor Error"; _sensorActive = false; });
      });
    } else {
      if (mounted) setState(() { _sensorStatus = "Permission Denied. Enable in Settings."; _sensorActive = false; });
    }
  }

  // --- 🎯 Personal Goal Handlers ---
  void _addPersonalGoal() {
    final newGoal = _personalGoalController.text.trim();
    if (newGoal.isNotEmpty && !_personalGoals.contains(newGoal)) {
      setState(() {
        _personalGoals.add(newGoal);
      });
      _saveActivities(newPersonalGoal: newGoal);
    }
  }

  void _removePersonalGoal(String goal) {
    setState(() {
      _personalGoals.remove(goal);
      _completedPersonalGoals.remove(goal);
    });
    _saveActivities();
  }

  // --- 🎯 NEW: Manual Reset Logic ---
  Future<void> _manualResetBaseline() async {
    final bool isToday = DateUtils.isSameDay(ref.read(activeDietPlanProvider).selectedDate, DateTime.now());
    if (!isToday) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You can only reset the step baseline for today.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Daily Steps?'),
        content: const Text('This will set your current step count for today to 0. This is useful if you restarted your phone.\n\nAre you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 🎯 Call save with the reset flag
      await _saveActivities(stepsToSave: 0, setBaseline: _sensorSteps);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Step count for today has been reset to 0.'),
        backgroundColor: Colors.green,
      ));
    }
  }


  // --- 🎯 Save Activity Logic (Consolidated) ---
  Future<void> _saveActivities({int? stepsToSave, String? newPersonalGoal, int? setBaseline}) async {
    final notifier = ref.read(dietPlanNotifierProvider(widget.client.id).notifier);
    final activePlan = ref.read(activeDietPlanProvider).activePlan;
    if (activePlan == null) return;

    setState(() { _isSaving = true; });

    try {
      final dailyLog = ref.read(activeDietPlanProvider).dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');

      final logToSave = dailyLog ?? ClientLogModel(
        id: '',
        clientId: activePlan.clientId,
        dietPlanId: activePlan.id,
        mealName: 'DAILY_WELLNESS_CHECK',
        actualFoodEaten: ['Daily Wellness Data'],
        date: notifier.state.selectedDate,
      );

      List<String> newPersonalGoalsList = List.from(_personalGoals);
      if (newPersonalGoal != null && newPersonalGoal.isNotEmpty && !newPersonalGoalsList.contains(newPersonalGoal)) {
        newPersonalGoalsList.add(newPersonalGoal);
      }

      int currentSteps = 0;
      int? newBaseline = logToSave.sensorStepsBaseline;

      if (setBaseline != null) {
        // --- Resetting Baseline ---
        currentSteps = 0;
        newBaseline = setBaseline;
      } else if (stepsToSave != null) {
        // --- Syncing from Sensor ---
        currentSteps = stepsToSave;
        if (newBaseline == 0 || newBaseline == null) newBaseline = _sensorSteps - stepsToSave;
      } else if (_isManualEntry) {
        // --- Saving from Manual Field ---
        currentSteps = int.tryParse(_manualStepsController.text) ?? 0;
        newBaseline = null;
      } else {
        currentSteps = logToSave.stepCount ?? 0;
      }

      final int completedTasks = _completedMandatoryTasks.length + _completedPersonalGoals.length;

      int score = 0;
      if (_stepGoal > 0) {
        score += ((currentSteps / _stepGoal) * 50).round().clamp(0, 50);
      }
      score += (completedTasks * 10).clamp(0, 50);
      final int caloriesBurned = (currentSteps * 0.04).round();

      final updatedLog = logToSave.copyWith(
        stepCount: currentSteps,
        stepGoal: _stepGoal,
        sensorStepsBaseline: newBaseline,
        caloriesBurned: caloriesBurned,
        completedMandatoryTasks: _completedMandatoryTasks.toList(),
        createdPersonalGoals: newPersonalGoalsList,
        completedPersonalGoals: _completedPersonalGoals.toList(),
        activityScore: score.clamp(0, 100),
      );

      await notifier.createOrUpdateLog(log: updatedLog, mealPhotoFiles: const []);

      if (mounted) {
        if(newPersonalGoal != null) _personalGoalController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Activity saved!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save activity: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 CRITICAL FIX 2: Listen for updates (like date changes) here
    ref.listen(activeDietPlanProvider, (previous, next) {
      if (previous?.selectedDate != next.selectedDate) {
        _updateStateFromLog(next);
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(activeDietPlanProvider);
    final bool isSensorGloballyEnabled = ref.watch(stepSensorEnabledProvider);
    final bool showManualMode = !isSensorGloballyEnabled || _isManualEntry;

    final dailyLog = state.dailyLogs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');
    final int baseline = dailyLog?.sensorStepsBaseline ?? 0;

    final int displayDailySteps = (isSensorGloballyEnabled && _sensorActive && baseline > 0 && _sensorSteps >= baseline)
        ? _sensorSteps - baseline
        : (dailyLog?.stepCount ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Tracker (${DateFormat.yMMMd().format(state.selectedDate)})'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 0. Date Selector
          _buildDateSelector(context, ref.read(dietPlanNotifierProvider(widget.client.id).notifier), state.selectedDate),
          const SizedBox(height: 20),

          // --- 1. Sensor / Manual Toggle ---
          if (isSensorGloballyEnabled)
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _isManualEntry = !showManualMode);
                },
                icon: Icon(showManualMode ? Icons.sensors : Icons.edit),
                label: Text(showManualMode ? 'Switch to Sensor Sync' : 'Switch to Manual Entry'),
                style: OutlinedButton.styleFrom(foregroundColor: colorScheme.secondary),
              ),
            ),
          const SizedBox(height: 20),

          // --- 2. Conditional Input Cards ---
          if (showManualMode)
            _buildManualStepCard(colorScheme)
          else
            _buildSensorSyncCard(colorScheme, displayDailySteps),

          const SizedBox(height: 20),

          // 3. Mandatory Activity Checklist
          _buildMandatoryTasksCard(colorScheme),
          const SizedBox(height: 20),

          // 4. Client's Personal Goals
          _buildPersonalGoalsCard(colorScheme),
        ],
      ),
    );
  }

  // --- 🎯 Refactored Card Widgets ---

  Widget _buildSensorSyncCard(ColorScheme colorScheme, int displayDailySteps) {
    return Card(
      elevation: 2,
      color: _sensorActive ? Colors.green.shade50 : Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Phone Step Sensor', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green.shade800)),
            const SizedBox(height: 10),
            Text(_sensorStatus, style: TextStyle(color: _sensorActive ? Colors.green : Colors.black54)),
            const SizedBox(height: 10),
            Text('TODAY\'S STEPS: $displayDailySteps', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('(Total Sensor: $_sensorSteps)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),

            // 🎯 NEW: Manual Reset Button
            OutlinedButton.icon(
              onPressed: _sensorActive && !_isSaving && DateUtils.isSameDay(ref.read(activeDietPlanProvider).selectedDate, DateTime.now())
                  ? _manualResetBaseline
                  : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset Daily Baseline'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualStepCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Manual Step Estimate',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.primary)
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _manualStepsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Enter estimated steps',
                prefixIcon: Icon(Icons.edit),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isSaving ? null : () => _saveActivities(),
              child: const Text('Save Manual Steps'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMandatoryTasksCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Dietitian\'s Tasks (Mandatory)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.secondary)
            ),
            const SizedBox(height: 10),
            if (_mandatoryTasks.isEmpty)
              const Text('No mandatory tasks assigned by your dietitian today.', style: TextStyle(fontStyle: FontStyle.italic)),
            ..._mandatoryTasks.map((task) {
              final bool isCompleted = _completedMandatoryTasks.contains(task);
              return CheckboxListTile(
                title: Text(task, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null)),
                value: isCompleted,
                activeColor: colorScheme.primary,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) _completedMandatoryTasks.add(task);
                    else _completedMandatoryTasks.remove(task);
                  });
                  _saveActivities(); // Auto-save on check
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalGoalsCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Your Personal Goals',
                style: Theme.of(context).textTheme.titleLarge
            ),
            const SizedBox(height: 10),
            ..._personalGoals.map((goal) {
              final bool isCompleted = _completedPersonalGoals.contains(goal);
              return CheckboxListTile(
                title: Text(goal, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null, fontStyle: FontStyle.italic)),
                value: isCompleted,
                activeColor: colorScheme.primary,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) _completedPersonalGoals.add(goal);
                    else _completedPersonalGoals.remove(goal);
                  });
                  _saveActivities();
                },
                controlAffinity: ListTileControlAffinity.leading,
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removePersonalGoal(goal),
                ),
              );
            }).toList(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _personalGoalController,
                    decoration: const InputDecoration(hintText: 'Add a new goal...'),
                    onSubmitted: (value) => _addPersonalGoal(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: _addPersonalGoal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, DietPlanNotifier notifier, DateTime selectedDate) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    String formatDate(DateTime date) {
      if (DateUtils.isSameDay(date, DateTime.now())) return 'Today';
      if (DateUtils.isSameDay(date, DateTime.now().subtract(const Duration(days: 1)))) return 'Yesterday';
      return DateFormat('EEE, MMM d').format(date);
    }

    return Card(
      elevation: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () {
              final previousDay = selectedDate.subtract(const Duration(days: 1));
              notifier.selectDate(previousDay);
            },
          ),

          GestureDetector(
            onTap: () async {
              final newDate = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (newDate != null && !DateUtils.isSameDay(newDate, selectedDate)) {
                notifier.selectDate(newDate);
              }
            },
            child: Text(
              formatDate(selectedDate),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isToday ? Theme.of(context).colorScheme.primary : Colors.black87
              ),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            onPressed: isToday ? null : () {
              final nextDay = selectedDate.add(const Duration(days: 1));
              notifier.selectDate(nextDay);
            },
            color: isToday ? Colors.grey : Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}