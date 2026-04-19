import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/new/dashboard/tenant_model.dart';
import 'package:pure_shift/new/service/client_service.dart';
import 'package:pure_shift/features/auth/auth_provider.dart';

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

final tenantProfileProvider = FutureProvider.family<TenantModel?, String>((ref, tenantId) async {
  final doc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
  if (doc.exists && doc.data() != null) {
    return TenantModel.fromFirestore(doc); // Or .fromJson depending on your model
  }
  return null;
});