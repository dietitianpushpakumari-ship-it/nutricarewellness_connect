import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/new/utils/image_compressor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:nutricare_connect/core/utils/client_model.dart';
import 'package:nutricare_connect/features/auth/auth_provider.dart';
import 'package:nutricare_connect/new/provider/diet_plan_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/new/login/client_auth_screen.dart';
import 'package:nutricare_connect/features/profile/client_reminder_setting_screen.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // 🎯 FIXED: All text fields now have dedicated controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gpsCtrl = TextEditingController();
  File? _pickedImageFile;

  Map<String, double>? _capturedGeoLocation;
  bool _isEditing = false;
  bool _isSaving = false;


  Widget _buildIdentityHeader(ClientModel user, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    ImageProvider? avatarImage;

    // 1. Show local preview if they just picked a new photo
    if (_pickedImageFile != null) {
      avatarImage = FileImage(_pickedImageFile!);
    }
    // 2. 🎯 Show Cached Network Image if URL exists
    else if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      avatarImage = CachedNetworkImageProvider(
        user.photoUrl!,
        // Optional: you can add maxHeight/maxWidth here to save memory
      );
    }

    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary.withOpacity(0.3), width: 2)
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: isDark ? colorScheme.primaryContainer.withOpacity(0.2) : colorScheme.primaryContainer,
                backgroundImage: avatarImage,
                // Fallback text if no image exists
                child: avatarImage == null
                    ? Text(user.name?.isNotEmpty == true ? user.name![0].toUpperCase() : 'U',
                    style: TextStyle(fontSize: 40, color: colorScheme.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            if (_isEditing) Positioned(
              bottom: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle, border: Border.all(color: theme.dividerColor.withOpacity(0.2))),
                child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.transparent,
                    child: IconButton(padding: EdgeInsets.zero, icon: Icon(Icons.camera_alt_rounded, size: 16, color: colorScheme.primary), onPressed: _pickProfilePhoto)
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        Text(user.name ?? "Wellness Warrior", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        const SizedBox(height: 4),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text("ID: ${user.patientId}", style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold, fontSize: 12))
        ),
      ],
    );
  }
  void _pickProfilePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      setState(() {
        _pickedImageFile = File(image.path); // 🎯 Triggers the UI to show the preview
      });

      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                "Photo selected! Tap 'Save Changes' to apply.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold) // 🎯 Forced white text
            ),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating, // Makes it look premium
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
      );
    }
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    // 🎯 FIXED: Prevent memory leaks by disposing of all controllers
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _gpsCtrl.dispose();
    super.dispose();
  }

  // 🎯 FIXED: Safe data loading that updates the GPS controller properly
  void _loadData() {
    // 🎯 Rely strictly on globalUserProvider since it holds the newly saved edits
    final user = ref.read(globalUserProvider) ?? ref.read(currentClientProvider);
    if (user != null && mounted) {
      setState(() {
        _nameCtrl.text = user.name ?? '';
        _emailCtrl.text = user.email ?? '';
        _whatsappCtrl.text = user.whatsappNumber ?? '';
        _addressCtrl.text = user.address ?? '';
        _capturedGeoLocation = user.geoLocation;
        _updateGpsDisplay();
      });
    }
  }

  void _updateGpsDisplay() {
    if (_capturedGeoLocation != null) {
      _gpsCtrl.text = "${_capturedGeoLocation!['lat']?.toStringAsFixed(4)}, ${_capturedGeoLocation!['lng']?.toStringAsFixed(4)}";
    } else {
      _gpsCtrl.text = "Not Captured";
    }
  }

  // 🎯 EXACT LOCATION FETCHING
// 🎯 EXACT LOCATION FETCHING (Updated with Premium Snackbars)
  Future<void> _fetchActualLocation(ColorScheme colorScheme) async {
    try {
      // 🎯 Standard Info Snackbar
      _showSnackBar("Checking GPS...");

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Location services are disabled in device settings.", isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions denied by user.", isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Permissions permanently denied. Go to App Settings.", isError: true);
        return;
      }

      _showSnackBar("Fetching exact coordinates...");

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _capturedGeoLocation = {
            'lat': position.latitude,
            'lng': position.longitude
          };
          _updateGpsDisplay(); // Update the text field

          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            _addressCtrl.text = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
          }
        });
        // 🎯 Green Success Snackbar
        _showSnackBar("Location Captured Successfully!", isSuccess: true);
      }
    } catch (e) {
      // 🎯 Red Error Snackbar
      _showSnackBar("Error: ${e.toString().replaceAll("Exception:", "").trim()}", isError: true);
    }
  }
  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://nutricarewellness.com/privacy-policy');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open Privacy Policy"), backgroundColor: Colors.red));
    }
  }

  // 🎯 SAVE PROFILE
// 🎯 SAVE PROFILE WITH WEBP COMPRESSION & UPLOAD
  // 🎯 SAVE PROFILE WITH WEBP COMPRESSION & UPLOAD
  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; });
    final user = ref.read(globalUserProvider) ?? ref.read(currentClientProvider);
    if (user == null) return;

    try {
      String? newPhotoUrl = user.photoUrl;

      if (_pickedImageFile != null) {
        // 🎯 Uses the Theme's Primary Color (Blue/Green/etc)
        _showSnackBar("Compressing & Uploading photo...");

        final File? compressedFile = await ImageCompressor.compressAndGetFile(_pickedImageFile!);
        final File fileToUpload = compressedFile ?? _pickedImageFile!;

        final String filePath = 'client_profiles/${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.webp';
        final Reference storageRef = FirebaseStorage.instance.ref().child(filePath);

        await storageRef.putFile(
          fileToUpload,
          SettableMetadata(contentType: 'image/webp'),
        );

        newPhotoUrl = await storageRef.getDownloadURL();
      }

      final updatedUser = user.copyWith(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        whatsappNumber: _whatsappCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        geoLocation: _capturedGeoLocation,
        photoUrl: newPhotoUrl,
      );

      await ref.read(clientServiceProvider).updateClient(updatedUser);
      ref.read(globalUserProvider.notifier).setUser(updatedUser);

      if (mounted) {
        // 🎯 Uses Solid Green
        _showSnackBar("Profile Updated Successfully!", isSuccess: true);
        setState(() {
          _isEditing = false;
          _pickedImageFile = null;
        });
      }
    } catch (e) {
      if (mounted) {
        // 🎯 Uses Solid Red
        _showSnackBar("Error: ${e.toString().replaceAll("Exception:", "").trim()}", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
// 🎯 UNIFIED PREMIUM SNACKBAR HELPER
  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;

    // Default to 'Info/Loading' mode (uses your Theme's Primary Color)
    Color bgColor = colorScheme.primary;
    IconData icon = Icons.info_outline_rounded;

    if (isError) {
      bgColor = Colors.red.shade600;
      icon = Icons.error_outline_rounded;
    } else if (isSuccess) {
      bgColor = Colors.green.shade600;
      icon = Icons.check_circle_outline_rounded;
    }

    // Hide any currently showing snackbars so they don't queue up forever
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20), // 🎯 Always White
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), // 🎯 Always White
                  )
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          elevation: 6,
          duration: const Duration(seconds: 3),
        )
    );
  }
  @override
  Widget build(BuildContext context) {
    // 🎯 FIXED: Listen for background provider updates to keep UI perfectly in sync
    ref.listen(globalUserProvider, (previous, next) {
      if (!_isEditing && next != null && mounted) {
        _loadData();
      }
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final user = ref.watch(currentClientProvider) ?? ref.watch(globalUserProvider);
    final bool isSensorEnabled = ref.watch(stepSensorEnabledProvider);
    String t(String key) => context.tr(key);

    if (user == null) return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: Center(child: CircularProgressIndicator(color: colorScheme.primary)));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('settings'), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: theme.scaffoldBackgroundColor.withOpacity(0.7)),
          ),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.close_rounded, color: colorScheme.error),
              tooltip: "Cancel Edit",
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _pickedImageFile = null; // 🎯 Throw away the local preview
                });
                _loadData();
              },
            ),
          IconButton(
            icon: _isSaving
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colorScheme.primary, strokeWidth: 2))
                : Icon(_isEditing ? Icons.check_circle_rounded : Icons.edit_rounded, color: colorScheme.primary),
            onPressed: _isSaving ? null : (_isEditing ? _saveProfile : () => setState(() => _isEditing = true)),
            tooltip: _isEditing ? "Save Changes" : "Edit Profile",
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          children: [
            _buildIdentityHeader(user, theme, colorScheme, isDark),
            const SizedBox(height: 32),

            _buildSectionTitle("Personal Details", theme),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.1))),
              child: Column(
                children: [
                  _buildTextField("Full Name", _nameCtrl, Icons.person_rounded, theme, colorScheme, isDark, isLocked: !_isEditing),
                  const SizedBox(height: 16),
                  _buildTextField("Gender", TextEditingController(text: user.gender), Icons.wc_rounded, theme, colorScheme, isDark, isLocked: true),
                  const SizedBox(height: 16),
                  _buildDateSelector("Date of Birth", user.dob, false, theme, colorScheme, isDark),
                  Divider(height: 32, color: theme.dividerColor.withOpacity(0.2)),
                  _buildTextField("WhatsApp Number", _whatsappCtrl, FontAwesomeIcons.whatsapp, theme, colorScheme, isDark, isLocked: !_isEditing),
                  const SizedBox(height: 16),
                  _buildTextField("Email Address", _emailCtrl, Icons.email_rounded, theme, colorScheme, isDark, isLocked: !_isEditing),
                  const SizedBox(height: 16),
                  _buildTextField("Physical Address", _addressCtrl, Icons.home_rounded, theme, colorScheme, isDark, isLocked: !_isEditing),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField(
                              "GPS Coordinates",
                              _gpsCtrl, // 🎯 FIXED: Using the dedicated controller
                              Icons.pin_drop_rounded,
                              theme, colorScheme, isDark,
                              isLocked: true
                          )
                      ),
                      if (_isEditing) ...[
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            icon: Icon(Icons.my_location_rounded, color: colorScheme.primary),
                            onPressed: () => _fetchActualLocation(colorScheme),
                          ),
                        )
                      ]
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildSectionTitle("Settings & Preferences", theme),
            _buildSettingsGroup(theme, isDark, [
              _buildActionTile("Notifications", "Manage Alerts", Icons.notifications_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientReminderSettingsScreen(client: user))), theme, colorScheme),
              _buildSwitchTile("Step Sensor", isSensorEnabled, (val) => ref.read(stepSensorEnabledProvider.notifier).state = val, theme, colorScheme),
              _buildActionTile("Privacy Policy", "Read", Icons.privacy_tip_rounded, _launchPrivacyPolicy, theme, colorScheme),
            ]),

            const SizedBox(height: 32),

            _buildSectionTitle("Security & Access", theme),
            _buildSettingsGroup(theme, isDark, [
              _buildActionTile("Reset PIN / Password", "Update Securely", Icons.lock_rounded, () => _showChangePasswordDialog(theme, colorScheme), theme, colorScheme),
              ListTile(
                  leading: Icon(Icons.logout_rounded, color: colorScheme.error),
                  title: Text("Log Out", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
                  onTap: () => _showLogoutConfirmation(theme, colorScheme)
              )
            ]),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(ThemeData theme, bool isDark, List<Widget> children) {
    return Container(decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.1))), child: Column(children: children));
  }
  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, ThemeData theme, ColorScheme colorScheme) {
    return ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: colorScheme.primary, size: 20)), title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)), subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.hintColor)), trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.hintColor), onTap: onTap);
  }
  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged, ThemeData theme, ColorScheme colorScheme) {
    return SwitchListTile(secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: value ? colorScheme.primary.withOpacity(0.1) : theme.dividerColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(value ? Icons.directions_run_rounded : Icons.directions_walk_rounded, color: value ? colorScheme.primary : theme.hintColor, size: 20)), title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)), value: value, onChanged: onChanged, activeColor: colorScheme.primary);
  }
  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.hintColor, letterSpacing: 1.2))));
  }
  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, ThemeData theme, ColorScheme colorScheme, bool isDark, {bool isLocked = false}) {
    return TextField(controller: ctrl, enabled: !isLocked, style: TextStyle(color: isLocked ? theme.hintColor : colorScheme.onSurface), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: theme.hintColor), prefixIcon: Icon(icon, color: isLocked ? theme.hintColor : colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.5))), filled: true, fillColor: isLocked ? (isDark ? Colors.white.withOpacity(0.02) : theme.scaffoldBackgroundColor) : (isDark ? Colors.white.withOpacity(0.05) : theme.scaffoldBackgroundColor)));
  }
  Widget _buildDateSelector(String label, DateTime? date, bool isEditable, ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return InputDecorator(decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: theme.hintColor), prefixIcon: Icon(Icons.cake_rounded, color: !isEditable ? theme.hintColor : colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))), filled: true, fillColor: !isEditable ? (isDark ? Colors.white.withOpacity(0.02) : theme.scaffoldBackgroundColor) : (isDark ? Colors.white.withOpacity(0.05) : theme.scaffoldBackgroundColor)), child: Text(date != null ? DateFormat('dd MMM yyyy').format(date) : "Not Set", style: TextStyle(color: !isEditable ? theme.hintColor : colorScheme.onSurface)));
  }

  void _showChangePasswordDialog(ThemeData theme, ColorScheme colorScheme) {
    showDialog(
        context: context,
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AlertDialog(
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
            title: Text("Reset Security PIN", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
            content: Text("To reset your 4-digit PIN, please Log Out and use the 'ACTIVATE ACCOUNT' button on the login screen with your original Activation Code.", style: TextStyle(color: theme.hintColor)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: theme.hintColor))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                  onPressed: () {
                    Navigator.pop(context);
                    _performLogout();
                  },
                  child: const Text("Log Out & Reset")
              )
            ],
          ),
        )
    );
  }

  void _showLogoutConfirmation(ThemeData theme, ColorScheme colorScheme) {
    showDialog(
        context: context,
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AlertDialog(
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
            title: Text("Log Out", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
            content: Text("Are you sure you want to log out of your NutriCare account?", style: TextStyle(color: theme.hintColor)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: theme.hintColor))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _performLogout();
                  },
                  child: const Text("Log Out")
              )
            ],
          ),
        )
    );
  }

  Future<void> _performLogout() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if(mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ClientAuthScreen()),
              (route) => false
      );
    }
  }
}