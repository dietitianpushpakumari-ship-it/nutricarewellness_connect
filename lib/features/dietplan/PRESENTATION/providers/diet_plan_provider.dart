// lib/features/diet_plan/presentation/providers/diet_plan_provider.dart
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nutricare_connect/core/utils/geeta_repository.dart';
import 'package:nutricare_connect/core/utils/geeta_shloka_model.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart';

// 🎯 FIX: Corrected Repository Import Path (assumes dATA casing for local structure)
import 'package:nutricare_connect/features/dietplan/dATA/repositories/diet_repositories.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/admin_profile_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/guideline_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/meeting_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/package_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/diet_plan_item_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/guidelines.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/schedule_meeting_utils.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/vitals_model.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:nutricare_connect/services/local_reminder_service.dart';
// 🎯 Required to access ClientService methods

// --- 1. State Definition (FIXED PROPS) ---
class DietPlanState extends Equatable {
  final ClientDietPlanModel? activePlan;
  final List<ClientLogModel> dailyLogs;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;
  final int version;


  DietPlanState({
    this.activePlan, this.dailyLogs = const [], this.isLoading = true, this.error, required this.selectedDate, this.version = 0,
  });

  DietPlanState copyWith({
    ClientDietPlanModel? activePlan, List<ClientLogModel>? dailyLogs, bool? isLoading, Object? error = const Object(), DateTime? selectedDate,int? version,
  }) {
    return DietPlanState(
      activePlan: activePlan ?? this.activePlan,
      dailyLogs: dailyLogs ?? this.dailyLogs,
      isLoading: isLoading ?? this.isLoading,
      error: error is String ? error : (error == null ? null : this.error),
      selectedDate: selectedDate ?? this.selectedDate,
      version: version ?? this.version,
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
    version,
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
        version: state.version + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
final vitalsServiceProvider = Provider((ref) => VitalsService());

// 🎯 CRITICAL FIX: Pass the ClientService instance to the Notifier
final dietPlanNotifierProvider = StateNotifierProvider.family<DietPlanNotifier, DietPlanState, String>((ref, clientId) {
  // Uses the stored ref to inject both Repository and ClientService
  return DietPlanNotifier(
    //
      ref.watch(dietRepositoryProvider),
      clientId,
      ref.watch(clientServiceProvider) // Inject ClientService dependency,
  );
});

final clientLogHistoryProvider = FutureProvider.family<List<ClientLogModel>, String>((ref, clientId) async {
  final repository = ref.watch(dietRepositoryProvider);
  return repository.fetchAllClientLogs(clientId);
});

final geetaRepositoryProvider = Provider((ref) => GeetaRepository());

// 🎯 This FutureProvider will trigger the "Check Cache -> Fetch" logic once
final geetaLibraryProvider = FutureProvider<List<GeetaShloka>>((ref) async {
  final repo = ref.watch(geetaRepositoryProvider);
  return repo.getAllShlokas();
});
final activeDietPlanProvider = Provider<DietPlanState>((ref) {
  final clientId = ref.watch(currentClientIdProvider);

  if (clientId == null) {
    return DietPlanState(isLoading: false, selectedDate: DateTime.now(), activePlan: null);
  }

  return ref.watch(dietPlanNotifierProvider(clientId));
});


final latestVitalsFutureProvider = FutureProvider.family<VitalsModel?, String>((ref, clientId) async {
  final service = VitalsService();
  final vitalsList = await service.getClientVitals(clientId); // Assuming getClientVitals returns a sorted list
  return vitalsList.firstWhereOrNull((v) => true); // Get the latest (first) record
});
final upcomingMeetingsProvider = FutureProvider.family<List<MeetingModel>, String>((ref, clientId) async {
  final service = MeetingService();
  // Fetch meetings based on the clientId
  return service.getClientMeetings(clientId);
});

final enrolledPackageProvider = FutureProvider.family<List<MeetingModel>, String>((ref, clientId) async {
  final service = MeetingService();
  // Fetch meetings based on the clientId
  return service.getClientMeetings(clientId);
});

final dietitianProfileProvider = FutureProvider<AdminProfileModel?>((ref) async {
  final service = AdminProfileService();
  // Call the service to fetch the single Admin Profile
  final adminProfile = await service.fetchAdminProfile();

  // Return the fetched profile (which is AdminProfileModel?)
  return adminProfile;
});

final guidelineProvider = FutureProvider.family<List<Guideline>, List<String>>((ref, guidelineIds) async {
  final service = GuidelineService();
  return await service.fetchGuidelinesByIds(guidelineIds);
});

final assignedPackageProvider = FutureProvider.family<List<PackageAssignmentModel>,String>((ref, clientId) async {
  final service = PackageService();
  return await service.getPackageAssignments(clientId);

});

final weeklyLogHistoryProvider = FutureProvider.family<Map<DateTime, List<ClientLogModel>>, String>((ref, clientId) async {
  final repository = ref.watch(dietRepositoryProvider);
  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 7));

  // NOTE: Assuming repository has a fetchLogsBetweenDates method or we use the existing fetchAll and filter locally
  final allLogs = await repository.fetchAllClientLogs(clientId);

  // 1. Filter logs to the last 7 days
  final recentLogs = allLogs.where((log) =>
      log.date.isAfter(startDate.subtract(const Duration(hours: 1))) // Account for time zone differences
  ).toList();

  // 2. Group the logs by date (removing time component)
  final Map<DateTime, List<ClientLogModel>> groupedLogs = {};

  for (final log in recentLogs) {
    final day = DateTime(log.date.year, log.date.month, log.date.day);
    groupedLogs.putIfAbsent(day, () => []).add(log);
  }

  // Return grouped data
  return groupedLogs;
});

// 🎯 Provider to control the step sensor toggle
final stepSensorEnabledProvider = StateProvider<bool>((ref) => true);


// --- Add these to diet_plan_provider.dart ---

// 🎯 NEW: Provider for Weekly Activity Score
final weeklyActivityScoreProvider = Provider.family<int, String>((ref, clientId) {
  final historyAsync = ref.watch(weeklyLogHistoryProvider(clientId));

  return historyAsync.when(
    data: (groupedLogs) {
      int score = 0;
      groupedLogs.forEach((date, logs) {
        final wellnessLog = logs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');
        score += wellnessLog?.activityScore ?? 0; // Sum up the daily scores
      });
      return score;
    },
    loading: () => 0,
    error: (e, s) => 0,
  );
});

// 🎯 NEW: Provider for Daily Movement Streak
final dailyActivityStreakProvider = Provider.family<int, String>((ref, clientId) {
  final historyAsync = ref.watch(weeklyLogHistoryProvider(clientId));

  return historyAsync.when(
    data: (groupedLogs) {
      int streak = 0;
      final sortedDates = groupedLogs.keys.toList()..sort((a, b) => b.compareTo(a)); // Newest first
      DateTime dayToCheck = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      final todayLog = groupedLogs[dayToCheck]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
      if (todayLog?.activityScore != null && todayLog!.activityScore! > 0) {
        streak++;
      } else {
        dayToCheck = dayToCheck.subtract(const Duration(days: 1));
      }

      for (final date in sortedDates) {
        if (!date.isAtSameMomentAs(dayToCheck)) continue;
        final wellnessLog = groupedLogs[date]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
        if (wellnessLog?.activityScore != null && wellnessLog!.activityScore! > 0) {
          streak++;
          dayToCheck = dayToCheck.subtract(const Duration(days: 1));
        } else {
          break; // Streak is broken
        }
      }
      return streak;
    },
    loading: () => 0,
    error: (e, s) => 0,
  );
});


final historicalLogProvider = FutureProvider.family<Map<DateTime, List<ClientLogModel>>, ({String clientId, int days})>((ref, params) async {

  // In a real app, you would optimize this query.
  // For now, we fetch all and filter.
  final repository = ref.watch(dietRepositoryProvider);
  final allLogs = await repository.fetchAllClientLogs(params.clientId);

  final endDate = DateTime.now();
  final startDate = endDate.subtract(Duration(days: params.days));

  // 1. Filter logs to the selected range
  final recentLogs = allLogs.where((log) =>
  !log.date.isBefore(startDate) && log.date.isBefore(endDate.add(const Duration(days: 1)))
  ).toList();

  // 2. Group the logs by date
  final Map<DateTime, List<ClientLogModel>> groupedLogs = {};
  for (final log in recentLogs) {
    final day = DateTime(log.date.year, log.date.month, log.date.day);
    groupedLogs.putIfAbsent(day, () => []).add(log);
  }

  return groupedLogs;
});


// 🎯 NEW: PROVIDER FOR VITALS HISTORY (for the graph)
final vitalsHistoryProvider = FutureProvider.family<List<VitalsModel>, String>((ref, clientId) async {
  final service = ref.watch(vitalsServiceProvider);
  return service.getClientVitals(clientId);
});