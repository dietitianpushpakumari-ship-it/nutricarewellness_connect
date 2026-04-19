import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pure_shift/new/service/client_service.dart';
import 'package:pure_shift/core/utils/database_provider.dart';
import 'package:pure_shift/core/utils/client_model.dart';

// --- State Definition ---
class AuthState {
  final User? currentUser;
  final String? clientId;
  final ClientModel? clientProfile;
  final bool isLoading;
  final String? error;
  final bool initialCheckComplete;

  AuthState({
    this.currentUser,
    this.clientId,
    this.clientProfile,
    this.isLoading = false,
    this.error,
    this.initialCheckComplete = false,
  });

  AuthState copyWith({
    User? currentUser,
    String? clientId,
    ClientModel? clientProfile,
    bool? isLoading,
    String? error,
    bool? initialCheckComplete,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      clientId: clientId ?? this.clientId,
      // 🎯 KEEP EXISTING PROFILE unless a new one is explicitly provided
      clientProfile: clientProfile ?? this.clientProfile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      initialCheckComplete: initialCheckComplete ?? this.initialCheckComplete,
    );
  }
}

// --- Notifier ---
class AuthNotifier extends StateNotifier<AuthState> {
  final ClientService _clientService;
  final Ref _ref;

  AuthNotifier(this._clientService, this._ref) : super(AuthState(isLoading: true)) {
    _initListener();
  }

  Future<void> _initListener() async {
    await _ref.read(firebaseAppProvider.future);

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) {
        // 🛑 LOGOUT: Wipe Everything & Finish Check
        state = AuthState(
            currentUser: null,
            clientId: null,
            clientProfile: null,
            isLoading: false,
            initialCheckComplete: true
        );
      } else {
        // ✅ LOGIN DETECTED
        // 1. Set the user, but DO NOT set initialCheckComplete yet.
        state = state.copyWith(
          currentUser: user,
          clientId: user.uid,
        );

        // 2. 🚑 AUTO-RECOVERY: Wait for the profile to fetch!
        if (state.clientProfile == null) {
          debugPrint("⚠️ Auth: User found, Profile missing. Fetching...");
          await _fetchProfileInternal(user.uid);
        }

        // 3. 🎯 NOW tell main.dart that the check is fully complete
        state = state.copyWith(initialCheckComplete: true);
      }
    });
  }

// ===========================================================================
  // 🚀 1. BULLETPROOF PROFILE RECOVERY
  // ===========================================================================
  Future<void> _fetchProfileInternal(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final lastPatientId = prefs.getString('last_active_patient_id');
      final lastTenantId = prefs.getString('last_active_tenant_id') ?? ''; // Safely handle null

      // Attempt 1: Recover via SharedPreferences
      if (lastPatientId != null && lastPatientId.isNotEmpty) {
        final profile = await _clientService.getSpecificProfile(uid, lastPatientId, lastTenantId);
        if (profile != null && mounted) {
          state = state.copyWith(clientProfile: profile, isLoading: false);
          debugPrint("✅ Auth: Profile recovered via local storage.");
          return;
        }
      }

      // Attempt 2: 🚑 THE FALLBACK RECOVERY
      // If storage was cleared, but Firebase Auth is still alive, don't give up!
      debugPrint("⚠️ Auth: Local storage missing. Attempting Firebase Auth fallback...");
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.email != null && user.email!.contains('@nutricare.internal')) {
        // Extract the mobile number from the dummy email (e.g., "1234567890@nutricare.internal")
        final mobile = user.email!.split('@').first;
        final profiles = await _clientService.getProfilesForAuthenticatedUser(mobile);

        if (profiles.isNotEmpty && mounted) {
          // Recover the profile and re-save it to storage
          await selectProfile(profiles.first);
          debugPrint("✅ Auth: Profile auto-recovered via Firebase session fallback!");
          return;
        }
      }

    } catch (e) {
      debugPrint("❌ Auth: Failed to recover profile: $e");
    }
  }

  // ===========================================================================
  // 🚀 2. SAFE SIGN-IN SAVE
  // ===========================================================================
  Future<List<ClientModel>> signIn(String mobile, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final String authEmail = "$mobile@nutricare.internal";
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: authEmail, password: password);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Authentication failed.");

      final profiles = await _clientService.getProfilesForAuthenticatedUser(mobile);
      if (profiles.isEmpty) throw Exception("Account verified, but profile data is missing.");

      if (profiles.length == 1) {
        final profile = profiles.first;

        // 🎯 FIX: Prevent crash if tenantId or patientId is null!
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_active_patient_id', profile.patientId ?? '');
        await prefs.setString('last_active_tenant_id', profile.tenantId ?? '');

        state = state.copyWith(
          currentUser: user,
          clientId: user.uid,
          clientProfile: profile,
          isLoading: false,
          initialCheckComplete: true,
        );
      } else {
        state = state.copyWith(
          currentUser: user,
          clientId: user.uid,
          clientProfile: null,
          isLoading: false,
          initialCheckComplete: true,
        );
      }
      return profiles;
    } on FirebaseAuthException catch (_) {
      state = state.copyWith(isLoading: false, error: "Invalid Mobile Number or PIN.");
      throw Exception("Invalid Mobile Number or PIN.");
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ===========================================================================
  // 🚀 3. SAFE PROFILE SELECTION SAVE
  // ===========================================================================
  Future<void> selectProfile(ClientModel profile) async {
    // 🎯 FIX: Prevent crash if tenantId or patientId is null!
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_active_patient_id', profile.patientId ?? '');
    await prefs.setString('last_active_tenant_id', profile.tenantId ?? '');

    state = state.copyWith(clientProfile: profile);
  }


  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);

    // 🚀 Clear BOTH persistences on logout so next login is fresh
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_active_patient_id');
    await prefs.remove('last_active_tenant_id');

    await FirebaseAuth.instance.signOut();
  }
}

// --- Providers ---
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(clientServiceProvider), ref);
});

// -----------------------------------------------------------------------------
// 🎯 THE MAGIC FIX: Get IDs directly from the loaded profile
// -----------------------------------------------------------------------------

// This now returns the true Firestore Document ID, not the Auth UID!
final currentClientIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(authNotifierProvider).clientProfile;
  return profile?.id;
});

// Since you need the tenantId too, expose it the exact same way
final currentTenantIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(authNotifierProvider).clientProfile;
  return profile?.tenantId;
});

final currentClientProvider = Provider<ClientModel?>((ref) => ref.watch(authNotifierProvider).clientProfile);

// -----------------------------------------------------------------------------
// 🎯 SAFE MIRROR PROVIDER (Satisfies other file dependencies)
// -----------------------------------------------------------------------------
final clientProfileFutureProvider = FutureProvider<ClientModel?>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  return authState.clientProfile;
});