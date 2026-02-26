import 'dart:ui';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/core/utils/database_provider.dart';
import 'package:nutricare_connect/new/service/client_service.dart';
import 'package:nutricare_connect/new/dashboard/client_dashboard_main_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/new/profile/privacy_policy_screen.dart';
import '../../features/auth/auth_provider.dart';

const bool kEnableGuestMode = true;
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

  bool _acceptedTerms = false;
  late TapGestureRecognizer _privacyTapRecognizer;

  // 🎯 Locked Dark Palette to match Splash & Onboarding
  final Color bgDark = const Color(0xFF0B0F19);
  final Color cardDark = const Color(0xFF121826);
  final Color neonGreen = const Color(0xFF00E676);
  final Color neonCyan = const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    _privacyTapRecognizer = TapGestureRecognizer()..onTap = () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
    };
  }

  @override
  void dispose() {
    _loginIdController.dispose(); _loginPinController.dispose();
    _regPatientIdController.dispose(); _regMobileController.dispose();
    _regActivationCodeController.dispose(); _regPinController.dispose();
    _regConfirmPinController.dispose(); _regNameController.dispose();
    _animController.dispose(); _privacyTapRecognizer.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 🔐 LOGIC METHODS (Unchanged)
  // ===========================================================================

  Future<void> _login() async {
    final loginId = _loginIdController.text.trim();
    final pin = _loginPinController.text.trim();
    if (loginId.isEmpty || pin.isEmpty) { _showMessage('Required fields missing.', isError: true); return; }
    HapticFeedback.lightImpact();

    try {
      await ref.read(authNotifierProvider.notifier).signIn(loginId, pin + kPinSalt);
      final clientProfile = ref.read(authNotifierProvider).clientProfile;

      if (clientProfile != null && mounted) {
        ref.read(globalUserProvider.notifier).setUser(clientProfile);
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => ClientDashboardScreen(client: clientProfile)), (route) => false);
      }
    } catch (e) {
      if (mounted) _showMessage('Authentication failed. Check your PIN.', isError: true);
    }
  }

  Future<void> _completeActivation() async {
    final pin = _regPinController.text.trim();
    final confirm = _regConfirmPinController.text.trim();
    if (pin != confirm) { _showMessage('PINs do not match.', isError: true); return; }
    if (pin.length != 4) { _showMessage('PIN must be exactly 4 digits.', isError: true); return; }

    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);
    try {
      final service = ref.read(clientServiceProvider);
      final securePassword = pin + kPinSalt;
      await service.activateClientAccess(client: _validatedClient!, pin: securePassword);
      if (mounted) {
        await ref.read(authNotifierProvider.notifier).signIn(_validatedClient!.mobile, securePassword);
        ref.invalidate(clientProfileFutureProvider);
      }
    } catch (e) {
      _showMessage('Activation failed: $e', isError: true);
      if (mounted) ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }

  Future<void> _validateRegistration() async {
    if (!_acceptedTerms) { _showMessage("Acceptance of Privacy Policy required.", isError: true); return; }
    final patientId = _regPatientIdController.text.trim();
    final mobile = _regMobileController.text.trim();
    final code = _regActivationCodeController.text.trim();

    if (patientId.isEmpty || mobile.isEmpty || code.isEmpty) { _showMessage("All fields required.", isError: true); return; }
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true, error: null);

    try {
      final query = await FirebaseFirestore.instance.collection('clients').where('patientId', isEqualTo: patientId).limit(1).get();
      if (query.docs.isEmpty) throw "Patient ID not found.";

      final doc = query.docs.first;
      final data = doc.data();

      String cleanInput = mobile.replaceAll(RegExp(r'\D'), '');
      String cleanDb = (data['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      if (cleanInput.length < 10) throw "Invalid mobile format.";
      if (!cleanDb.endsWith(cleanInput)) throw "Mobile number mismatch.";

      String serverToken = (data['loginToken'] ?? '').toString().trim();
      if (serverToken.isEmpty) throw "Activation Code not generated.";
      if (serverToken != code.trim()) throw "Invalid Activation Code.";

      ref.read(isGuestModeProvider.notifier).state = false;
      await ref.read(firebaseAppProvider.future);

      if (mounted) {
        setState(() { _validatedClient = ClientModel.fromFirestore(doc); _currentPage = AuthPage.registerPassword; });
        _showMessage('Verification successful. Secure your account.', isError: false);
      }
    } catch (e) {
      _showMessage(e.toString().replaceAll("Exception:", "").trim(), isError: true);
    } finally {
      if (mounted) ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }

  Future<void> _handleNewUserSignUp() async {
    if (!_acceptedTerms) { _showMessage("Acceptance of Privacy Policy required.", isError: true); return; }
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
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: isError ? Colors.white : bgDark, fontWeight: FontWeight.bold)),
      backgroundColor: isError ? Colors.redAccent : neonGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _clearControllers() {
    _regPatientIdController.clear(); _regMobileController.clear(); _regActivationCodeController.clear();
    _regPinController.clear(); _regConfirmPinController.clear(); _regNameController.clear();
    setState(() => _acceptedTerms = false);
  }

  // ===========================================================================
  // 🎨 UI RENDERING (HI-TECH PREMIUM)
  // ===========================================================================

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
      case AuthPage.forgotPassword: content = _buildForgotPassword(); break;
      default: content = _buildLoginScreen(authState);
    }

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 🎯 Subtle Background Glow
          Positioned(
            top: -150, right: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(shape: BoxShape.circle, color: neonGreen.withOpacity(0.08), boxShadow: [BoxShadow(color: neonGreen.withOpacity(0.05), blurRadius: 100)]),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_currentPage != AuthPage.login) _buildBackBtn(() => setState(() => _currentPage = AuthPage.login)),
                        _buildBrandHeader(),
                        const SizedBox(height: 40),
                        content,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 🎯 The Core Brand Component ---
  Widget _buildBrandHeader() {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2.0),
            children: [
              const TextSpan(text: "NUTRI", style: TextStyle(color: Colors.white)),
              TextSpan(text: "CARE", style: TextStyle(color: neonGreen, shadows: [Shadow(color: neonGreen.withOpacity(0.5), blurRadius: 10)])),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text("WELLNESS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 6.0)),
      ],
    );
  }

  // --- SCREENS ---
  Widget _buildLoginScreen(AuthState s) {
    return Column(
      children: [
        _buildHiTechContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("SECURE LOGIN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2.0)),
              const SizedBox(height: 24),

              _buildModernTextField(controller: _loginIdController, label: "Mobile Number", icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),

              _buildModernTextField(controller: _loginPinController, label: "4-Digit PIN", icon: Icons.lock_rounded, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),

              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => setState(() => _currentPage = AuthPage.forgotPassword), child: Text("Forgot PIN?", style: TextStyle(color: neonGreen, fontSize: 13, fontWeight: FontWeight.bold)))
              ),
              const SizedBox(height: 8),

              _buildModernButton("AUTHENTICATE", s.isLoading, _login),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text("New patient or clinical referral?", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 8),
        TextButton(
            onPressed: () { _clearControllers(); setState(() => _currentPage = AuthPage.registerGateway); },
            child: Text("ACTIVATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white))
        ),
      ],
    );
  }

  Widget _buildGatewayScreen() {
    return Column(
      children: [
        const Text("INITIALIZATION", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2.0)),
        const SizedBox(height: 12),
        Text("Select your secure onboarding path.", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        const SizedBox(height: 32),
        _buildOptionCard(icon: Icons.vpn_key_rounded, title: "Activation Code", desc: "Provided by your clinical dietitian.", color: neonGreen, onTap: () { ref.read(isGuestModeProvider.notifier).state = false; setState(() => _currentPage = AuthPage.registerVerify); }),
        const SizedBox(height: 16),
        if (kEnableGuestMode) _buildOptionCard(icon: Icons.explore_rounded, title: "Guest Access", desc: "Explore the platform interface.", color: neonCyan, onTap: _handleGuestDemo),
      ],
    );
  }

  Widget _buildActivationScreen(AuthState s) {
    return _buildHiTechContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.shield_rounded, size: 40, color: neonGreen),
          const SizedBox(height: 16),
          const Text("VERIFY CREDENTIALS", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          const SizedBox(height: 30),

          _buildModernTextField(controller: _regPatientIdController, label: "Patient ID", icon: Icons.badge_rounded),
          const SizedBox(height: 16),
          _buildModernTextField(controller: _regMobileController, label: "Mobile Number", icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _buildModernTextField(controller: _regActivationCodeController, label: "6-Digit Auth Code", icon: Icons.key_rounded, keyboardType: TextInputType.number),

          const SizedBox(height: 24),
          _buildConsentCheckbox(),
          const SizedBox(height: 24),
          _buildModernButton("VERIFY IDENTITY", s.isLoading, _validateRegistration),
        ],
      ),
    );
  }

  Widget _buildPinSetScreen(AuthState s) {
    return _buildHiTechContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_clock_rounded, size: 40, color: neonCyan),
          const SizedBox(height: 16),
          const Text("SECURE ACCESS", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text("Set a local encryption PIN.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 30),

          _buildModernTextField(controller: _regPinController, label: "New PIN", icon: Icons.lock_rounded, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),
          const SizedBox(height: 16),
          _buildModernTextField(controller: _regConfirmPinController, label: "Confirm PIN", icon: Icons.lock_outline_rounded, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),

          const SizedBox(height: 24),
          _buildModernButton("FINALIZE & LOGIN", s.isLoading, _completeActivation),
        ],
      ),
    );
  }

  Widget _buildGuestSignUp(AuthState s) {
    return _buildHiTechContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("GUEST REGISTRATION", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          const SizedBox(height: 30),

          _buildModernTextField(controller: _regNameController, label: "Full Name", icon: Icons.person_rounded),
          const SizedBox(height: 16),
          _buildModernTextField(controller: _regMobileController, label: "Mobile Number", icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _buildModernTextField(controller: _regPinController, label: "Create PIN (4 Digits)", icon: Icons.lock_rounded, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),

          const SizedBox(height: 24),
          _buildConsentCheckbox(),
          const SizedBox(height: 24),
          _buildModernButton("INITIALIZE ACCOUNT", s.isLoading, _handleNewUserSignUp),
        ],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return _buildHiTechContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.help_center_rounded, size: 40, color: Colors.white),
          const SizedBox(height: 16),
          const Text("RESET PROTOCOL", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Text("To reset your secure PIN, you must re-verify your original clinical Activation Code.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, height: 1.5)),
          const SizedBox(height: 32),
          _buildModernButton("PROCEED TO VERIFICATION", false, () { setState(() => _currentPage = AuthPage.registerGateway); }),
        ],
      ),
    );
  }

  // --- REUSABLE HI-TECH WIDGETS ---

  Widget _buildConsentCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20, height: 20,
            child: Checkbox(
              value: _acceptedTerms, activeColor: neonGreen, checkColor: bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: BorderSide(color: Colors.grey.shade600),
              onChanged: (bool? value) => setState(() => _acceptedTerms = value ?? false),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.5),
                children: [
                  const TextSpan(text: "I accept the "),
                  TextSpan(text: "Privacy Policy", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline), recognizer: _privacyTapRecognizer),
                  const TextSpan(text: " and consent to the secure clinical processing of my health vitals."),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHiTechContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: child,
    );
  }

  Widget _buildModernTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    return TextField(
      controller: controller, obscureText: isPassword, keyboardType: keyboardType, maxLength: maxLength,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white, letterSpacing: isPassword ? 8 : 1),
      textAlign: isPassword ? TextAlign.center : TextAlign.start,
      cursorColor: neonGreen,
      decoration: InputDecoration(
        labelText: label, counterText: "",
        labelStyle: TextStyle(color: Colors.grey.shade600, letterSpacing: 0, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
        filled: true, fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: neonGreen.withOpacity(0.5), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      ),
    );
  }

  Widget _buildModernButton(String text, bool isLoading, VoidCallback onPressed) {
    return SizedBox(
      height: 56, width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: neonGreen, foregroundColor: bgDark,
            elevation: 10, shadowColor: neonGreen.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
        ),
        child: isLoading
            ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: bgDark, strokeWidth: 3))
            : Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      ),
    );
  }

  Widget _buildOptionCard({required IconData icon, required String title, required String desc, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(desc, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackBtn(VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0, left: 8.0),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}