// lib/features/auth/presentation/screens/client_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutricare_connect/services/client_service.dart';
import '../providers/auth_provider.dart';

// 識 ADDED OTP State
enum AuthPage { login, registerVerify, registerOtpClient, registerPassword, registerOtp, forgotPassword }

class ClientAuthScreen extends ConsumerStatefulWidget {
  const ClientAuthScreen({super.key});

  @override
  ConsumerState<ClientAuthScreen> createState() => _ClientAuthScreenState();
}

class _ClientAuthScreenState extends ConsumerState<ClientAuthScreen> {
  AuthPage _currentPage = AuthPage.login;
  String? _clientVerificationId;
  final _clientOtpCodeController = TextEditingController();

  // Login Controllers
  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Registration Controllers (Patient ID/Mobile verification for existing)
  final _regPatientIdController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  ClientModel? _validatedClient;

  // 識 NEW OTP Controllers & State
  final _otpMobileController = TextEditingController();
  final _otpCodeController = TextEditingController();
  String? _verificationId;
  bool _otpCodeSent = false;

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _regPatientIdController.dispose();
    _regMobileController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _otpMobileController.dispose();
    _otpCodeController.dispose();
    super.dispose();
  }

  // --- Auth Logic Handlers (Existing Client Flow) ---
  Future<void> _initiateSmsFlow(String mobile) async {
    // Set loading state again, as this is a new network call
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true, error: null);

    await ref.read(clientServiceProvider).initiateMobileOtpRegistration(
        mobileNumber: mobile,
        codeSentCallback: (verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _otpCodeSent = true;
            });
            _showMessage(context, 'Notification failed. Sending via SMS.', isError: false);
          }
        },
        verificationFailedCallback: (error) {
          if (mounted) {
            _showMessage(context, 'SMS sending failed: $error', isError: true);
          }
        });
  }

// --- MODIFIED HANDLER: New User Registration (PUSH First) ---
  Future<void> _initiateOtpFlow() async {
    String mobile = _otpMobileController.text.trim();

    // Auto-prepend +91 if only digits are entered
    if (RegExp(r'^[0-9]+$').hasMatch(mobile) && mobile.length >= 10) {
    }
    if (mobile.isEmpty || !mobile.startsWith('+') || mobile.length < 10) {
      if (mounted) {
        _showMessage(context, 'Mobile must be in E.164 format (+91XXXXXXXXXX).', isError: true);
      }
      return;
    }

    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true, error: null);

    // 🎯 NEW USER OTP BYPASS CHECK
    if (ClientService.kBypassOtpVerification) {
      if (!mounted) return;
      setState(() {
        _verificationId = 'MOCK_VERIFICATION_ID_NEW'; // Fake ID for new user
        _otpCodeSent = true;
      });
      _showMessage(context, 'OTP bypassed. Use mock code 123456.', isError: false);
      ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
      return;
    }

    try {
      // 1. Try PUSH Notification delivery
      final deliveryResult = await service.generateAndSendOtp(mobileNumber: mobile);

      if (deliveryResult == 'SMS_REQUIRED') {
        // 2. Fallback: PUSH failed or token was missing, initiate SMS flow
        await _initiateSmsFlow(mobile); // This handles its own state updates

      } else {
        // PUSH Notification successfully sent (deliveryResult is the verificationId)
        if (!mounted) return;
        setState(() {
          _verificationId = deliveryResult; // Use the CF-generated session ID
          _otpCodeSent = true;
        });
        _showMessage(context, 'OTP sent via notification. Check your notifications.', isError: false);
      }

    } on Exception catch (e) {
      if (!mounted) return;
      _showMessage(context, 'Error initiating OTP: ${e.toString().split(':').last.trim()}', isError: true);
    } finally {
      if (!mounted) return;
      ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }


  Future<void> _login() async {
    final loginId = _loginIdController.text.trim();
    final password = _loginPasswordController.text.trim();
    if (loginId.isEmpty || password.isEmpty) return;

    try {
      await ref.read(authNotifierProvider.notifier).signIn(loginId, password);
    } catch (e) {
      _showMessage(context, 'Login failed: ${e.toString().split(':').last.trim()}', isError: true);
    }
  }
  Future<void> _signInWithGoogle() async {
    // Set loading state (Must be done before the async call)
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true, error: null);

    try {
      await ref.read(clientServiceProvider).signInWithGoogle();

      // Success. AuthProvider listener handles navigation.
      if (!mounted) return;
      _showMessage(context, 'Signed in successfully!', isError: false);

    } on Exception catch (e) {
      // 識 CRITICAL FIX: Check mounted before using context/state
      if (!mounted) return;
      _showMessage(context, 'Google Sign-In failed: ${e.toString().split(':').last.trim()}', isError: true);
    } finally {
      if (!mounted) return;
      ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }

  Future<void> _validateRegistration() async {
    final patientId = _regPatientIdController.text.trim();
    final mobile = _regMobileController.text.trim();
    if (patientId.isEmpty || mobile.isEmpty) return;

    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);

    try {
      final client = await service.getClientByPatientIdAndMobile(patientId, mobile);
      if (client != null) {
        // 1. Client data is valid (Patient ID + Mobile matched). Now initiate OTP.

        // 🎯 EXISTING CLIENT OTP BYPASS CHECK
        if (ClientService.kBypassOtpVerification) {
          if (!mounted) return;
          setState(() {
            _validatedClient = client; // Save client data
            _clientVerificationId = 'MOCK_VERIFICATION_ID_EXISTING'; // Mock ID for existing client
            _currentPage = AuthPage.registerOtpClient; // Move to OTP page
          });
          _showMessage(context, 'OTP bypassed. Use mock code 123456.', isError: false);
          return;
        }

        // --- REAL OTP FLOW ---
        await service.initiateClientOtpVerification(
            mobileNumber: client.mobile, // Use the verified mobile number
            codeSentCallback: (verificationId) {
              if (mounted) {
                setState(() {
                  _validatedClient = client; // Save client data
                  _clientVerificationId = verificationId;
                  _currentPage = AuthPage.registerOtpClient; // Move to OTP page
                });
                _showMessage(context, 'OTP sent to your registered mobile number.', isError: false);
              }
            },
            verificationFailedCallback: (error) {
              if (mounted) {
                _showMessage(context, 'OTP sending failed: $error', isError: true);
              }
            });
      } else {
        _showMessage(context, 'Verification failed. Client not found with those details.', isError: true);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showMessage(context, 'Error: ${e.toString().split(':').last.trim()}', isError: true);
    } finally {
      if (!mounted) return;
      ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }


  Future<void> _verifyExistingClientOtp() async {
    final code = _clientOtpCodeController.text.trim();
    if (_clientVerificationId == null || code.isEmpty) {
      _showMessage(context, 'Please enter the 6-digit OTP.', isError: true);
      return;
    }

    // Set loading state
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true, error: null);

    try {
      // 🎯 EXISTING CLIENT OTP BYPASS CHECK
      if (ClientService.kBypassOtpVerification) {
        const mockCode = '123456';
        if (code == mockCode) {
          if (!mounted) return;
          setState(() => _currentPage = AuthPage.registerPassword);
          _showMessage(context, 'Mock OTP verified successfully.', isError: false);
        } else {
          _showMessage(context, 'Incorrect mock code. Try $mockCode.', isError: true);
        }
        return; // EXIT after mock check
      }

      // --- REAL OTP FLOW ---
      // NOTE: We don't sign in here, we just verify the code
      await ref.read(clientServiceProvider).verifyOtpCode(
          verificationId: _clientVerificationId!,
          smsCode: code
      );

      // OTP is valid! Now move to the final password setting step.
      if (!mounted) return;
      setState(() {
        _currentPage = AuthPage.registerPassword;
      });
      _showMessage(context, 'Mobile verified. Set your secure password.', isError: false);

    } on Exception catch (e) {
      if (!mounted) return;
      _showMessage(context, 'OTP verification failed. Invalid code.', isError: true);
    } finally {
      if (!mounted) return;
      ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }



  Future<void> _completeRegistration() async {
    final password = _regPasswordController.text.trim();
    final confirmPassword = _regConfirmPasswordController.text.trim();
    if (_validatedClient == null || password != confirmPassword || password.length < 6) {
      _showMessage(context, 'Passwords do not match or are too short (min 6 characters).', isError: true);
      return;
    }

    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true);

    try {
      await service.registerClientCredentials(_validatedClient!.id,_validatedClient!.mobile, password);
      await ref.read(authNotifierProvider.notifier).signIn(_validatedClient!.mobile, password);
      if(!mounted) return;
      _showMessage(context, 'Registration complete! Welcome.', isError: false);
    } on Exception catch (e) {
      if(!mounted) return;
      _showMessage(context, 'Registration failed: ${e.toString().split(':').last.trim()}', isError: true);
    } finally {
      if(!mounted) return;
      ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }


  // --- NEW UI BUILDER: OTP Challenge ---
  Widget _buildOtpClientRegistration(AuthState authState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            'Verify Mobile for ${_validatedClient?.mobile ?? ''}',
            textAlign: TextAlign.center,
            style:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade700)
        ),
        const SizedBox(height: 10),
        // 🎯 Show mock code message if bypassed
        if (ClientService.kBypassOtpVerification)
          const Text('OTP verification bypassed for development. Enter mock code 123456.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.red)),
        const SizedBox(height: 10),
        const Text('Enter the 6-digit code sent to your registered mobile number to confirm ownership.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
        const SizedBox(height: 30),

        // OTP Input Field
        _buildTextField(
          controller: _clientOtpCodeController,
          label: 'Enter 6-digit OTP',
          icon: Icons.vpn_key_rounded,
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 30),

        // Verify Button
        _buildAuthButton(
          text: 'Verify Mobile Number',
          isLoading: authState.isLoading,
          onPressed: _verifyExistingClientOtp,
          color: Colors.blue.shade700,
        ),

        const SizedBox(height: 20),
        _buildSecondaryButton(text: "Cancel Registration", onPressed: () => setState(() => _currentPage = AuthPage.login)),
      ],
    );
  }

  Future<void> _completeOtpRegistration() async {
    final code = _otpCodeController.text.trim();
    if (_verificationId == null || code.isEmpty) {
      _showMessage(context, 'Please enter the 6-digit OTP.', isError: true);
      return;
    }

    final service = ref.read(clientServiceProvider);
    ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: true, error: null);

    try {
      // 🎯 NEW USER VERIFICATION BYPASS CHECK
      if (ClientService.kBypassOtpVerification) {
        const mockCode = '123456';
        if (code == mockCode) {
          // Mock verification successful, now proceed to mock registration
          final mobile = _otpMobileController.text.trim();
          await service.registerNewAppUser(
              verificationId: _verificationId!, // Still pass the mock ID
              smsCode: code,
              mobileNumber: mobile
          );
          _showMessage(context, 'Registration successful! Welcome (Mock).', isError: false);
          return;
        } else {
          _showMessage(context, 'OTP verification failed: Invalid mock code.', isError: true);
          return;
        }
      }

      // --- REAL REGISTRATION FLOW ---
      await service.registerNewAppUser(
          verificationId: _verificationId!,
          smsCode: code,
          mobileNumber: _otpMobileController.text.trim()
      );
      _showMessage(context, 'Registration successful! Welcome.', isError: false);
      // AuthProvider listener handles navigation
    } on Exception catch (e) {
      _showMessage(context, 'OTP verification failed: ${e.toString().split(':').last.trim()}', isError: true);
    } finally {
      ref.read(authNotifierProvider.notifier).state = ref.read(authNotifierProvider).copyWith(isLoading: false);
    }
  }

  // --- UI Builders ---

  Widget _buildLogin(AuthState authState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Welcome Back!', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)),

        const SizedBox(height: 30),

        // --- Existing Login Fields ---
        _buildTextField(controller: _loginIdController, label: 'Mobile or Patient ID', icon: Icons.person_rounded),
        const SizedBox(height: 20),
        _buildTextField(controller: _loginPasswordController, label: 'Password', icon: Icons.lock_rounded, isPassword: true),
        const SizedBox(height: 30),
        _buildAuthButton(text: 'Sign In', isLoading: authState.isLoading, onPressed: _login),

        const SizedBox(height: 20),
        TextButton(onPressed: () => setState(() => _currentPage = AuthPage.forgotPassword), child: const Text('Forgot Password?', style: TextStyle(color: Colors.blue))),

        const Divider(height: 40, thickness: 1), // Separator

        // 識 NEW: Google Sign-In Button (Available immediately on the login screen)
        ElevatedButton.icon(
          onPressed: authState.isLoading ? null : _signInWithGoogle,
          icon: const Icon(Icons.email, color: Colors.white),
          label: const Text('Continue with Google'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: 20),

        // Existing Client Registration Button
        _buildSecondaryButton(text: "Existing Client: Register Patient ID", onPressed: () => setState(() => _currentPage = AuthPage.registerVerify)),

        // Mobile OTP Registration Button
        _buildSecondaryButton(
            text: "New User: Register via Mobile OTP",
            onPressed: () => setState(() {
              _currentPage = AuthPage.registerOtp;
              // Reset OTP state
              _otpCodeSent = false;
            }),
            color: Colors.blue.shade700
        ),
      ],
    );
  }

  Widget _buildOtpRegistration(AuthState authState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Explore NutriCare', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 10),
        const Text('Sign up with your mobile number to explore free features.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
        const SizedBox(height: 30),

        _buildTextField(
            controller: _otpMobileController,
            label: 'Mobile Number (+CountryCode)',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            readOnly: _otpCodeSent // Lock number after OTP is sent
        ),

        const SizedBox(height: 20),

        if (_otpCodeSent) ...[
          // 🎯 Show mock code message if bypassed
          if (ClientService.kBypassOtpVerification)
            const Text('OTP verification bypassed. Enter mock code 123456.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.red)),
          const SizedBox(height: 10),

          _buildTextField(
            controller: _otpCodeController,
            label: 'Enter 6-digit OTP',
            icon: Icons.vpn_key_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 30),
          _buildAuthButton(
            text: 'Verify OTP & Register',
            isLoading: authState.isLoading,
            onPressed: _completeOtpRegistration,
            color: Colors.blue,
          ),
        ] else ...[
          _buildAuthButton(
            text: 'Send OTP',
            isLoading: authState.isLoading,
            onPressed: _initiateOtpFlow,
            color: Colors.blue,
          ),
        ],

        const SizedBox(height: 20),
        _buildSecondaryButton(text: "Back to Login", onPressed: () => setState(() => _currentPage = AuthPage.login)),
      ],
    );
  }

  // --- Common Helper Widgets (omitted existing helpers) ---
  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text, bool readOnly = false}) {
    return TextField(controller: controller, obscureText: isPassword, readOnly: readOnly, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.teal)));
  }

  Widget _buildAuthButton({required String text, required bool isLoading, required VoidCallback onPressed, Color color = Colors.teal}) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
      child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSecondaryButton({required String text, required VoidCallback onPressed, Color color = Colors.grey}) {
    return TextButton(onPressed: onPressed, child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)));
  }

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.teal, duration: const Duration(seconds: 3)));
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    Widget currentWidget;
    switch (_currentPage) {
      case AuthPage.login:
        currentWidget = _buildLogin(authState);
        break;
      case AuthPage.registerVerify:
        currentWidget = _buildRegisterVerify(authState);
        break;
      case AuthPage.registerOtpClient:
        currentWidget = _buildOtpClientRegistration(authState);
        break;
      case AuthPage.registerPassword:
        currentWidget = _buildRegisterPassword(authState);
        break;
      case AuthPage.forgotPassword:
        currentWidget = _buildForgotPassword(authState);
        break;
      case AuthPage.registerOtp:
        currentWidget = _buildOtpRegistration(authState);
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - 64,
            child: currentWidget,
          ),
        ),
      ),
    );
  }

// NOTE: These methods belong inside the _ClientAuthScreenState class in lib/features/dietplan/PRESENTATION/screens/client_auth_screen.dart

  // --- Existing Client Registration Step 1: Verification ---
  Widget _buildRegisterVerify(AuthState authState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Activate Account', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)),
        const SizedBox(height: 10),
        const Text('Enter Patient ID and Mobile Number for verification.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
        const SizedBox(height: 30),

        // Patient ID Field
        _buildTextField(controller: _regPatientIdController, label: 'Patient ID', icon: Icons.badge_rounded),
        const SizedBox(height: 20),

        // Registered Mobile Field
        _buildTextField(controller: _regMobileController, label: 'Registered Mobile', icon: Icons.phone_rounded, keyboardType: TextInputType.phone),
        const SizedBox(height: 30),

        // Verify Button
        _buildAuthButton(text: 'Verify Account', isLoading: authState.isLoading, onPressed: _validateRegistration),
        const SizedBox(height: 20),

        _buildSecondaryButton(text: "Back to Login", onPressed: () => setState(() => _currentPage = AuthPage.login)),
      ],
    );
  }

  // --- Existing Client Registration Step 2: Set Password ---
  Widget _buildRegisterPassword(AuthState authState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            'Set Password for Client: ${_validatedClient?.mobile ?? 'N/A'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)
        ),
        const SizedBox(height: 30),

        // New Password Field
        _buildTextField(controller: _regPasswordController, label: 'New Password (min 6)', icon: Icons.vpn_key_rounded, isPassword: true),
        const SizedBox(height: 20),

        // Confirm Password Field
        _buildTextField(controller: _regConfirmPasswordController, label: 'Confirm Password', icon: Icons.vpn_key_rounded, isPassword: true),
        const SizedBox(height: 30),

        // Complete Registration Button
        _buildAuthButton(text: 'Set Password & Login', isLoading: authState.isLoading, onPressed: _completeRegistration),
        const SizedBox(height: 20),

        _buildSecondaryButton(text: "Cancel", onPressed: () => setState(() => _currentPage = AuthPage.login)),
      ],
    );
  }

  // --- Forgot Password Flow ---
  Widget _buildForgotPassword(AuthState authState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Reset Password', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 10),
        const Text('Enter your Login ID to receive a password reset link in your registered email.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
        const SizedBox(height: 30),

        // Login ID Field (Used for password reset lookup)
        _buildTextField(controller: _loginIdController, label: 'Mobile or Patient ID', icon: Icons.person_rounded),
        const SizedBox(height: 30),

        // Send Reset Link Button
        _buildAuthButton(
          text: 'Send Reset Link',
          isLoading: authState.isLoading,
          onPressed: () async {
            try {
              // Note: The logic for this handler is partially implemented in the method definition above.
              await ref.read(clientServiceProvider).clientForgotPassword(_loginIdController.text.trim());
              _showMessage(context, 'Password reset link sent (if account exists).', isError: false);
              setState(() => _currentPage = AuthPage.login);
            } catch (e) {
              _showMessage(context, 'Failed to send reset link.', isError: true);
            }
          },
          color: Colors.orange,
        ),
        const SizedBox(height: 20),

        _buildSecondaryButton(text: "Back to Login", onPressed: () => setState(() => _currentPage = AuthPage.login)),
      ],
    );
  }
}