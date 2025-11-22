import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';

// 1. The StateNotifier class to manage the ClientModel
class UserNotifier extends StateNotifier<ClientModel?> {
  final ClientService _clientService;

  UserNotifier(this._clientService) : super(null);

  // Update user data manually (e.g. after profile edit)
  void setUser(ClientModel user) {
    state = user;
  }

  // Fetch and Cache User Data
  Future<void> fetchUser(String clientId) async {
    try {
      final user = await _clientService.getClientById(clientId);
      if (user != null) {
        state = user; // <--- Stores it in memory (RAM)
      }
    } catch (e) {
      print("Error fetching global user: $e");
    }
  }

  void clearUser() {
    state = null;
  }
}

// 2. The Provider Definition
final globalUserProvider = StateNotifierProvider<UserNotifier, ClientModel?>((ref) {
  final clientService = ref.watch(clientServiceProvider);
  return UserNotifier(clientService);
});