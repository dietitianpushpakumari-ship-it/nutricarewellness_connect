// lib/features/diet_plan/presentation/providers/diet_plan_provider.dart
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/legacy.dart';

// 🎯 FIX: Corrected Repository Import Path (assumes dATA casing for local structure)
import 'package:nutricare_connect/features/dietplan/dATA/repositories/diet_repositories.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
// 🎯 Required to access ClientService methods

// --- 1. State Definition (FIXED PROPS) ---
class DietPlanState extends Equatable {
  final ClientDietPlanModel? activePlan;
  final List<ClientLogModel> dailyLogs;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;

  DietPlanState({
    this.activePlan, this.dailyLogs = const [], this.isLoading = true, this.error, required this.selectedDate,
  });

  DietPlanState copyWith({
    ClientDietPlanModel? activePlan, List<ClientLogModel>? dailyLogs, bool? isLoading, Object? error = const Object(), DateTime? selectedDate,
  }) {
    return DietPlanState(
      activePlan: activePlan ?? this.activePlan,
      dailyLogs: dailyLogs ?? this.dailyLogs,
      isLoading: isLoading ?? this.isLoading,
      error: error is String ? error : (error == null ? null : this.error),
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  @override
  List<Object?> get props => [
    activePlan,
    dailyLogs,
    isLoading,
    error,
    selectedDate.day,
    selectedDate.month,
    selectedDate.year,
  ];
}

// --- 2. Notifier (ViewModel/Controller) ---
class DietPlanNotifier extends StateNotifier<DietPlanState> {
  final DietRepository _repository;
  final String _currentClientId;
  final ClientService _clientService; // 🎯 CRITICAL FIX: Add and store the service instance

  // 🎯 MODIFIED CONSTRUCTOR: Accepts ClientService
  DietPlanNotifier(this._repository, this._currentClientId, this._clientService)
      : super(DietPlanState(selectedDate: DateTime.now())) {
    loadInitialData(state.selectedDate);
  }

  Future<void> loadInitialData(DateTime date) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final plan = state.activePlan ??
          await _repository.getActivePlan(_currentClientId);
      final logs = await _repository.getLogsForDate(_currentClientId, date);

      state = state.copyWith(
        activePlan: plan,
        dailyLogs: logs,
        isLoading: false,
        selectedDate: date,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logMeal(String mealName, String food) async {
    if (state.activePlan == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final newLog = ClientLogModel(
        clientId: _currentClientId,
        dietPlanId: state.activePlan!.id,
        date: state.selectedDate,
        mealName: mealName,
        actualFoodEaten: food,
      );
      final createdLog = await _repository.createLog(newLog);

      state = state.copyWith(
        dailyLogs: [...state.dailyLogs, createdLog],
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Failed to log meal: ${e.toString()}');
    }
  }

  void selectDate(DateTime newDate) {
    if (newDate.day != state.selectedDate.day) {
      loadInitialData(newDate);
    }
  }

  // 🎯 Log Creation/Update Logic (Uses injected _clientService)
  Future<void> createOrUpdateLog({
    required ClientLogModel log,
    required List<XFile> mealPhotoFiles, // New parameter for photos
  }) async {
    final isUpdate = log.id.isNotEmpty;

    state = state.copyWith(isLoading: true);

    try {
      List<String> photoUrls = log.mealPhotoUrls;

      // 1. Upload new photos (USING INJECTED SERVICE)
      if (mealPhotoFiles.isNotEmpty) {
        // Use the injected service instance to call the upload method
        // NOTE: Assuming uploadFiles is implemented on ClientService
        photoUrls = await _clientService.uploadFiles(
            mealPhotoFiles,
            'client_logs/${log.clientId}/${log.id.isNotEmpty ? log.id : 'new'}'
        );
      }

      final logWithUrls = log.copyWith(mealPhotoUrls: photoUrls);

      if (isUpdate) {
        // 2. 🎯 UPDATE LOG
        await _repository.updateLog(logWithUrls);
      } else {
        // 3. 🎯 CREATE LOG
        await _repository.createLog(logWithUrls);
      }

      // 4. Refresh the active day's logs (to reflect changes on the dashboard)
      await loadInitialData(state.selectedDate);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to save log: $e');
    }
  }
}
// --- 3. Riverpod Providers for Dependency Injection ---

final clientServiceProvider = Provider((ref) => ClientService()); // Assuming this is defined or available

// 🎯 FIX: Repository now returns the instance directly (no dependencies needed)
final dietRepositoryProvider = Provider((ref) => DietRepository());

// 🎯 CRITICAL FIX: Pass the ClientService instance to the Notifier
final dietPlanNotifierProvider = StateNotifierProvider.family<DietPlanNotifier, DietPlanState, String>((ref, clientId) {
  // Uses the stored ref to inject both Repository and ClientService
  return DietPlanNotifier(
      ref.watch(dietRepositoryProvider),
      clientId,
      ref.watch(clientServiceProvider) // Inject ClientService dependency
  );
});

final clientLogHistoryProvider = FutureProvider.family<List<ClientLogModel>, String>((ref, clientId) async {
  final repository = ref.watch(dietRepositoryProvider);
  return repository.fetchAllClientLogs(clientId);
});

final activeDietPlanProvider = Provider<DietPlanState>((ref) {
  final clientId = ref.watch(currentClientIdProvider);

  if (clientId == null) {
    return DietPlanState(isLoading: false, selectedDate: DateTime.now(), activePlan: null);
  }

  return ref.watch(dietPlanNotifierProvider(clientId));
});