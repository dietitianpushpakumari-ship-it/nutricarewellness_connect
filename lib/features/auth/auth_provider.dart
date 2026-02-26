import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nutricare_connect/new/service/client_service.dart';
import 'package:nutricare_connect/core/utils/database_provider.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';

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
        // 🛑 LOGOUT: Wipe Everything
        state = AuthState(
            currentUser: null,
            clientId: null,
            clientProfile: null,
            isLoading: false,
            initialCheckComplete: true
        );
      } else {
        // ✅ LOGIN DETECTED
        state = state.copyWith(
            currentUser: user,
            clientId: user.uid,
            initialCheckComplete: true
        );

        // 🚑 AUTO-RECOVERY: If we have a user but NO profile, fetch it immediately
        if (state.clientProfile == null) {
          debugPrint("⚠️ Auth: User found, Profile missing. Fetching...");
          await _fetchProfileInternal(user.uid);
        }
      }
    });
  }

  Future<void> _fetchProfileInternal(String uid) async {
    try {
      final profile = await _clientService.getClientById(uid);
      if (profile != null && mounted) {
        state = state.copyWith(clientProfile: profile, isLoading: false);
        debugPrint("✅ Auth: Profile recovered.");
      }
    } catch (e) {
      debugPrint("❌ Auth: Failed to recover profile: $e");
    }
  }

// Inside your AuthNotifier class in lib/features/auth/auth_provider.dart

  Future<void> signIn(String mobile, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Authenticate and fetch profile from Service
      final profile = await _clientService.clientSignIn(mobile, password);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Authentication failed.");

      // 2. 🎯 ATOMIC UPDATE
      // We update everything in ONE shot.
      state = state.copyWith(
        currentUser: user,
        clientId: user.uid,
        clientProfile: profile, // This is what the Dashboard needs
        isLoading: false,
        initialCheckComplete: true,
      );

      debugPrint("✅ AuthNotifier: State updated with Profile for ${profile.name}");

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await FirebaseAuth.instance.signOut();
  }
}

// --- Providers ---
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(clientServiceProvider), ref);
});

final currentClientIdProvider = Provider<String?>((ref) => ref.watch(authNotifierProvider).clientId);
final currentClientProvider = Provider<ClientModel?>((ref) => ref.watch(authNotifierProvider).clientProfile);

// -----------------------------------------------------------------------------
// 🎯 SAFE MIRROR PROVIDER (Satisfies other file dependencies)
// -----------------------------------------------------------------------------
final clientProfileFutureProvider = FutureProvider<ClientModel?>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  return authState.clientProfile;
});