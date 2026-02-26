// lib/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

// 🎯 Domain & Data Layers
import 'package:nutricare_connect/core/clinical_master_service.dart';
import 'package:nutricare_connect/core/package_payment_service.dart';
import 'package:nutricare_connect/features/appointments/meeting_Service.dart';
import 'package:nutricare_connect/core/utils/geeta_repository.dart';
import 'package:nutricare_connect/core/utils/geeta_shloka_model.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/admin_profile_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/guideline_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/package_service.dart';
import 'package:nutricare_connect/features/dietplan/dATA/services/vitals_service.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/admin_profile_model.dart';
import 'package:nutricare_connect/new/models/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/guidelines.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/appointments/schedule_meeting_utils.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/service/client_service.dart';
import 'package:nutricare_connect/features/appointments/appointment_model.dart';
import '../repositories/diet_repositories.dart';

// =========================================================================
// --- 1. State Definition (Atomic Structure) ---
// =========================================================================

class DietPlanState extends Equatable {
  final ClientDietPlanModel? activePlan;
  final VitalsModel? clinicalVitals;
  final ClientLogModel? dailyRecord;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;
  final int version;

  const DietPlanState({
    this.activePlan,
    this.clinicalVitals,
    this.dailyRecord,
    this.isLoading = true,
    this.error,
    required this.selectedDate,
    this.version = 0,
  });

  DietPlanState copyWith({
    ClientDietPlanModel? activePlan,
    VitalsModel? clinicalVitals,
    ClientLogModel? dailyRecord,
    bool? isLoading,
    Object? error = const Object(),
    DateTime? selectedDate,
    int? version,
  }) {
    return DietPlanState(
      activePlan: activePlan ?? this.activePlan,
      clinicalVitals: clinicalVitals ?? this.clinicalVitals,
      dailyRecord: dailyRecord ?? this.dailyRecord,
      isLoading: isLoading ?? this.isLoading,
      error: error is String ? error : (error == null ? null : this.error),
      selectedDate: selectedDate ?? this.selectedDate,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    activePlan,
    clinicalVitals,
    dailyRecord,
    isLoading,
    error,
    selectedDate.day,
    selectedDate.month,
    selectedDate.year,
    version,
  ];
}

// =========================================================================
// --- 2. Notifier (ViewModel/Controller) ---
// =========================================================================

class DietPlanNotifier extends StateNotifier<DietPlanState> {
  final DietRepository _repository;
  final ClientService _clientService;
  final Ref _ref;
  final String _clientId;

  DietPlanNotifier(this._repository, this._clientService, this._ref, this._clientId)
      : super(DietPlanState(selectedDate: DateTime.now())) {
    loadInitialData(state.selectedDate);
  }

  Future<void> loadInitialData(DateTime date) async {
    state = state.copyWith(isLoading: true, error: null);

    final clientProfile = _ref.read(authNotifierProvider).clientProfile;
    final tenantId = clientProfile?.tenantId;

    if (clientProfile == null || tenantId == null || tenantId.isEmpty) {
      state = state.copyWith(isLoading: false, error: "Access Denied: Missing Clinic Context");
      return;
    }

    try {
      ClientDietPlanModel? plan;
      VitalsModel? vitals;

      final session = await _repository.getLatestSession(_clientId, tenantId);

      if (session != null) {
        if (session.linkedDietPlanId != null) {
          plan = await _repository.getPlanById(session.linkedDietPlanId!, tenantId); // 🎯 FIXED
        }
        if (session.linkedVitalsId != null) {
          vitals = await _repository.getVitalsById(session.linkedVitalsId!, tenantId); // 🎯 FIXED
        }
      }

      if (plan == null) plan = await _repository.getActivePlan(_clientId, tenantId);
      if (vitals == null) vitals = await _repository.getLatestVitals(_clientId, tenantId); // 🎯 FIXED

      // 🎯 Fetch Single Master Record with tenantId
      final dailyRecord = await _repository.getDailyRecord(_clientId, date, tenantId); // 🎯 FIXED

      state = state.copyWith(
        activePlan: plan,
        clinicalVitals: vitals,
        dailyRecord: dailyRecord,
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

  // 🎯 ATOMIC UPDATE LOGIC
  Future<void> updateDailyRecord({
    required Map<String, dynamic> data,
    List<XFile>? newPhotos,
    String? mealNameForPhotos,
  }) async {
    try {
      final dateId = DateFormat('yyyy-MM-dd').format(state.selectedDate);

      // 🔒 Tenant Security Injection
      final clientProfile = _ref.read(authNotifierProvider).clientProfile;
      final tenantId = clientProfile?.tenantId ?? 'guest';

      data['tenantId'] = tenantId;
      data['clientId'] = _clientId;

      // 1. Upload WebP Photos
      if (newPhotos != null && newPhotos.isNotEmpty && mealNameForPhotos != null) {
        List<String> uploadedUrls = [];
        for (var photo in newPhotos) {
          final url = await _clientService.uploadMealPhoto(photo, 'meal_photos/$_clientId/$dateId');
          if (url != null) uploadedUrls.add(url);
        }

        final mealKey = 'mealLogs.$mealNameForPhotos';
        if (data.containsKey(mealKey)) {
          List<String> existingUrls = List<String>.from(data[mealKey]['photos'] ?? []);
          data[mealKey]['photos'] = [...existingUrls, ...uploadedUrls];
        }
      }

      // 2. Execute Atomic Merge with strict tenantId
      await _repository.saveAtomicDailyRecord(
        clientId: _clientId,
        tenantId: tenantId, // 🎯 FIXED
        dateId: dateId,
        data: data,
      );

      // 3. Refresh Local State with strict tenantId
      final updatedRecord = await _repository.getDailyRecord(_clientId, state.selectedDate, tenantId); // 🎯 FIXED
      state = state.copyWith(dailyRecord: updatedRecord);

    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// =========================================================================
// --- 3. RIVERPOD PROVIDERS ---
// =========================================================================

// --- Base Providers ---

final currentTenantIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final tenantId = authState.clientProfile?.tenantId;
  return (tenantId == null || tenantId.isEmpty) ? 'guest' : tenantId;
});

final dietRepositoryProvider = Provider((ref) => DietRepository());
final clientServiceProvider = Provider((ref) => ClientService(ref));

final vitalsServiceProvider = Provider<VitalsService>((ref) {
  final currentClient = ref.watch(currentClientProvider);
  final tenantId = currentClient?.tenantId ?? '';
  return VitalsService(tenantId: tenantId);
});

final geetaRepositoryProvider = Provider((ref) => GeetaRepository());
final clinicalMasterServiceProvider = Provider<ClinicalMasterService>((ref) => ClinicalMasterService());

final packagePaymentServiceProvider = Provider<PackagePaymentService>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  return PackagePaymentService(tenantId: tenantId);
});

// --- Main State Providers ---

final dietPlanNotifierProvider = StateNotifierProvider.family<DietPlanNotifier, DietPlanState, String>((ref, clientId) {
  final repository = ref.watch(dietRepositoryProvider);
  final clientService = ref.watch(clientServiceProvider);
  return DietPlanNotifier(repository, clientService, ref, clientId);
});

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
  final tenantId = ref.watch(currentTenantIdProvider); // 🎯 FIXED
  return repository.fetchAllClientLogs(clientId, tenantId); // 🎯 FIXED
});

final geetaLibraryProvider = FutureProvider<List<GeetaShloka>>((ref) async {
  final repo = ref.watch(geetaRepositoryProvider);
  return repo.getAllShlokas();
});

final latestVitalsFutureProvider = FutureProvider.family<VitalsModel?, String>((ref, clientId) async {
  final service = ref.watch(vitalsServiceProvider);
  final vitalsList = await service.getClientVitals(clientId);
  return vitalsList.isNotEmpty ? vitalsList.first : null;
});

final upcomingMeetingsProvider = FutureProvider.family<List<MeetingModel>, String>((ref, clientId) async {
  final service = MeetingService();
  return service.getClientMeetings(clientId);
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

final weeklyLogHistoryProvider = FutureProvider.family<Map<DateTime, ClientLogModel>, String>((ref, clientId) async {
  final repository = ref.watch(dietRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider); // 🎯 FIXED

  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 7));

  final allLogs = await repository.fetchAllClientLogs(clientId, tenantId); // 🎯 FIXED

  final recentLogs = allLogs.where((log) =>
      log.date.isAfter(startDate.subtract(const Duration(hours: 1)))
  ).toList();

  final Map<DateTime, ClientLogModel> groupedLogs = {};

  for (final log in recentLogs) {
    final day = DateTime(log.date.year, log.date.month, log.date.day);
    groupedLogs[day] = log;
  }
  return groupedLogs;
});

final stepSensorEnabledProvider = StateProvider<bool>((ref) => true);

final weeklyActivityScoreProvider = Provider.family<int, String>((ref, clientId) {
  final historyAsync = ref.watch(weeklyLogHistoryProvider(clientId));

  return historyAsync.when(
    data: (groupedLogs) {
      int score = 0;
      groupedLogs.forEach((date, dailyRecord) {
        score += dailyRecord.stepCount ?? 0;
      });
      return score;
    },
    loading: () => 0,
    error: (e, s) => 0,
  );
});

final dailyActivityStreakProvider = Provider.family<int, String>((ref, clientId) {
  final historyAsync = ref.watch(weeklyLogHistoryProvider(clientId));

  return historyAsync.when(
    data: (groupedLogs) {
      int streak = 0;
      final sortedDates = groupedLogs.keys.toList()..sort((a, b) => b.compareTo(a));
      DateTime dayToCheck = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      final todayRecord = groupedLogs[dayToCheck];
      if (todayRecord != null && (todayRecord.stepCount ?? 0) > 0) {
        streak++;
        dayToCheck = dayToCheck.subtract(const Duration(days: 1));
      } else {
        dayToCheck = dayToCheck.subtract(const Duration(days: 1));
      }

      for (final date in sortedDates) {
        if (!date.isAtSameMomentAs(dayToCheck)) continue;
        final dailyRecord = groupedLogs[date];
        if (dailyRecord != null && (dailyRecord.stepCount ?? 0) > 0) {
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

final historicalLogProvider = FutureProvider.family<Map<DateTime, ClientLogModel>, ({String clientId, int days})>((ref, params) async {
  final repository = ref.watch(dietRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider); // 🎯 FIXED

  final allLogs = await repository.fetchAllClientLogs(params.clientId, tenantId); // 🎯 FIXED

  final endDate = DateTime.now();
  final startDate = endDate.subtract(Duration(days: params.days));

  final recentLogs = allLogs.where((log) =>
  !log.date.isBefore(startDate) && log.date.isBefore(endDate.add(const Duration(days: 1)))
  ).toList();

  final Map<DateTime, ClientLogModel> groupedLogs = {};
  for (final log in recentLogs) {
    final day = DateTime(log.date.year, log.date.month, log.date.day);
    groupedLogs[day] = log;
  }

  return groupedLogs;
});

final vitalsHistoryProvider = FutureProvider.family<List<VitalsModel>, String>((ref, clientId) async {
  final service = ref.watch(vitalsServiceProvider);
  return service.getClientVitals(clientId);
});