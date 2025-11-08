import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:nutricare_connect/core/app_theme.dart';

// 🎯 ADJUST IMPORTS TO YOUR PROJECT STRUCTURE

import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_auth_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_dashboard_main_screen.dart'; // The new dashboard
import 'package:nutricare_connect/services/client_service.dart';

import 'features/dietplan/PRESENTATION/providers/auth_provider.dart';
import 'firebase_options.dart';


// --- Client Profile Lookup Provider ---
// This provider fetches the full profile based on the authenticated UID.
final clientProfileFutureProvider = FutureProvider<ClientModel?>((ref) async {
  // Read the authenticated user's ID from the AuthProvider state
  final clientId = ref.watch(authNotifierProvider.select((state) => state.clientId));
  if (clientId == null) return null;

  // Use the service to fetch the profile
  final clientService = ref.watch(clientServiceProvider);

  // NOTE: Assuming getClientById is now implemented in ClientService
  return clientService.getClientById(clientId);
});


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase Core
  await Firebase.initializeApp(
    // NOTE: Ensure your firebase_options.dart path is correct
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Activate App Check Provider (Using debug for development ease)
  await FirebaseAppCheck.instance.activate(
    // Ensure the correct provider is used (e.g., debug for testing)
    androidProvider: AndroidProvider.debug,
  );

  runApp(const ProviderScope(child: NutriCareClientApp()));
}

class NutriCareClientApp extends ConsumerWidget {
  const NutriCareClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    // Check if initial Firebase Auth check is complete
    if (!authState.initialCheckComplete) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // 1. Check if user is authenticated (clientId is available)
    final isAuthenticated = authState.clientId != null;

    if (isAuthenticated) {
      // 2. Fetch the full client profile based on the authenticated UID
      final clientProfileAsync = ref.watch(clientProfileFutureProvider);

      return clientProfileAsync.when(
        loading: () => const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator()))),
        error: (e, s) => MaterialApp(home: Scaffold(body: Center(child: Text('Error loading client profile: $e')))),
        data: (client) {
          if (client == null) {
            // User is authenticated but the Firestore profile record is missing
            return const MaterialApp(home: Scaffold(body: Center(child: Text('User profile data missing. Please complete setup.'))));
          }

          // 3. Navigate to the dashboard, passing the loaded ClientModel
          return MaterialApp(
            title: 'NutriCare Client',
            theme: ThemeData(
              primarySwatch: Colors.teal,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              useMaterial3: true,
            ),
            home: ClientDashboardScreen(client: client),
            debugShowCheckedModeBanner: false,
          );
        },
      );
    }

    // Default to Auth Screen if not authenticated
    return MaterialApp(
      title: 'NutriCare Client',
      theme: AppTheme.lightTheme,
      home: const ClientAuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}