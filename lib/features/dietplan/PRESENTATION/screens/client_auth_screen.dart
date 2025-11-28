import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/core/app_theme.dart';
import 'package:nutricare_connect/core/utils/database_provider.dart';
import 'package:nutricare_connect/services/client_service.dart';
import '../providers/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/client_diet_plan_model.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/reminder_config_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui'; // For ImageFilter

enum AuthPage { login, registerGateway, registerVerify, signUp, registerPassword, forgotPassword }

class ClientAuthScreen extends ConsumerStatefulWidget {
  const ClientAuthScreen({super.key});

  @override
  ConsumerState<ClientAuthScreen> createState() => _ClientAuthScreenState();
}

class _ClientAuthScreenState extends ConsumerState<ClientAuthScreen> with SingleTickerProviderStateMixin {
  static const bool kEnableGuestMode = false;
  AuthPage _currentPage = AuthPage.login;

  // Controllers
  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _regPatientIdController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regNameController = TextEditingController();

  ClientModel? _validatedClient;

  // Animation
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

  // ... (KEEP ALL YOUR EXISTING LOGIC METHODS: _login, _validateRegistration, _completeActivation, _handleNewUserSignUp, _switchToLiveMode, _handleGuestDemo, _showMessage, _clearControllers) ...

  // ⚡ PASTE LOGIC METHODS HERE (omitted for brevity, logic remains unchanged)
  Future<void> _login() async {
    final loginId = _loginIdController.text.trim();
    final password = _loginPasswordController.text.trim();
    if (loginId.isEmpty || password.isEmpty) {
      _showMessage('Please enter ID and Password.', isError: true);
      return;
    }
    try {
      if (ref.read(isGuestModeProvider)) await _switchToLiveMode();
      await ref.read(authNotifierProvider.notifier).signIn(loginId, password);
    } catch (e) {
      _showMessage('Login failed: ${e.toString().split(':').last.trim()}', isError: true);
    }
  }

  Future<void> _validateRegistration() async {
    final patientId = _regPatientIdController.text.trim();
    final mobile = _regMobileController.text.trim();
    if (patientId.isEmpty || mobile.isEmpty) { _showMessage("Please enter both Patient ID and Mobile.", isError: true); return; }
    if (ref.read(isGuestModeProvider)) await _switchToLiveMode();
    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);
    try {
      final client = await service.getClientByPatientIdAndMobile(patientId, mobile);
      if (client != null) {
        if (client.id.isEmpty) { _showMessage("Error: System returned a client without an ID.", isError: true); return; }
        setState(() { _validatedClient = client; _currentPage = AuthPage.registerPassword; });
        _showMessage('Identity Verified! Set your password.', isError: false);
      } else { _showMessage('Invalid Patient ID or Mobile Number.', isError: true); }
    } catch (e) { _showMessage('Verification Error: ${e.toString()}', isError: true); }
    finally { ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false); }
  }

  Future<void> _completeActivation() async {
    final password = _regPasswordController.text.trim();
    final confirm = _regConfirmPasswordController.text.trim();
    if (password != confirm) { _showMessage('Passwords do not match.', isError: true); return; }
    if (password.length < 6) { _showMessage('Password too short.', isError: true); return; }
    if (ref.read(isGuestModeProvider)) await _switchToLiveMode();
    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);
    try {
      await service.registerClientCredentials(_validatedClient!.id, _validatedClient!.mobile, password);
      await ref.read(authNotifierProvider.notifier).signIn(_validatedClient!.mobile, password);
    } catch (e) { _showMessage('Activation failed: $e', isError: true); }
    finally { ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false); }
  }

  Future<void> _handleNewUserSignUp() async {
    final name = _regNameController.text.trim();
    final mobile = _regMobileController.text.trim();
    final pass = _regPasswordController.text.trim();
    if (name.isEmpty || mobile.isEmpty || pass.isEmpty) { _showMessage("All fields are required.", isError: true); return; }
    if (mobile.length < 10) { _showMessage("Invalid mobile number.", isError: true); return; }
    if (ref.read(isGuestModeProvider)) await _switchToLiveMode();
    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);
    try {
      await service.registerNewUser(name: name, mobile: mobile, password: pass);
      await ref.read(authNotifierProvider.notifier).signIn(mobile, pass);
      _showMessage("Welcome, $name!", isError: false);
    } catch (e) { _showMessage(e.toString().replaceAll("Exception:", "").trim(), isError: true); }
    finally { if(mounted) ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false); }
  }

  Future<void> _switchToLiveMode() async {
    ref.read(isGuestModeProvider.notifier).state = false;
    await ref.read(firebaseAppProvider.future);
    ref.refresh(clientServiceProvider);
  }

  Future<void> _handleGuestDemo() async {
    // ... (Keep existing logic)
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.teal));
  }

  void _clearControllers() {
    _regPatientIdController.clear(); _regMobileController.clear(); _regPasswordController.clear(); _regConfirmPasswordController.clear(); _regNameController.clear();
  }

  // =================================================================
  // 🎨 PREMIUM UI
  // =================================================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
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
          // 1. BACKGROUND (Gradient + Blobs)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE0F2F1), Color(0xFFF8F9FE)], // Mint to White
              ),
            ),
          ),
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.teal.withOpacity(0.1)),
            ),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.1)),
            ),
          ),

          // 2. CONTENT (Glass Card)
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
    return _buildGlassCard(
      children: [
        // Logo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.spa, color: Color(0xFF00BFA5), size: 40),
        ),
        const SizedBox(height: 24),
        const Text("NutriCare Wellness", textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text("Your Journey to Health Starts Here", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 40),

        _buildTextField(controller: _loginIdController, label: "Mobile Number", icon: Icons.phone_android),
        const SizedBox(height: 16),
        _buildTextField(controller: _loginPasswordController, label: "Password", icon: Icons.lock_outline, isPassword: true),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => _currentPage = AuthPage.forgotPassword),
            child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
        ),

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

        if (kEnableGuestMode) ...[
          const SizedBox(height: 16),
          TextButton(onPressed: _handleGuestDemo, child: const Text("Try Demo Mode", style: TextStyle(color: Colors.grey))),
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
            onTap: () => setState(() => _currentPage = AuthPage.registerVerify)
        ),
        const SizedBox(height: 16),
        _buildOptionTile(
            title: "I'm a New User",
            subtitle: "I want to explore the app.",
            icon: Icons.person_add_alt_1,
            color: Colors.teal,
            onTap: () => setState(() => _currentPage = AuthPage.signUp)
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

  // ... (Include registerPassword and forgotPassword using _buildGlassCard pattern)

  // --- PREMIUM HELPERS ---

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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF00BFA5).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white,
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

  // Placeholders for missing methods
  Widget _buildRegisterPassword(AuthState s) => _buildGlassCard(children: [Text("Password"), _buildPrimaryButton("Save", s.isLoading, _completeActivation)]);
  Widget _buildForgotPassword(AuthState s) => _buildGlassCard(children: [Text("Reset"), _buildPrimaryButton("Send", s.isLoading, _validateRegistration)]);
}