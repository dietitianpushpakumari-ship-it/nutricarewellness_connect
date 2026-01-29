import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/core/utils/database_provider.dart'; // 🎯 Import
import 'package:nutricare_connect/features/auth/client_service.dart';
import 'auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'dart:ui';

enum AuthPage { login, registerGateway, registerVerify, signUp, registerPassword, forgotPassword }

class ClientAuthScreen extends ConsumerStatefulWidget {
  const ClientAuthScreen({super.key});

  @override
  ConsumerState<ClientAuthScreen> createState() => _ClientAuthScreenState();
}

class _ClientAuthScreenState extends ConsumerState<ClientAuthScreen> with SingleTickerProviderStateMixin {
  // 🎯 Enable Guest Mode button if you want the separate button too
  static const bool kEnableGuestMode = true;
  AuthPage _currentPage = AuthPage.login;

  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _regPatientIdController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regNameController = TextEditingController();

  ClientModel? _validatedClient;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _regPatientIdController.dispose();
    _regMobileController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _regNameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // --- 🎯 LOGIC: LOGIN ---
  Future<void> _login() async {
    final loginId = _loginIdController.text.trim();
    final password = _loginPasswordController.text.trim();
    if (loginId.isEmpty || password.isEmpty) {
      _showMessage('Please enter ID and Password.', isError: true);
      return;
    }
    try {
      // Note: By default we assume Live mode for login unless user explicitly switched.
      // If you want to support Guest Login, they should already be in Guest Mode via the UI flow.
      await ref.read(authNotifierProvider.notifier).signIn(loginId, password);
    } catch (e) {
      _showMessage('Login failed: ${e.toString().split(':').last.trim()}', isError: true);
    }
  }

  // --- 🎯 LOGIC: VERIFY PATIENT (Force Live Mode Check) ---
  Future<void> _validateRegistration() async {
    final patientId = _regPatientIdController.text.trim();
    final mobile = _regMobileController.text.trim();
    if (patientId.isEmpty || mobile.isEmpty) { _showMessage("Please enter both Patient ID and Mobile.", isError: true); return; }

    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);

    try {
      // 1. Check if this patient exists in the LIVE database
      bool existsInLive = await service.verifyPatientInLiveDb(patientId);

      if (existsInLive) {
        // ✅ FOUND!
        // Switch app to Live Mode (if not already)
        ref.read(isGuestModeProvider.notifier).state = false;
        await ref.read(firebaseAppProvider.future); // Ensure initialized

        // Now fetch the full details from the Live DB
        final client = await service.getClientByPatientIdAndMobile(patientId, mobile);

        if (client != null) {
          setState(() { _validatedClient = client; _currentPage = AuthPage.registerPassword; });
          _showMessage('Identity Verified! Set your password.', isError: false);
        } else {
          _showMessage('Mobile number does not match records.', isError: true);
        }
      } else {
        // ❌ NOT FOUND
        _showMessage("Patient ID not found. Use 'New User' to explore as Guest.", isError: true);
      }
    } catch (e) {
      _showMessage('Verification Error: ${e.toString()}', isError: true);
    } finally {
      ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }

  Future<void> _completeActivation() async {
    final password = _regPasswordController.text.trim();
    final confirm = _regConfirmPasswordController.text.trim();
    if (password != confirm) { _showMessage('Passwords do not match.', isError: true); return; }
    if (password.length < 6) { _showMessage('Password too short.', isError: true); return; }

    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);
    try {
      await service.registerClientCredentials(_validatedClient!.id, _validatedClient!.mobile, password);
      await ref.read(authNotifierProvider.notifier).signIn(_validatedClient!.mobile, password);
    } catch (e) { _showMessage('Activation failed: $e', isError: true); }
    finally { ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false); }
  }

  // --- 🎯 LOGIC: GUEST/NEW USER SIGN UP ---
  Future<void> _handleNewUserSignUp() async {
    final name = _regNameController.text.trim();
    final mobile = _regMobileController.text.trim();
    final pass = _regPasswordController.text.trim();
    if (name.isEmpty || mobile.isEmpty || pass.isEmpty) { _showMessage("All fields are required.", isError: true); return; }
    if (mobile.length < 10) { _showMessage("Invalid mobile number.", isError: true); return; }

    // Ensure we are in Guest Mode (Should be set by UI before coming here)
    if (!ref.read(isGuestModeProvider)) {
      // Fallback safety
      ref.read(isGuestModeProvider.notifier).state = true;
      await ref.read(firebaseAppProvider.future);
    }

    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);
    try {
      await service.registerNewUser(name: name, mobile: mobile, password: pass);
      await ref.read(authNotifierProvider.notifier).signIn(mobile, pass);
      _showMessage("Welcome, $name! You are in Guest Mode.", isError: false);
    } catch (e) { _showMessage(e.toString().replaceAll("Exception:", "").trim(), isError: true); }
    finally { if(mounted) ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false); }
  }

  Future<void> _handleGuestDemo() async {
    // 1. Switch State
    ref.read(isGuestModeProvider.notifier).state = true;
    // 2. Wait for Firebase Init
    await ref.read(firebaseAppProvider.future);
    // 3. Navigate
    setState(() => _currentPage = AuthPage.signUp);
    _showMessage("Entering Guest Mode...", isError: false);
  }

  void _switchToLiveAndLogin() {
    ref.read(isGuestModeProvider.notifier).state = false;
    setState(() => _currentPage = AuthPage.login);
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.teal));
  }

  void _clearControllers() {
    _regPatientIdController.clear(); _regMobileController.clear(); _regPasswordController.clear(); _regConfirmPasswordController.clear(); _regNameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isGuest = ref.watch(isGuestModeProvider); // Watch mode for UI updates

    Widget content;
    switch (_currentPage) {
      case AuthPage.login: content = _buildSimpleLogin(authState); break;
      case AuthPage.registerGateway: content = _buildRegisterGateway(); break;
      case AuthPage.registerVerify: content = _buildRegisterVerify(authState); break;
      case AuthPage.signUp: content = _buildSignUp(authState); break;
      case AuthPage.registerPassword: content = _buildRegisterPassword(authState); break;
      case AuthPage.forgotPassword: content = _buildForgotPassword(authState); break;
      default: content = _buildSimpleLogin(authState);
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isGuest ? [Colors.orange.shade50, Colors.white] : [Color(0xFFE0F2F1), Color(0xFFF8F9FE)],
              ),
            ),
          ),
          // ... (Background shapes remain same) ...
          Center(
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
        ],
      ),
    );
  }

  Widget _buildSimpleLogin(AuthState authState) {
    final isGuest = ref.watch(isGuestModeProvider);

    return _buildGlassCard(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isGuest ? Colors.orange.shade50 : Colors.teal.shade50, shape: BoxShape.circle),
          child: Icon(Icons.spa, color: isGuest ? Colors.orange : Color(0xFF00BFA5), size: 40),
        ),
        const SizedBox(height: 24),
        Text(isGuest ? "Guest Login" : "NutriCare Wellness", textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text(isGuest ? "Explore features in demo mode" : "Your Journey to Health Starts Here", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 40),

        _buildTextField(controller: _loginIdController, label: "Mobile Number", icon: Icons.phone_android),
        const SizedBox(height: 16),
        _buildTextField(controller: _loginPasswordController, label: "Password", icon: Icons.lock_outline, isPassword: true),

        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => _currentPage = AuthPage.forgotPassword), child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)))),
        const SizedBox(height: 24),

        _buildPrimaryButton("Log In", authState.isLoading, _login),

        const SizedBox(height: 30),
        const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("OR", style: TextStyle(color: Colors.grey, fontSize: 12))), Expanded(child: Divider())]),
        const SizedBox(height: 30),

        OutlinedButton(
          onPressed: () { _clearControllers(); setState(() => _currentPage = AuthPage.registerGateway); },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Color(0xFF00BFA5), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text("Create Account / Activate", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
        ),

        if (kEnableGuestMode && !isGuest) ...[
          const SizedBox(height: 16),
          TextButton(onPressed: _handleGuestDemo, child: const Text("Try Demo Mode", style: TextStyle(color: Colors.grey))),
        ],
        if (isGuest) ...[
          const SizedBox(height: 16),
          TextButton(onPressed: _switchToLiveAndLogin, child: const Text("Back to Live Login", style: TextStyle(color: Colors.indigo))),
        ]
      ],
    );
  }

  Widget _buildRegisterGateway() {
    return _buildGlassCard(
      children: [
        _buildBackBtn(() => setState(() => _currentPage = AuthPage.login)),
        const Text("Get Started", textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 40),

        _buildOptionTile(
            title: "I have a Patient ID",
            subtitle: "My Dietitian invited me.",
            icon: Icons.verified_user,
            color: Colors.indigo,
            onTap: () {
              // Force Live Mode Logic
              ref.read(isGuestModeProvider.notifier).state = false;
              setState(() => _currentPage = AuthPage.registerVerify);
            }
        ),
        const SizedBox(height: 16),
        _buildOptionTile(
            title: "I'm a New User",
            subtitle: "I want to explore the app.",
            icon: Icons.person_add_alt_1,
            color: Colors.teal,
            onTap: () async {
              // 🎯 Switch to Guest Mode Logic
              ref.read(isGuestModeProvider.notifier).state = true;
              await ref.read(firebaseAppProvider.future);
              setState(() => _currentPage = AuthPage.signUp);
            }
        ),
      ],
    );
  }
  Widget _buildRegisterVerify(AuthState authState) {
    return _buildGlassCard(
      children: [
        _buildBackBtn(() => setState(() => _currentPage = AuthPage.registerGateway)),
        const Text("Activate Account", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Verify your identity to proceed.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 30),
        _buildTextField(controller: _regPatientIdController, label: "Patient ID (e.g. PAT-123)", icon: Icons.badge),
        const SizedBox(height: 16),
        _buildTextField(controller: _regMobileController, label: "Registered Mobile", icon: Icons.phone),
        const SizedBox(height: 24),
        _buildPrimaryButton("Verify Identity", authState.isLoading, _validateRegistration),
      ],
    );
  }
  Widget _buildSignUp(AuthState authState) {
    return _buildGlassCard(
      children: [
        _buildBackBtn(() => setState(() => _currentPage = AuthPage.registerGateway)),
        const Text("Create Account", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        _buildTextField(controller: _regNameController, label: "Full Name", icon: Icons.person),
        const SizedBox(height: 16),
        _buildTextField(controller: _regMobileController, label: "Mobile Number", icon: Icons.phone),
        const SizedBox(height: 16),
        _buildTextField(controller: _regPasswordController, label: "Create Password", icon: Icons.lock, isPassword: true),
        const SizedBox(height: 24),
        _buildPrimaryButton("Sign Up", authState.isLoading, _handleNewUserSignUp),
      ],
    );
  }

  // ... (Rest of the build methods _buildRegisterVerify, _buildSignUp remain same, just keep using the new controllers) ...
  // Included in full code above for brevity, ensure _buildGlassCard and helpers are present.

  // (Helpers from previous version should be here)
  Widget _buildGlassCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    return TextField(
      controller: controller, obscureText: isPassword,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.teal.shade300),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        filled: true, fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, bool isLoading, VoidCallback onPressed) {
    final isGuest = ref.watch(isGuestModeProvider);
    final color = isGuest ? Colors.orange : const Color(0xFF00BFA5);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildOptionTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildBackBtn(VoidCallback onTap) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: onTap),
      ),
    );
  }

  Widget _buildRegisterPassword(AuthState s) => _buildGlassCard(children: [
    _buildBackBtn(() => setState(() => _currentPage = AuthPage.registerVerify)),
    const Text("Set Password", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 30),
    _buildTextField(controller: _regPasswordController, label: "New Password", icon: Icons.lock, isPassword: true),
    const SizedBox(height: 16),
    _buildTextField(controller: _regConfirmPasswordController, label: "Confirm Password", icon: Icons.lock, isPassword: true),
    const SizedBox(height: 24),
    _buildPrimaryButton("Complete Activation", s.isLoading, _completeActivation)
  ]);

  Widget _buildForgotPassword(AuthState s) => _buildGlassCard(children: [
    _buildBackBtn(() => setState(() => _currentPage = AuthPage.login)),
    const Text("Reset Password", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 30),
    _buildTextField(controller: _loginIdController, label: "Registered Mobile", icon: Icons.phone_android),
    const SizedBox(height: 24),
    _buildPrimaryButton("Send Reset Link", s.isLoading, () async {
      try {
        final service = ref.read(clientServiceProvider);
        await service.clientForgotPassword(_loginIdController.text.trim());
        _showMessage("Reset link sent to email (if registered).", isError: false);
      } catch(e) {
        _showMessage(e.toString(), isError: true);
      }
    })
  ]);
}