import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nutricare_connect/core/utils/database_provider.dart'; // 🎯 Import Database Provider
import 'client_service.dart';

// --- State Definitions ---
class AuthState {
  final User? currentUser;
  final String? clientId;
  final bool isLoading;
  final String? error;
  final bool initialCheckComplete;

  AuthState({this.currentUser, this.clientId, this.isLoading = false, this.error, this.initialCheckComplete = false});

  AuthState copyWith({
    User? currentUser, String? clientId, bool? isLoading, Object? error = const Object(), bool? initialCheckComplete,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      clientId: clientId ?? this.clientId,
      isLoading: isLoading ?? this.isLoading,
      error: error is String ? error : (error == null ? null : this.error),
      initialCheckComplete: initialCheckComplete ?? this.initialCheckComplete,
    );
  }
}

// --- Notifier (ViewModel) ---
class AuthNotifier extends StateNotifier<AuthState> {
  final ClientService _clientService;
  final Ref _ref;

  AuthNotifier(this._clientService, this._ref) : super(AuthState(isLoading: true)) {
    _initListener();
  }

  // 🎯 FIX: Make this async and wait for initialization
  Future<void> _initListener() async {


    // Simulate a short delay to mimic loading (optional)
    await Future.delayed(const Duration(milliseconds: 500));

    // Force the state to be "Logged In" with your demo ID
    state = state.copyWith(
      clientId: 'zLxmLOlSe9XvVCjwOw0x', // <--- Your Hardcoded ID
      initialCheckComplete: true,
      isLoading: false,
      // Note: currentUser will be null, so ensure your DB
      // service doesn't rely on 'FirebaseAuth.instance.currentUser'
      // for simple reads, or your DB rules are open for this demo.
    );

    return;
    try {
      // 1. Wait for the dynamic Firebase App (Live or Guest) to be ready
      await _ref.read(firebaseAppProvider.future);

      // 2. NOW it is safe to read the auth provider
      final auth = _ref.read(authProvider);
      auth.authStateChanges().listen(_onAuthStateChanged);
    } catch (e) {
      print("Auth Init Error: $e");
      // If init fails (e.g. config missing), fallback to loading state or error
      state = state.copyWith(isLoading: false, error: "Database Init Failed: $e");
    }
  }

  void _onAuthStateChanged(User? user) {
    if (user == null) {
      state = state.copyWith(currentUser: null, clientId: null, initialCheckComplete: true, isLoading: false);
      return;
    }
    state = state.copyWith(currentUser: user, clientId: user.uid, initialCheckComplete: true, isLoading: false);
  }

  Future<void> signIn(String loginId, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _clientService.clientSignIn(loginId, password);
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      print("SignIn Error: $e");
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    // 🎯 Sign out of the CURRENT instance
    final auth = _ref.read(authProvider);
    await auth.signOut();
  }
}

// --- Riverpod Providers ---

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  // 🎯 Watch the Mode Switch!
  ref.watch(isGuestModeProvider);

  return AuthNotifier(ref.watch(clientServiceProvider), ref);
});

final currentClientIdProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider.select((auth) => auth.clientId));
});