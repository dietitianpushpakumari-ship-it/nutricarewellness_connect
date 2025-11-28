// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../services/client_service.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthNotifier(this._clientService) : super(AuthState(isLoading: true)) {
    // 🎯 Live Logic: Listen to Firebase Auth state changes
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    if (user == null) {
      state = state.copyWith(currentUser: null, clientId: null, initialCheckComplete: true, isLoading: false);
      return;
    }
    // Set the Firestore ID (clientId) to the Auth UID.
    state = state.copyWith(currentUser: user, clientId: user.uid, initialCheckComplete: true, isLoading: false);
  }

  Future<void> signIn(String loginId, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Perform the API call
      await _clientService.clientSignIn(loginId, password);

      // 🎯 FIX 1: Force loading to false immediately on success.
      // Don't rely solely on the stream listener, as it might lag.
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }

    } catch (e, stack) {
      // 🎯 FIX 2: Catch 'e' (Everything), not just 'Exception'.
      // This catches TypeErrors (like the one in Step 1) that were freezing the UI.

      print("SignIn Error: $e");
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
    // State update handled by the listener
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// --- Riverpod Providers ---

//final clientServiceProvider = Provider((ref) => ClientService());

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(clientServiceProvider));
});

final currentClientIdProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider.select((auth) => auth.clientId));
});