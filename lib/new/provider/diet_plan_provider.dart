// lib/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart';

// 🎯 Domain & Data Layers
import 'package:nutricare_connect/core/clinical_master_service.dart';
import 'package:nutricare_connect/features/appointments/meeting_Service.dart';
import 'package:nutricare_connect/core/utils/geeta_repository.dart';
import 'package:nutricare_connect/core/utils/geeta_shloka_model.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/admin_profile_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/guideline_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/package_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart'; // Ensure this exists
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/guidelines.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/appointments/schedule_meeting_utils.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart'; // Ensure this exists
import 'package:nutricare_connect/features/auth/client_service.dart';
import 'package:nutricare_connect/features/appointments/appointment_model.dart'; // For MeetingModel
import '../repositories/diet_repositories.dart';

// =========================================================================
// --- 1. State Definition (Updated for Vitals & Tenant) ---
// =========================================================================

class DietPlanState extends Equatable {
  final ClientDietPlanModel? activePlan;
  final VitalsModel? clinicalVitals; // 🎯 Added: Holds Medications/Guidelines
  final List<ClientLogModel> dailyLogs;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;
  final int version;

  const DietPlanState({
    this.activePlan,
    this.clinicalVitals,
    this.dailyLogs = const [],
    this.isLoading = true,
    this.error,
    required this.selectedDate,
    this.version = 0,
  });

  DietPlanState copyWith({
    ClientDietPlanModel? activePlan,
    VitalsModel? clinicalVitals,
    List<ClientLogModel>? dailyLogs,
    bool? isLoading,
    Object? error = const Object(),
    DateTime? selectedDate,
    int? version,
  }) {
    return DietPlanState(
      activePlan: activePlan ?? this.activePlan,
      clinicalVitals: clinicalVitals ?? this.clinicalVitals,
      dailyLogs: dailyLogs ?? this.dailyLogs,
      isLoading: isLoading ?? this.isLoading,
      error: error is String ? error : (error == null ? null : this.error),
      selectedDate: selectedDate ?? this.selectedDate,
      version: version ?? this.version,
    );
  }

  // Helper to easily get the wellness log for the day
  ClientLogModel? get wellnessLog => dailyLogs.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');

  @override
  List<Object?> get props => [
    activePlan,
    clinicalVitals,
    dailyLogs,
    isLoading,
    error,
    selectedDate.day,
    selectedDate.month,
    selectedDate.year,
    version,
  ];
}

// =========================================================================
// --- 2. Notifier (ViewModel/Controller) with Tenant Logic ---
// =========================================================================

class DietPlanNotifier extends StateNotifier<DietPlanState> {
  final DietRepository _repository;
  final Ref _ref;
  final String _clientId;

  DietPlanNotifier(this._repository, this._ref, this._clientId)
      : super(DietPlanState(selectedDate: DateTime.now())) {
    loadInitialData(state.selectedDate);
  }
  Future<void> loadInitialData(DateTime date) async {
    state = state.copyWith(isLoading: true, error: null);

    // 🔒 1. GET TENANT CONTEXT
    final clientProfile = _ref.read(authNotifierProvider).clientProfile;
    final tenantId = clientProfile?.tenantId;

    if (clientProfile == null || tenantId == null || tenantId.isEmpty) {
      state = state.copyWith(isLoading: false, error: "Access Denied: Missing Clinic Context");
      return;
    }

    try {
      ClientDietPlanModel? plan;
      VitalsModel? vitals;

      // 🎯 2. TRY FETCHING SESSION-BASED DATA
      final session = await _repository.getLatestSession(_clientId, tenantId);

      if (session != null) {
        // 識 CASE A: Session Found - Use Linked Data
        if (session.linkedDietPlanId != null) {
          plan = await _repository.getPlanById(session.linkedDietPlanId!);
        }
        if (session.linkedVitalsId != null) {
          vitals = await _repository.getVitalsById(session.linkedVitalsId!);
        }
      }

      // 識 CASE B: Fallback (If session missing OR linked data missing)
      if (plan == null) {
        plan = await _repository.getActivePlan(_clientId, tenantId);
      }
      if (vitals == null) {
        vitals = await _repository.getLatestVitals(_clientId);
      }

      // 🎯 3. FETCH DAILY LOGS (Client-Specific)
      final logs = await _repository.getLogsForDate(_clientId, date);

      state = state.copyWith(
        activePlan: plan,
        clinicalVitals: vitals,
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
    if (newDate.day != state.selectedDate.day ||
        newDate.month != state.selectedDate.month ||
        newDate.year != state.selectedDate.year) {
      loadInitialData(newDate);
    }
  }

  Future<void> createOrUpdateLog({
    required ClientLogModel log,
    required List<XFile> mealPhotoFiles,
  }) async {
    try {
      // 1. (Optional) Upload Photo Logic would go here
      List<String> photoUrls = List.from(log.mealPhotoUrls);

      // 2. Prepare Final Model
      final logToSave = log.copyWith(mealPhotoUrls: photoUrls);

      // 3. Call Repository
      final savedLog = await _repository.createOrUpdateLog(logToSave);

      // 4. Update Local State (Optimistic UI)
      final currentLogs = [...state.dailyLogs];
      final index = currentLogs.indexWhere((l) => l.id == savedLog.id);

      if (index != -1) {
        currentLogs[index] = savedLog;
      } else {
        currentLogs.add(savedLog);
      }

      state = state.copyWith(dailyLogs: currentLogs);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// =========================================================================
// --- 3. RIVERPOD PROVIDERS ---
// =========================================================================

final dietRepositoryProvider = Provider((ref) => DietRepository());
final clientServiceProvider = Provider((ref) => ClientService(ref));
final vitalsServiceProvider = Provider((ref) => VitalsService());
final geetaRepositoryProvider = Provider((ref) => GeetaRepository());
final clinicalMasterServiceProvider = Provider<ClinicalMasterService>((ref) => ClinicalMasterService());

// 🎯 MAIN NOTIFIER PROVIDER
final dietPlanNotifierProvider = StateNotifierProvider.family<DietPlanNotifier, DietPlanState, String>((ref, clientId) {
  final repository = ref.watch(dietRepositoryProvider);
  // Pass 'ref' to access AuthProvider inside the notifier
  return DietPlanNotifier(repository, ref, clientId);
});

// 🎯 GLOBAL ACTIVE STATE PROVIDER (Auto-Selects current user)
final activeDietPlanProvider = Provider<DietPlanState>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final clientId = authState.clientProfile?.id;

  if (clientId == null || clientId.isEmpty) {
    return DietPlanState(isLoading: false, selectedDate: DateTime.now(), activePlan: null);
  }

  return ref.watch(dietPlanNotifierProvider(clientId));
});

// --- DATA FETCHING PROVIDERS ---

final clientLogHistoryProvider = FutureProvider.family<List<ClientLogModel>, String>((ref, clientId) async {
  final repository = ref.watch(dietRepositoryProvider);
  return repository.fetchAllClientLogs(clientId);
});

final geetaLibraryProvider = FutureProvider<List<GeetaShloka>>((ref) async {
  final repo = ref.watch(geetaRepositoryProvider);
  return repo.getAllShlokas();
});

// 🎯 Updated to use VitalsService which likely returns List<VitalsModel>
final latestVitalsFutureProvider = FutureProvider.family<VitalsModel?, String>((ref, clientId) async {
  final service = ref.watch(vitalsServiceProvider);
  final vitalsList = await service.getClientVitals(clientId);
  return vitalsList.isNotEmpty ? vitalsList.first : null;
});

final upcomingMeetingsProvider = FutureProvider.family<List<MeetingModel>, String>((ref, clientId) async {
  final service = MeetingService();
  return service.getClientMeetings(clientId); // Ensure MeetingService returns List<MeetingModel>
});

final enrolledPackageProvider = FutureProvider.family<List<MeetingModel>, String>((ref, clientId) async {
  final service = MeetingService();
  return service.getClientMeetings(clientId);
});

final dietitianProfileProvider = FutureProvider<AdminProfileModel?>((ref) async {
  final service = AdminProfileService();
  return await service.fetchAdminProfile();
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

  final allLogs = await repository.fetchAllClientLogs(clientId);

  final recentLogs = allLogs.where((log) =>
      log.date.isAfter(startDate.subtract(const Duration(hours: 1)))
  ).toList();

  final Map<DateTime, List<ClientLogModel>> groupedLogs = {};

  for (final log in recentLogs) {
    final day = DateTime(log.date.year, log.date.month, log.date.day);
    groupedLogs.putIfAbsent(day, () => []).add(log);
  }
  return groupedLogs;
});

// 🎯 Provider to control the step sensor toggle
final stepSensorEnabledProvider = StateProvider<bool>((ref) => true);

// 🎯 Weekly Activity Score
final weeklyActivityScoreProvider = Provider.family<int, String>((ref, clientId) {
  final historyAsync = ref.watch(weeklyLogHistoryProvider(clientId));

  return historyAsync.when(
    data: (groupedLogs) {
      int score = 0;
      groupedLogs.forEach((date, logs) {
        final wellnessLog = logs.firstWhereOrNull((log) => log.mealName == 'DAILY_WELLNESS_CHECK');
        score += wellnessLog?.activityScore ?? 0;
      });
      return score;
    },
    loading: () => 0,
    error: (e, s) => 0,
  );
});

// 🎯 Daily Movement Streak
final dailyActivityStreakProvider = Provider.family<int, String>((ref, clientId) {
  final historyAsync = ref.watch(weeklyLogHistoryProvider(clientId));

  return historyAsync.when(
    data: (groupedLogs) {
      int streak = 0;
      final sortedDates = groupedLogs.keys.toList()..sort((a, b) => b.compareTo(a));
      DateTime dayToCheck = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      // Check Today
      final todayLog = groupedLogs[dayToCheck]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
      if (todayLog?.activityScore != null && todayLog!.activityScore! > 0) {
        streak++;
        dayToCheck = dayToCheck.subtract(const Duration(days: 1));
      } else {
        // Even if no activity today, check yesterday to keep streak alive
        dayToCheck = dayToCheck.subtract(const Duration(days: 1));
      }

      for (final date in sortedDates) {
        if (!date.isAtSameMomentAs(dayToCheck)) continue;
        final wellnessLog = groupedLogs[date]?.firstWhereOrNull((l) => l.mealName == 'DAILY_WELLNESS_CHECK');
        if (wellnessLog?.activityScore != null && wellnessLog!.activityScore! > 0) {
          streak++;
          dayToCheck = dayToCheck.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
      return streak;
    },
    loading: () => 0,
    error: (e, s) => 0,
  );
});

// 🎯 Historical Logs
final historicalLogProvider = FutureProvider.family<Map<DateTime, List<ClientLogModel>>, ({String clientId, int days})>((ref, params) async {
  final repository = ref.watch(dietRepositoryProvider);
  final allLogs = await repository.fetchAllClientLogs(params.clientId);

  final endDate = DateTime.now();
  final startDate = endDate.subtract(Duration(days: params.days));

  final recentLogs = allLogs.where((log) =>
  !log.date.isBefore(startDate) && log.date.isBefore(endDate.add(const Duration(days: 1)))
  ).toList();

  final Map<DateTime, List<ClientLogModel>> groupedLogs = {};
  for (final log in recentLogs) {
    final day = DateTime(log.date.year, log.date.month, log.date.day);
    groupedLogs.putIfAbsent(day, () => []).add(log);
  }

  return groupedLogs;
});

// 🎯 Vitals History
final vitalsHistoryProvider = FutureProvider.family<List<VitalsModel>, String>((ref, clientId) async {
  final service = ref.watch(vitalsServiceProvider);
  return service.getClientVitals(clientId); // Assumes VitalsService returns List<VitalsModel>
});