import 'dart:ui';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/core/utils/database_provider.dart';
import 'package:nutricare_connect/features/auth/client_service.dart';
import 'package:nutricare_connect/new/dashboard/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/main.dart'; // Import for provider
import 'auth_provider.dart';

// 🎨 GLOBAL CONSTANTS
const Color kPrimaryColor = Color(0xFF00695C);
const Color kAccentColor = Color(0xFF80CBC4);
const bool kEnableGuestMode = true;

// 🎯 UPDATED CONSTANTS (Match ClientService)
const String kPinSalt = "@NC2026";
const String kAuthDomain = "@nutricare-v4.com";

enum AuthPage { login, registerGateway, registerVerify, signUp, registerPassword, forgotPassword }

class ClientAuthScreen extends ConsumerStatefulWidget {
  const ClientAuthScreen({super.key});

  @override
  ConsumerState<ClientAuthScreen> createState() => _ClientAuthScreenState();
}

class _ClientAuthScreenState extends ConsumerState<ClientAuthScreen> with SingleTickerProviderStateMixin {
  AuthPage _currentPage = AuthPage.login;

  final _loginIdController = TextEditingController();
  final _loginPinController = TextEditingController();

  final _regPatientIdController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regActivationCodeController = TextEditingController();

  final _regPinController = TextEditingController();
  final _regConfirmPinController = TextEditingController();
  final _regNameController = TextEditingController();

  ClientModel? _validatedClient;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _failedAttempts = 0;
  DateTime? _lockoutTime;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPinController.dispose();
    _regPatientIdController.dispose();
    _regMobileController.dispose();
    _regActivationCodeController.dispose();
    _regPinController.dispose();
    _regConfirmPinController.dispose();
    _regNameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 🔐 LOGIC METHODS
  // ===========================================================================

// ... inside ClientAuthScreen class ...

// ... imports ...

  // ---------------------------------------------------------------------------
  // 🔐 LOGIN: Simple & Robust
  // ---------------------------------------------------------------------------
  Future<void> _login() async {
    final loginId = _loginIdController.text.trim();
    final pin = _loginPinController.text.trim();

    if (loginId.isEmpty || pin.isEmpty) {
      _showMessage('Please enter Mobile and PIN.', isError: true);
      return;
    }

    // Show loading overlay or disable button
    HapticFeedback.lightImpact();

    try {
      // 1. Perform Login and get the result
      await ref.read(authNotifierProvider.notifier).signIn(loginId, pin + kPinSalt);

      // 2. 🎯 FORCED REDIRECT
      // We grab the loaded profile directly from the provider we just updated
      final clientProfile = ref.read(authNotifierProvider).clientProfile;

      if (clientProfile != null && mounted) {
        // Sync the Global Provider immediately
        ref.read(globalUserProvider.notifier).setUser(clientProfile);

        // Force Navigation to the Dashboard and clear the backstack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ClientDashboardScreen(client: clientProfile),
          ),
              (route) => false, // This removes the Login screen from memory
        );
      } else {
        // Fallback: If for some reason profile is null, main.dart's fallback will handle it
        debugPrint("⚠️ Login successful but profile not in state yet.");
      }

    } catch (e) {
      if (mounted) {
        setState(() => _failedAttempts++);
        _showMessage('Login failed: ${e.toString().replaceAll("Exception:", "").trim()}', isError: true);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🔐 ACTIVATION: Tenant Aware
  // ---------------------------------------------------------------------------
  Future<void> _completeActivation() async {
    final pin = _regPinController.text.trim();
    final confirm = _regConfirmPinController.text.trim();

    if (pin != confirm) { _showMessage('PINs do not match.', isError: true); return; }
    if (pin.length != 4) { _showMessage('PIN must be exactly 4 digits.', isError: true); return; }

    ref.read(authNotifierProvider.notifier).state =
        ref.read(authNotifierProvider).copyWith(isLoading: true);

    try {
      final service = ref.read(clientServiceProvider);
      final securePassword = pin + kPinSalt;

      // 1. Create Auth & Link (Service Logic)
      await service.activateClientAccess(
          client: _validatedClient!,
          pin: securePassword
      );

      // 2. Force Login & State Update
      if (mounted) {
        await ref.read(authNotifierProvider.notifier).signIn(
            _validatedClient!.mobile,
            securePassword
        );

        // 🚀 FORCE REFRESH
        ref.invalidate(clientProfileFutureProvider);
      }

    } catch (e) {
      _showMessage('Activation failed: $e', isError: true);
      if (mounted) {
        ref.read(authNotifierProvider.notifier).state =
            ref.read(authNotifierProvider).copyWith(isLoading: false);
      }
    }
  }
// ... rest of class ...

  Future<void> _handleBiometricLogin() async {
    HapticFeedback.mediumImpact();
    _showMessage("Biometric Scan initiated... (Requires Integration)", isError: false);
  }

  Future<void> _validateRegistration() async {
    final patientId = _regPatientIdController.text.trim();
    final mobile = _regMobileController.text.trim();
    final code = _regActivationCodeController.text.trim();

    if (patientId.isEmpty || mobile.isEmpty || code.isEmpty) {
      _showMessage("All fields are required.", isError: true);
      return;
    }

    ref.read(authNotifierProvider.notifier).state =
        ref.read(authNotifierProvider).copyWith(isLoading: true, error: null);

    try {
      final query = await FirebaseFirestore.instance
          .collection('clients')
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) throw "Patient ID not found.";

      final doc = query.docs.first;
      final data = doc.data();

      String registeredMobile = (data['mobile'] ?? '').toString();
      String cleanInput = mobile.replaceAll(RegExp(r'\D'), '');
      String cleanDb = registeredMobile.replaceAll(RegExp(r'\D'), '');
      if (cleanInput.length < 10) throw "Enter valid 10-digit mobile.";
      if (!cleanDb.endsWith(cleanInput)) throw "Mobile number mismatch.";

      // ALLOW RE-ACTIVATION (RESET)
      // We removed the "Already Active" check to allow PIN Resets via Activation Code

      String serverToken = (data['loginToken'] ?? '').toString().trim();
      if (serverToken.isEmpty) throw "Activation Code not generated yet.";
      if (serverToken != code.trim()) throw "Invalid Activation Code.";

      ref.read(isGuestModeProvider.notifier).state = false;
      await ref.read(firebaseAppProvider.future);

      if (mounted) {
        setState(() {
          _validatedClient = ClientModel.fromFirestore(doc);
          _currentPage = AuthPage.registerPassword;
        });
        _showMessage('Code Verified. Set your secure PIN.', isError: false);
      }

    } catch (e) {
      _showMessage(e.toString().replaceAll("Exception:", "").trim(), isError: true);
    } finally {
      if (mounted) {
        ref.read(authNotifierProvider.notifier).state =
            ref.read(authNotifierProvider).copyWith(isLoading: false);
      }
    }
  }


  Future<void> _handleNewUserSignUp() async {
    final name = _regNameController.text.trim();
    final mobile = _regMobileController.text.trim();
    final pin = _regPinController.text.trim();

    if (name.isEmpty || mobile.isEmpty || pin.isEmpty) { _showMessage("All fields required.", isError: true); return; }
    if (pin.length != 4) { _showMessage("PIN must be 4 digits.", isError: true); return; }

    ref.read(isGuestModeProvider.notifier).state = true;
    await ref.read(firebaseAppProvider.future);

    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);

    try {
      await service.registerNewUser(name: name, mobile: mobile, password: pin + kPinSalt);
      await ref.read(authNotifierProvider.notifier).signIn(mobile, pin + kPinSalt);
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if(mounted) ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }

  Future<void> _handleGuestDemo() async {
    ref.read(isGuestModeProvider.notifier).state = true;
    await ref.read(firebaseAppProvider.future);
    setState(() => _currentPage = AuthPage.signUp);
    _showMessage("Entering Guest Registration...", isError: false);
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: isError ? Colors.redAccent : kPrimaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )
    );
  }

  void _clearControllers() {
    _regPatientIdController.clear(); _regMobileController.clear();
    _regActivationCodeController.clear();
    _regPinController.clear(); _regConfirmPinController.clear(); _regNameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    Widget content;
    switch (_currentPage) {
      case AuthPage.login: content = _buildLoginScreen(authState); break;
      case AuthPage.registerGateway: content = _buildGatewayScreen(); break;
      case AuthPage.registerVerify: content = _buildActivationScreen(authState); break;
      case AuthPage.signUp: content = _buildGuestSignUp(authState); break;
      case AuthPage.registerPassword: content = _buildPinSetScreen(authState); break;
      case AuthPage.forgotPassword: content = _buildForgotPassword(authState); break;
      default: content = _buildLoginScreen(authState);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(color: kAccentColor.withOpacity(0.15), shape: BoxShape.circle),
              ),
            ),
          ),
          Positioned(
            top: 100, left: -80,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SCREENS ---
  Widget _buildLoginScreen(AuthState s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(),
        const SizedBox(height: 40),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Welcome Back", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              const Text("Sign in with your secure PIN", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 32),

              _buildModernTextField(controller: _loginIdController, label: "Mobile Number", icon: Icons.phone_android, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),

              TextField(
                controller: _loginPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "4-Digit PIN",
                  counterText: "",
                  prefixIcon: Icon(Icons.lock_clock_outlined, color: kPrimaryColor.withOpacity(0.6)),
                  filled: true, fillColor: const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                ),
              ),

              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => _currentPage = AuthPage.forgotPassword), child: const Text("Forgot PIN?", style: TextStyle(color: Colors.grey, fontSize: 12)))),
              const SizedBox(height: 16),
              _buildModernButton("Log In", s.isLoading, _login),
              const SizedBox(height: 16),
              TextButton.icon(onPressed: _handleBiometricLogin, icon: const Icon(Icons.fingerprint, color: kPrimaryColor), label: const Text("Use FaceID / TouchID", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text("First time here?", style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        TextButton(onPressed: () { _clearControllers(); setState(() => _currentPage = AuthPage.registerGateway); }, child: const Text("ACTIVATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, color: kPrimaryColor))),
      ],
    );
  }

  Widget _buildGatewayScreen() {
    return Column(
      children: [
        _buildBackBtn(() => setState(() => _currentPage = AuthPage.login)),
        _buildLogo(compact: true),
        const SizedBox(height: 30),
        const Text("Get Started", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 10),
        const Text("Choose how you want to join NutriCare", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 40),
        _buildOptionCard(icon: Icons.verified_user_outlined, title: "I have an Activation Code", desc: "From my activation letter or WhatsApp.", color: kPrimaryColor, onTap: () { ref.read(isGuestModeProvider.notifier).state = false; setState(() => _currentPage = AuthPage.registerVerify); }),
        const SizedBox(height: 16),
        if (kEnableGuestMode) _buildOptionCard(icon: Icons.explore_outlined, title: "I'm New Here", desc: "I want to explore the app first.", color: Colors.orange, onTap: _handleGuestDemo),
      ],
    );
  }

  Widget _buildActivationScreen(AuthState s) {
    return Column(
      children: [
        _buildBackBtn(() => setState(() => _currentPage = AuthPage.registerGateway)),
        const SizedBox(height: 20),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_open_rounded, size: 48, color: kPrimaryColor),
              const SizedBox(height: 16),
              const Text("Activate Account", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Enter the 6-digit code from your letter.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 30),
              _buildModernTextField(controller: _regPatientIdController, label: "Patient ID", icon: Icons.badge_outlined),
              const SizedBox(height: 16),
              _buildModernTextField(controller: _regMobileController, label: "Mobile Number", icon: Icons.phone_android, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildModernTextField(controller: _regActivationCodeController, label: "6-Digit Activation Code", icon: Icons.key, keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              _buildModernButton("Verify Code", s.isLoading, _validateRegistration),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinSetScreen(AuthState s) {
    return Column(
      children: [
        _buildBackBtn(() => setState(() => _currentPage = AuthPage.registerVerify)),
        const SizedBox(height: 20),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.security, size: 48, color: Colors.green),
              const SizedBox(height: 16),
              const Text("Set Login PIN", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Create a 4-digit PIN for quick login.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 30),

              TextField(
                controller: _regPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: "New PIN",
                  counterText: "",
                  prefixIcon: Icon(Icons.lock, color: Colors.teal.shade300),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true, fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _regConfirmPinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: "Confirm PIN",
                  counterText: "",
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.teal.shade300),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true, fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 24),
              _buildModernButton("Set PIN & Login", s.isLoading, _completeActivation),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestSignUp(AuthState s) {
    return Column(
      children: [
        _buildBackButton(() => setState(() => _currentPage = AuthPage.registerGateway)),
        const SizedBox(height: 20),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Guest Registration", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              _buildModernTextField(controller: _regNameController, label: "Full Name", icon: Icons.person_outline),
              const SizedBox(height: 16),
              _buildModernTextField(controller: _regMobileController, label: "Mobile Number", icon: Icons.phone_android, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildModernTextField(controller: _regPinController, label: "Create PIN (4 Digits)", icon: Icons.lock_outline, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),
              const SizedBox(height: 24),
              _buildModernButton("Create Account", s.isLoading, _handleNewUserSignUp),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword(AuthState s) {
    return Column(
      children: [
        _buildBackButton(() => setState(() => _currentPage = AuthPage.login)),
        const SizedBox(height: 20),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Reset PIN", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("To reset your PIN, please use the 'Activate Account' option with your original activation code.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 30),
              _buildModernButton("Go to Activation", false, () { setState(() => _currentPage = AuthPage.registerGateway); }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo({bool compact = false}) {
    return Column(
      children: [
        Container(padding: EdgeInsets.all(compact ? 12 : 20), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]), child: Icon(Icons.spa, color: kPrimaryColor, size: compact ? 30 : 50)),
        if (!compact) ...[const SizedBox(height: 16), const Text("NutriCare", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -1.0)), const Text("WELLNESS", style: TextStyle(fontSize: 10, letterSpacing: 4.0, color: Colors.grey, fontWeight: FontWeight.bold))],
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)), BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 1, offset: const Offset(0, 0))]), child: child);
  }

  Widget _buildModernTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    return TextField(controller: controller, obscureText: isPassword, keyboardType: keyboardType, maxLength: maxLength, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), decoration: InputDecoration(labelText: label, counterText: "", labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13), prefixIcon: Icon(icon, color: kPrimaryColor.withOpacity(0.6), size: 20), filled: true, fillColor: const Color(0xFFF0F2F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)), contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16)));
  }

  Widget _buildModernButton(String text, bool isLoading, VoidCallback onPressed) {
    return SizedBox(height: 56, child: ElevatedButton(onPressed: isLoading ? null : onPressed, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white, elevation: 4, shadowColor: kPrimaryColor.withOpacity(0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5))));
  }

  Widget _buildOptionCard({required IconData icon, required String title, required String desc, required Color color, required VoidCallback onTap}) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(20), elevation: 2, shadowColor: Colors.black.withOpacity(0.05), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12))])), Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade300)]))));
  }

  Widget _buildBackButton(VoidCallback onTap) {
    return Align(alignment: Alignment.centerLeft, child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black54), onPressed: onTap, padding: const EdgeInsets.all(0)));
  }

  Widget _buildBackBtn(VoidCallback onTap) => _buildBackButton(onTap);
}