// lib/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:rxdart/rxdart.dart';

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

 // Ensure this provides FlatClientDietPlanModel
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_log_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/guidelines.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_assignment_model.dart';
import 'package:nutricare_connect/features/appointments/schedule_meeting_utils.dart';
import 'package:nutricare_connect/new/models/lab_test_config_model.dart';
import 'package:nutricare_connect/new/models/vitals_model.dart';
import 'package:nutricare_connect/new/service/client_service.dart';
import 'package:nutricare_connect/features/appointments/appointment_model.dart';
import '../FlatClientDietPlanModel.dart';
import '../repositories/diet_repositories.dart';

// =========================================================================
// --- 1. State Definition (Atomic Structure) ---
// =========================================================================

class DietPlanState extends Equatable {
  // 🚀 THE FIX: Strongly typed to Flat Model
  final FlatClientDietPlanModel? activePlan;
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
    FlatClientDietPlanModel? activePlan, // 🚀 Flat Model
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

  DietPlanNotifier(this._repository, this._clientService, this._ref,
      this._clientId)
      : super(DietPlanState(selectedDate: DateTime.now())) {
    loadInitialData(state.selectedDate);
  }

  Future<void> _notifyAdmin(String mealName, var client) async {
    try {
      if (client.coachId == null || client.coachId!.isEmpty) return;

      // 1. Fetch the Admin's FCM Token from Firestore
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(client.coachId)
          .get();

      final fcmToken = adminDoc.data()?['fcmToken'];
      var clientName = client.name;
      var clientId = client.patientId;

      if (fcmToken != null) {
        // 2. Trigger the notification
        await _repository.sendPushNotification(
          token: fcmToken,
          title: "New Meal Logged 🥗",
          body: "$clientName (ID: $clientId) just logged $mealName",
          data: {
            "type": "meal_log",
            "clientId": clientId,
            "click_action": "FLUTTER_NOTIFICATION_CLICK"
          },
        );
      }
    } catch (e) {
      print("Failed to notify coach: $e");
    }
  }

  Future<void> loadInitialData(DateTime date) async {
    state = state.copyWith(isLoading: true, error: null);

    final clientProfile = _ref
        .read(authNotifierProvider)
        .clientProfile;
    final tenantId = clientProfile?.tenantId;

    if (clientProfile == null || tenantId == null || tenantId.isEmpty) {
      state = state.copyWith(
          isLoading: false, error: "Access Denied: Missing Clinic Context");
      return;
    }

    try {
      FlatClientDietPlanModel? plan; // 🚀 Flat Model
      VitalsModel? vitals;

      final session = await _repository.getLatestSession(_clientId, tenantId);

      if (session != null) {
        if (session.linkedDietPlanId != null) {
          // ⚠️ NOTE: Make sure your repository methods return FlatClientDietPlanModel
          plan = await _repository.getPlanById(session.linkedDietPlanId!, tenantId);
        }
        if (session.linkedVitalsId != null) {
          vitals = await _repository.getVitalsById(session.linkedVitalsId!, tenantId);
        }
      }

      if (plan == null) {
        plan = await _repository.getActivePlan(_clientId, tenantId);
      }
      if (vitals == null) {
        vitals = await _repository.getLatestVitals(_clientId, tenantId);
      }

      final dailyRecord = await _repository.getDailyRecord(
          _clientId, date, tenantId);

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

// 🎯 ATOMIC UPDATE LOGIC WITH OPTIMISTIC UI
  Future<void> updateDailyRecord({
    required Map<String, dynamic> data,
    List<XFile>? newPhotos,
    String? mealNameForPhotos,
  }) async {
    try {
      final dateId = DateFormat('yyyy-MM-dd').format(state.selectedDate);

      // 🔒 Tenant Security Injection
      final clientProfile = _ref
          .read(authNotifierProvider)
          .clientProfile;
      final tenantId = clientProfile?.tenantId ?? 'guest';

      data['tenantId'] = tenantId;
      data['clientId'] = _clientId;

      // 1. Upload Photos First
      if (newPhotos != null && newPhotos.isNotEmpty &&
          mealNameForPhotos != null) {
        List<String> uploadedUrls = [];
        for (var photo in newPhotos) {
          final url = await _clientService.uploadMealPhoto(
              photo, 'meal_photos/$_clientId/$dateId');
          if (url != null) uploadedUrls.add(url);
        }

        if (data['mealLogs'] != null &&
            data['mealLogs'][mealNameForPhotos] != null) {
          List<String> existingUrls = List<String>.from(
              data['mealLogs'][mealNameForPhotos]['mealPhotoUrls'] ?? []);
          data['mealLogs'][mealNameForPhotos]['mealPhotoUrls'] =
          [...existingUrls, ...uploadedUrls];
        }
      }

      // 🚀 2. OPTIMISTIC UI UPDATE
      if (mealNameForPhotos != null && data['mealLogs'] != null &&
          data['mealLogs'][mealNameForPhotos] != null) {
        final currentRecord = state.dailyRecord ?? ClientLogModel(
          clientId: _clientId,
          tenantId: tenantId,
          dietPlanId: state.activePlan?.id ?? '',
          date: state.selectedDate,
        );

        final updatedMeals = Map<String, MealEntry>.from(
            currentRecord.mealLogs);

        final safeKey = mealNameForPhotos.trim();
        updatedMeals[safeKey] =
            MealEntry.fromMap(data['mealLogs'][mealNameForPhotos]);

        final optimisticRecord = currentRecord.copyWith(mealLogs: updatedMeals);
        state = state.copyWith(
            dailyRecord: optimisticRecord, version: state.version + 1);
      }

      // 3. Execute Atomic Merge to Database
      await _repository.saveAtomicDailyRecord(
        clientId: _clientId,
        tenantId: tenantId,
        dateId: dateId,
        data: data,
      );

      if (mealNameForPhotos != null) {
        // Do not await this so it doesn't slow down the UI update
        _notifyAdmin(mealNameForPhotos, clientProfile);
      }

      // 4. Refresh Local State from DB
      final updatedRecord = await _repository.getDailyRecord(
          _clientId, state.selectedDate, tenantId);

      state = state.copyWith(
          dailyRecord: updatedRecord, version: state.version + 1);
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
  final tenantId = ref.watch(currentTenantIdProvider);
  return repository.fetchAllClientLogs(clientId, tenantId);
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
  final tenantId = ref.watch(currentTenantIdProvider);

  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 7));

  final allLogs = await repository.fetchAllClientLogs(clientId, tenantId);

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
  final tenantId = ref.watch(currentTenantIdProvider);

  final allLogs = await repository.fetchAllClientLogs(params.clientId, tenantId);

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

final labTestConfigsProvider = StreamProvider<List<LabTestConfigModel>>((ref) {

  final tenantId = ref.watch(currentTenantIdProvider);

  if (tenantId == null || tenantId.isEmpty) {
    return Stream.value([]);
  }
  final collection = FirebaseFirestore.instance.collection('config_labTestConfigs');

  final globalStream = collection
      .where('isGlobal', isEqualTo: true)
      .where('isDeleted', isEqualTo: false)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => LabTestConfigModel.fromFirestore(doc))
      .toList());

  Stream<List<LabTestConfigModel>> tenantStream;
  if (tenantId != null && tenantId.isNotEmpty) {
    tenantStream = collection
        .where('tenantId', isEqualTo: tenantId)
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => LabTestConfigModel.fromFirestore(doc))
        .toList());
  } else {
    tenantStream = Stream.value([]);
  }

  return Rx.combineLatest2(
      globalStream,
      tenantStream,
          (List<LabTestConfigModel> globalList, List<LabTestConfigModel> tenantList) {

        final List<LabTestConfigModel> combined = [...globalList, ...tenantList];

        combined.sort((a, b) {
          int orderDiff = a.order.compareTo(b.order);
          if (orderDiff != 0) return orderDiff;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        return combined;
      }
  );
});


// 🚀 THE FIX: We use .family<AdminProfileModel?, String> to pass the coachId securely
final dietitianProfileProvider = FutureProvider.family<AdminProfileModel?, String>((ref, coachId) async {
  try {
    // 1. If no coach is assigned, return null immediately
    if (coachId.isEmpty) {
      return null;
    }

    // 2. Fetch the specific Coach/Admin from the 'admins' collection
    final docSnapshot = await FirebaseFirestore.instance
        .collection('admins')
        .doc(coachId)
        .get();

    if (docSnapshot.exists) {
      return AdminProfileModel.fromFirestore(docSnapshot);
    }

    return null; // Coach ID exists on client, but document was deleted
  } catch (e) {
    throw Exception("Failed to load Care Team profile: $e");
  }
});