import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// 🎯 IMPORT YOUR DASHBOARD/HOME SCREEN HERE
import 'package:nutricare_connect/new/dashboard/client_dashboard_main_screen.dart';

import '../provider/diet_plan_provider.dart';

class UniversalLoginScreen extends ConsumerStatefulWidget {
  const UniversalLoginScreen({super.key});

  @override
  ConsumerState<UniversalLoginScreen> createState() => _UniversalLoginScreenState();
}

class _UniversalLoginScreenState extends ConsumerState<UniversalLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 🚀 1. PHONE + PASSWORD LOGIN (The Returning User Hack)
  // ===========================================================================
// ===========================================================================
  // 🚀 1. PHONE + PASSWORD LOGIN
  // ===========================================================================
  Future<void> _loginWithPhoneAndPassword() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showToast("Please enter both mobile number and password.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🎯 Call YOUR Riverpod AuthNotifier! This handles the dummy email hack
      // and fetches the ClientModel all in one go.
      final profiles = await ref.read(authNotifierProvider.notifier).signIn(phone, password);

      if (profiles.isNotEmpty) {
        _routeToDashboard(profiles.first); // Pass the client profile!
      } else {
        _showToast("Profile not found.", isError: true);
      }
    } catch (e) {
      _showToast("Login failed. Check your credentials.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 🚀 2. GOOGLE SIGN-IN
  // ===========================================================================
// ===========================================================================
  // 🚀 2. GOOGLE SIGN-IN
  // ===========================================================================
// ===========================================================================
  // 🚀 2. GOOGLE SIGN-IN (Updated for v7.0.0+)
  // ===========================================================================
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn.instance;

      // 1. Mandatory Initialization in v7+
      await googleSignIn.initialize();

      // 2. Authenticate (Replaces the old signIn() method)
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled the sign-in
      }

      // 3. Authorize scopes to get the Access Token (New split-architecture in v7+)
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);

      // 4. Get the ID Token from the authentication object
      final googleAuth = await googleUser.authentication;

      // 5. Create the Firebase Credential using both tokens
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 6. Sign in to Firebase!
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      await _checkIfNewOrExistingPatient(userCredential.user!);

    } catch (e) {
      _showToast("Google Sign-In failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 🚀 3. APPLE SIGN-IN
  // ===========================================================================
  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      final AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final AuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      await _checkIfNewOrExistingPatient(userCredential.user!);

    } catch (e) {
      _showToast("Apple Sign-In failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // 🚀 ROUTING & PROFILE CHECK LOGIC
  // ===========================================================================
// ===========================================================================
  // 🚀 ROUTING & PROFILE CHECK LOGIC
  // ===========================================================================
  Future<void> _checkIfNewOrExistingPatient(User user) async {
    // 🎯 Safely fetch the client using your existing service
    final clientProfile = await ref.read(clientServiceProvider).getClientById(user.uid);

    if (clientProfile != null && clientProfile.mobile.isNotEmpty) {
      // 🟢 Existing Patient! Lock them into Riverpod state
      ref.read(authNotifierProvider.notifier).selectProfile(clientProfile);

      // Route to dashboard with the profile!
      _routeToDashboard(clientProfile);
    } else {
      // 🟠 Brand New App User -> We need to get their Mobile Number to link offline records!
      _showToast("Welcome! Let's set up your profile.");

      // TODO: Navigate to the "Complete Profile" screen here
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CompleteProfileScreen()));
    }
  }

  void _routeToDashboard(ClientModel clientProfile) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ClientDashboardScreen(client: clientProfile)),
          (route) => false,
    );
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
          behavior: SnackBarBehavior.floating,
        )
    );
  }

  // ===========================================================================
  // 🚀 UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    bool isAppleDevice = kIsWeb ? true : (Platform.isIOS || Platform.isMacOS); // Adjust web check as needed

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // 🎯 THE RETURNING USER LOGIN
                  Text("Welcome Back", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Text("Log in to manage your appointments and reports.", style: TextStyle(color: theme.hintColor)),
                  const SizedBox(height: 32),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: "Mobile Number", prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: "Password", prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      onPressed: _isLoading ? null : _loginWithPhoneAndPassword,
                      child: const Text("Log In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 🎯 DIVIDER
                  Row(
                    children: [
                      Expanded(child: Divider(color: theme.dividerColor)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("OR", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold))),
                      Expanded(child: Divider(color: theme.dividerColor)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 🎯 GOOGLE SIGN-IN
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: theme.dividerColor),
                      ),
                      // Use a flutter built-in icon or standard image asset for Google
                      icon: Icon(Icons.g_mobiledata_rounded, size: 32, color: colorScheme.onSurface),
                      label: Text("Continue with Google", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: _isLoading ? null : _loginWithGoogle,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🎯 APPLE SIGN-IN
                  if (isAppleDevice)
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.apple, size: 28),
                        label: const Text("Continue with Apple", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        onPressed: _isLoading ? null : _loginWithApple,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 🎯 UNIVERSAL EMAIL FALLBACK
                  TextButton(
                    onPressed: () { /* Navigate to standard Email Registration Screen */ },
                    child: Text("Continue with Email", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  )
                ],
              ),
            ),

            // 🎯 LOADING OVERLAY
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                  child: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}