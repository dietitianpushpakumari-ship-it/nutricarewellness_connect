import 'dart:ui';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_shift/core/utils/background_sync_service.dart';
import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/core/utils/database_provider.dart';
import 'package:pure_shift/new/service/client_service.dart';
import 'package:pure_shift/new/dashboard/client_dashboard_main_screen.dart';
import 'package:pure_shift/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:pure_shift/new/profile/privacy_policy_screen.dart';
import '../../features/auth/auth_provider.dart';
import 'package:pure_shift/layout_utils.dart';

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

  bool _isProcessing = false;
  bool _acceptedTerms = false;
  bool _isResetFlow = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TapGestureRecognizer _privacyTapRecognizer;

  final Color bgLight = const Color(0xFFF8FAFC);
  final Color cardLight = const Color(0xFFFFFFFF);
  final Color textDark = const Color(0xFF0F172A);
  final Color textMuted = const Color(0xFF64748B);
  final Color clinicalEmerald = const Color(0xFF059669);
  final Color fieldBg = const Color(0xFFF1F5F9);

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

  void _clearControllers() {
    _loginIdController.clear(); _loginPinController.clear();
    _regPatientIdController.clear(); _regMobileController.clear();
    _regActivationCodeController.clear(); _regPinController.clear();
    _regConfirmPinController.clear(); _regNameController.clear();
    setState(() {
      _acceptedTerms = false;
      _isProcessing = false;
    });
  }

  // ===========================================================================
  // 🔐 LOGIC METHODS
  // ===========================================================================

  Future<void> _login() async {
    final rawLoginId = _loginIdController.text.trim();
    final pin = _loginPinController.text.trim();
    if (rawLoginId.isEmpty || pin.isEmpty) { _showMessage('Required fields missing.', isError: true); return; }
    HapticFeedback.lightImpact();
    final String cleanNum = rawLoginId.replaceAll(RegExp(r'\D'), '');
    setState(() => _isProcessing = true);
    try {
      final profiles = await ref.read(authNotifierProvider.notifier).signIn(cleanNum, pin + kPinSalt);
      if (!mounted) return;

      if (profiles.isEmpty) {
        _showMessage("Account verified, but profile document is missing.", isError: true);
        return;
      }

      if (profiles.length > 1) {
        _showProfileSelectionSheet(profiles);
      } else if (profiles.length == 1) {
        ref.read(globalUserProvider.notifier).setUser(profiles.first);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => ClientDashboardScreen(client: profiles.first, showWelcomeSheet: true)), (route) => false);
      }
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceAll("Exception:", "").trim(), isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _completeActivation() async {
    final pin = _regPinController.text.trim();
    final confirm = _regConfirmPinController.text.trim();
    if (pin != confirm) { _showMessage('PINs do not match.', isError: true); return; }
    if (pin.length != 4) { _showMessage('PIN must be exactly 4 digits.', isError: true); return; }
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(clientServiceProvider);
      final securePassword = pin + kPinSalt;
      final mobile = _regMobileController.text.replaceAll(RegExp(r'\D'), '');

      await service.activateClientAccess(
        patientId: _regPatientIdController.text.trim(),
        mobile: mobile,
        activationCode: _regActivationCodeController.text.trim(),
        pin: securePassword,
        isResetting: _isResetFlow,
      );

      if (mounted) {
        final profiles = await ref.read(authNotifierProvider.notifier).signIn(mobile, securePassword);
        ref.invalidate(clientProfileFutureProvider);

        if (profiles.isNotEmpty) {
          scheduleClinicalSync(profiles.first.patientId!);
          ref.read(globalUserProvider.notifier).setUser(profiles.first);
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => ClientDashboardScreen(client: profiles.first, showWelcomeSheet: true)), (route) => false);
        }
      }
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceAll("Exception:", "").trim(), isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleNewUserSignUp() async {
    if (!_acceptedTerms) { _showMessage("Acceptance of Privacy Policy required.", isError: true); return; }
    final name = _regNameController.text.trim();
    final mobile = _regMobileController.text.replaceAll(RegExp(r'\D'), '');
    final pin = _regPinController.text.trim();
    if (name.isEmpty || mobile.isEmpty || pin.isEmpty) { _showMessage("All fields required.", isError: true); return; }
    if (pin.length != 4) { _showMessage("PIN must be 4 digits.", isError: true); return; }
    setState(() => _isProcessing = true);
    ref.read(isGuestModeProvider.notifier).state = true;
    await ref.read(firebaseAppProvider.future);
    final service = ref.read(clientServiceProvider);
    try {
      await service.registerNewUser(name: name, mobile: mobile, password: pin + kPinSalt);
      final profiles = await ref.read(authNotifierProvider.notifier).signIn(mobile, pin + kPinSalt);

      if (mounted && profiles.isNotEmpty) {
        ref.read(globalUserProvider.notifier).setUser(profiles.first);
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => ClientDashboardScreen(client: profiles.first, showWelcomeSheet: true)), (route) => false);
      }
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceAll("Exception:", "").trim(), isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showProfileSelectionSheet(List<ClientModel> profiles) {
    showModalBottomSheet(
        context: context, backgroundColor: cardLight, isScrollControlled: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(context.scale(24)))),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(context.scale(24.0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: context.scale(40), height: context.scale(4), margin: EdgeInsets.only(bottom: context.scale(20)), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(context.scale(10)))),
                  Text("Select Profile", style: TextStyle(color: textDark, fontSize: context.scale(20), fontWeight: FontWeight.w800, letterSpacing: context.scale(1.5))),
                  SizedBox(height: context.scale(8)),
                  Text("Multiple patients found under this mobile number.", style: TextStyle(color: textMuted, fontSize: context.scale(13))),
                  SizedBox(height: context.scale(24)),
                  ...profiles.map((profile) => Padding(
                    padding: EdgeInsets.only(bottom: context.scale(12.0)),
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await ref.read(authNotifierProvider.notifier).selectProfile(profile);
                        ref.read(globalUserProvider.notifier).setUser(profile);
                      },
                      borderRadius: BorderRadius.circular(context.scale(16)),
                      child: Container(
                        padding: EdgeInsets.all(context.scale(16)),
                        decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(context.scale(16)), border: Border.all(color: clinicalEmerald.withOpacity(0.2))),
                        child: Row(
                          children: [
                            CircleAvatar(radius: context.scale(24), backgroundColor: clinicalEmerald.withOpacity(0.1), child: Icon(Icons.person_rounded, color: clinicalEmerald, size: context.scale(28))),
                            SizedBox(width: context.scale(16)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(profile.name!, style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: context.scale(16))),
                                  SizedBox(height: context.scale(4)),
                                  Text("Patient ID: ${profile.patientId}", style: TextStyle(color: textMuted, fontSize: context.scale(12))),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: textMuted, size: context.scale(24)),
                          ],
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          );
        }
    );
  }

  Future<void> _validateRegistration() async {
    if (!_acceptedTerms) { _showMessage("Acceptance of Privacy Policy required.", isError: true); return; }
    if (_regPatientIdController.text.trim().isEmpty || _regMobileController.text.trim().isEmpty || _regActivationCodeController.text.trim().isEmpty) { _showMessage("All fields required.", isError: true); return; }
    ref.read(isGuestModeProvider.notifier).state = false;
    setState(() => _currentPage = AuthPage.registerPassword);
  }

  Future<void> _handleGuestDemo() async {
    ref.read(isGuestModeProvider.notifier).state = true;
    await ref.read(firebaseAppProvider.future);
    setState(() => _currentPage = AuthPage.signUp);
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: context.scale(14))),
      backgroundColor: isError ? Colors.redAccent : clinicalEmerald, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(10))),
    ));
  }

  // ===========================================================================
  // 🎨 MAIN BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_currentPage) {
      case AuthPage.login: content = _buildLoginScreen(); break;
      case AuthPage.registerGateway: content = _buildGatewayScreen(); break;
      case AuthPage.registerVerify: content = _buildActivationScreen(); break;
      case AuthPage.signUp: content = _buildGuestSignUp(); break;
      case AuthPage.registerPassword: content = _buildPinSetScreen(); break;
      case AuthPage.forgotPassword: content = _buildForgotPassword(); break;
      default: content = _buildLoginScreen();
    }

    return Scaffold(
      backgroundColor: bgLight,
      body: Stack(
        children: [
          Positioned(
            top: context.scale(-150), right: context.scale(-100),
            child: Container(
              width: context.scale(400), height: context.scale(400),
              decoration: BoxDecoration(shape: BoxShape.circle, color: clinicalEmerald.withOpacity(0.04), boxShadow: [BoxShadow(color: clinicalEmerald.withOpacity(0.04), blurRadius: context.scale(100))]),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(context.scale(24), context.scale(16), context.scale(24), MediaQuery.of(context).viewInsets.bottom + context.scale(16)),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_currentPage != AuthPage.login) _buildBackBtn(() { _clearControllers(); setState(() { _currentPage = AuthPage.login; _isResetFlow = false; }); }),
                        _buildBrandHeader(),
                        SizedBox(height: context.scale(40)),
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

  // ===========================================================================
  // 💎 CLINICAL LIGHT THEME SCREENS
  // ===========================================================================

  Widget _buildBrandHeader() {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: context.scale(36), fontWeight: FontWeight.w800, letterSpacing: context.scale(2.0), fontFamily: 'Space Grotesk'),
              children: [
                TextSpan(text: "NUTRI", style: TextStyle(color: textDark)),
                TextSpan(text: "CARE", style: TextStyle(color: clinicalEmerald)),
              ],
            ),
          ),
        ),
        SizedBox(height: context.scale(6)),
        Text("CLINICAL WELLNESS", style: TextStyle(fontSize: context.scale(10), fontWeight: FontWeight.w800, color: textMuted, letterSpacing: context.scale(6.0))),
      ],
    );
  }

  Widget _buildLoginScreen() {
    return Column(
      children: [
        _buildLuxuryContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text("SECURE PATIENT PORTAL", style: TextStyle(fontSize: context.scale(12), fontWeight: FontWeight.w800, color: clinicalEmerald, letterSpacing: context.scale(2.0))),
              ),
              SizedBox(height: context.scale(24)),
              _buildModernTextField(controller: _loginIdController, label: "MOBILE NUMBER", icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
              SizedBox(height: context.scale(16)),
              _buildModernTextField(controller: _loginPinController, label: "4-DIGIT PIN", icon: Icons.lock_rounded, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () { _clearControllers(); setState(() { _isResetFlow = true; _currentPage = AuthPage.forgotPassword; }); }, child: Text("Forgot PIN?", style: TextStyle(color: clinicalEmerald, fontSize: context.scale(13), fontWeight: FontWeight.bold)))
              ),
              SizedBox(height: context.scale(12)),
              // 🚀 Shortened Button Text
              _buildModernButton("LOGIN", _isProcessing, _login),
            ],
          ),
        ),
        SizedBox(height: context.scale(32)),
        Text("New patient or clinical referral?", style: TextStyle(color: textMuted, fontSize: context.scale(13), fontWeight: FontWeight.w500)),
        SizedBox(height: context.scale(8)),
        TextButton(onPressed: () { _clearControllers(); setState(() { _isResetFlow = false; _currentPage = AuthPage.registerGateway; }); }, child: Text("ACTIVATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: context.scale(1.5), color: textDark))),
      ],
    );
  }

  Widget _buildGatewayScreen() {
    return _buildLuxuryContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text("INITIALIZATION", style: TextStyle(fontSize: context.scale(14), fontWeight: FontWeight.w800, color: clinicalEmerald, letterSpacing: context.scale(2.0))),
          ),
          SizedBox(height: context.scale(12)),
          Text("Select your secure onboarding path.", style: TextStyle(color: textMuted, fontSize: context.scale(13), height: 1.5)),
          SizedBox(height: context.scale(32)),
          _buildOptionCard(icon: Icons.vpn_key_rounded, title: "Activation Code", desc: "Provided by your clinical dietitian.", color: clinicalEmerald, onTap: () { ref.read(isGuestModeProvider.notifier).state = false; setState(() => _currentPage = AuthPage.registerVerify); }),
          SizedBox(height: context.scale(16)),
          if (kEnableGuestMode) _buildOptionCard(icon: Icons.explore_rounded, title: "Guest Access", desc: "Explore the platform interface.", color: textDark, onTap: _handleGuestDemo),
        ],
      ),
    );
  }

  Widget _buildActivationScreen() {
    return _buildLuxuryContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.shield_rounded, size: context.scale(40), color: clinicalEmerald),
          SizedBox(height: context.scale(16)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_isResetFlow ? "VERIFY IDENTITY FOR RESET" : "VERIFY CREDENTIALS", textAlign: TextAlign.center, style: TextStyle(fontSize: context.scale(14), fontWeight: FontWeight.w800, color: textDark, letterSpacing: context.scale(1.5))),
          ),
          SizedBox(height: context.scale(30)),
          _buildModernTextField(controller: _regPatientIdController, label: "PATIENT ID", icon: Icons.badge_rounded),
          SizedBox(height: context.scale(16)),
          _buildModernTextField(controller: _regMobileController, label: "MOBILE NUMBER", icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
          SizedBox(height: context.scale(16)),
          _buildModernTextField(controller: _regActivationCodeController, label: "6-DIGIT AUTH CODE", icon: Icons.key_rounded, keyboardType: TextInputType.number),
          SizedBox(height: context.scale(24)),
          _buildConsentCheckbox(),
          SizedBox(height: context.scale(24)),
          // 🚀 Shortened Button Text
          _buildModernButton("VERIFY", _isProcessing, _validateRegistration),
        ],
      ),
    );
  }

  Widget _buildPinSetScreen() {
    return _buildLuxuryContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_clock_rounded, size: context.scale(40), color: textDark),
          SizedBox(height: context.scale(16)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_isResetFlow ? "RESET SECURE ACCESS" : "SECURE ACCESS", textAlign: TextAlign.center, style: TextStyle(fontSize: context.scale(14), fontWeight: FontWeight.w800, color: textDark, letterSpacing: context.scale(1.5))),
          ),
          SizedBox(height: context.scale(8)),
          Text("Set a local encryption PIN.", textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: context.scale(12))),
          SizedBox(height: context.scale(30)),
          _buildModernTextField(controller: _regPinController, label: "NEW PIN", icon: Icons.lock_rounded, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),
          SizedBox(height: context.scale(16)),
          _buildModernTextField(controller: _regConfirmPinController, label: "CONFIRM PIN", icon: Icons.lock_outline_rounded, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),
          SizedBox(height: context.scale(24)),
          // 🚀 Shortened Button Text
          _buildModernButton(_isResetFlow ? "UPDATE PIN" : "SET PIN", _isProcessing, _completeActivation),
        ],
      ),
    );
  }

  Widget _buildGuestSignUp() {
    return _buildLuxuryContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("GUEST REGISTRATION", textAlign: TextAlign.center, style: TextStyle(fontSize: context.scale(14), fontWeight: FontWeight.w800, color: textDark, letterSpacing: context.scale(1.5))),
          ),
          SizedBox(height: context.scale(30)),
          _buildModernTextField(controller: _regNameController, label: "FULL NAME", icon: Icons.person_rounded),
          SizedBox(height: context.scale(16)),
          _buildModernTextField(controller: _regMobileController, label: "MOBILE NUMBER", icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
          SizedBox(height: context.scale(16)),
          _buildModernTextField(controller: _regPinController, label: "CREATE PIN", icon: Icons.lock_rounded, isPassword: true, keyboardType: TextInputType.number, maxLength: 4),
          SizedBox(height: context.scale(24)),
          _buildConsentCheckbox(),
          SizedBox(height: context.scale(24)),
          // 🚀 Shortened Button Text
          _buildModernButton("CREATE ACCOUNT", _isProcessing, _handleNewUserSignUp),
        ],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return _buildLuxuryContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.help_center_rounded, size: context.scale(40), color: textDark),
          SizedBox(height: context.scale(16)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("RESET PROTOCOL", textAlign: TextAlign.center, style: TextStyle(fontSize: context.scale(14), fontWeight: FontWeight.w800, color: textDark, letterSpacing: context.scale(1.5))),
          ),
          SizedBox(height: context.scale(16)),
          Text("To reset your secure PIN, you must re-verify your original clinical Activation Code.", textAlign: TextAlign.center, style: TextStyle(color: textMuted, height: 1.5, fontSize: context.scale(12))),
          SizedBox(height: context.scale(32)),
          // 🚀 Shortened Button Text
          _buildModernButton("VERIFY CODE", false, () { _clearControllers(); setState(() => _currentPage = AuthPage.registerVerify); }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 💎 LIGHT THEME WIDGETS
  // ===========================================================================

  Widget _buildLuxuryContainer({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(context.scale(28)),
      decoration: BoxDecoration(
        color: cardLight,
        borderRadius: BorderRadius.circular(context.scale(28)),
        border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: context.scale(40), offset: Offset(0, context.scale(20))),
        ],
      ),
      child: child,
    );
  }

  Widget _buildModernTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.scale(4), bottom: context.scale(8)),
          // 🚀 Fixed Hardcoded Letter Spacing
          child: Text(label.toUpperCase(), style: TextStyle(fontSize: context.scale(10), fontWeight: FontWeight.w800, color: textMuted, letterSpacing: context.scale(1.5))),
        ),
        TextField(
          controller: controller, obscureText: isPassword, keyboardType: keyboardType, maxLength: maxLength, cursorColor: clinicalEmerald,
          // 🚀 Fixed Hardcoded Letter Spacing
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.scale(16), color: textDark, letterSpacing: isPassword ? context.scale(6) : context.scale(0.5)),
          decoration: InputDecoration(
            counterText: "", prefixIcon: Icon(icon, color: textMuted.withOpacity(0.7), size: context.scale(20)),
            filled: true, fillColor: fieldBg,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(context.scale(16)), borderSide: const BorderSide(color: Colors.transparent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(context.scale(16)), borderSide: BorderSide(color: clinicalEmerald.withOpacity(0.5), width: context.scale(1.5))),
            contentPadding: EdgeInsets.symmetric(vertical: context.scale(18), horizontal: context.scale(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildModernButton(String text, bool isLoading, VoidCallback onPressed) {
    return Container(
      height: context.scale(56), width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [clinicalEmerald, const Color(0xFF047857)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(context.scale(16)),
        boxShadow: [BoxShadow(color: clinicalEmerald.withOpacity(0.25), blurRadius: context.scale(15), offset: Offset(0, context.scale(8)))],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(16)))),
        child: isLoading
            ? SizedBox(width: context.scale(24), height: context.scale(24), child: CircularProgressIndicator(color: Colors.white, strokeWidth: context.scale(3)))
            : Text(text, style: TextStyle(fontSize: context.scale(14), fontWeight: FontWeight.w800, letterSpacing: context.scale(2.0), color: Colors.white)),
      ),
    );
  }

  Widget _buildOptionCard({required IconData icon, required String title, required String desc, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(context.scale(20)),
        child: Container(
          padding: EdgeInsets.all(context.scale(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(context.scale(20)),
            border: Border.all(color: Colors.grey.shade200, width: context.scale(1.5)),
            // 🚀 Fixed Hardcoded Shadow Values
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: context.scale(10), offset: Offset(0, context.scale(4)))],
          ),
          child: Row(
            children: [
              Container(padding: EdgeInsets.all(context.scale(12)), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: context.scale(24))),
              SizedBox(width: context.scale(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.scale(16), color: textDark)),
                    SizedBox(height: context.scale(4)),
                    Text(desc, style: TextStyle(color: textMuted, fontSize: context.scale(13))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: context.scale(14), color: textMuted.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentCheckbox() {
    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(context.scale(16)), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: context.scale(20), height: context.scale(20),
            child: Checkbox(
              value: _acceptedTerms, activeColor: clinicalEmerald, checkColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.scale(4))),
              side: BorderSide(color: Colors.grey.shade400),
              onChanged: (bool? value) => setState(() => _acceptedTerms = value ?? false),
            ),
          ),
          SizedBox(width: context.scale(16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: context.scale(12), color: textMuted, height: 1.5), // Line height is standard multiplier, left as 1.5
                children: [
                  const TextSpan(text: "I accept the "),
                  TextSpan(text: "Privacy Policy", style: TextStyle(color: clinicalEmerald, fontWeight: FontWeight.bold, decoration: TextDecoration.underline), recognizer: _privacyTapRecognizer),
                  const TextSpan(text: " and consent to the secure clinical processing of my health vitals."),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackBtn(VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: context.scale(24.0), left: context.scale(8.0)),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(context.scale(30)),
          child: Container(
            padding: EdgeInsets.all(context.scale(8)),
            // 🚀 Fixed Hardcoded Blur Radius
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: context.scale(10))]),
            child: Icon(Icons.arrow_back_rounded, size: context.scale(20), color: textDark),
          ),
        ),
      ),
    );
  }
}