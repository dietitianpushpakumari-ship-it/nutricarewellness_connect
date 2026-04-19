import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pure_shift/core/utils/CloudinaryService.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:pure_shift/core/utils/client_model.dart';
import 'package:pure_shift/new/utils/image_compressor.dart';
import 'package:pure_shift/new/service/notification_service.dart';
import 'package:pure_shift/features/auth/auth_provider.dart';
import 'package:pure_shift/new/provider/diet_plan_provider.dart';
import 'package:pure_shift/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:pure_shift/new/login/client_auth_screen.dart';
import 'package:pure_shift/features/profile/client_reminder_setting_screen.dart';


// 🎯 GLOBAL PREMIUM FONTS
const String kDisplayFont = 'Space Grotesk';
const String kBodyFont = 'Inter';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gpsCtrl = TextEditingController();
  File? _pickedImageFile;

  Map<String, double>? _capturedGeoLocation;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _gpsCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
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

  void _pickProfilePhoto() async {
    HapticFeedback.mediumImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null && mounted) {
      setState(() => _pickedImageFile = File(image.path));
      _showSnackBar("Photo selected! Save changes to apply.", isSuccess: true);
    }
  }

  Future<void> _fetchActualLocation() async {
    HapticFeedback.selectionClick();
    try {
      _showSnackBar("Calibrating GPS...");
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _capturedGeoLocation = {'lat': position.latitude, 'lng': position.longitude};
          _updateGpsDisplay();
          if (placemarks.isNotEmpty) {
            Placemark p = placemarks.first;
            _addressCtrl.text = "${p.street}, ${p.subLocality}, ${p.locality}";
          }
        });
        _showSnackBar("Location captured.", isSuccess: true);
      }
    } catch (e) {
      _showSnackBar("GPS Error", isError: true);
    }
  }

  // 🚀 CLOUDINARY UPLOAD LOGIC
  Future<void> _saveProfile() async {
    HapticFeedback.heavyImpact();
    setState(() => _isSaving = true);
    final user = ref.read(globalUserProvider) ?? ref.read(currentClientProvider);
    if (user == null) return;

    try {
      String? newPhotoUrl = user.photoUrl;

      if (_pickedImageFile != null) {
        _showSnackBar("Optimizing & Uploading to Cloudinary...");

        // Keep compression to save bandwidth
        final File? compressed = await ImageCompressor.compressAndGetFile(_pickedImageFile!);
        final File fileToUpload = compressed ?? _pickedImageFile!;

        // 🚀 Swap Firebase for Cloudinary Service
        final uploadedUrl = await ref.read(cloudinaryServiceProvider).uploadFile(
            file: fileToUpload,
            folderName: 'client_profiles'
        );

        if (uploadedUrl == null) {
          throw Exception("Cloudinary upload failed.");
        }
        newPhotoUrl = uploadedUrl;
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
        _showSnackBar("Profile Synced.", isSuccess: true);
        setState(() { _isEditing = false; _pickedImageFile = null; });
      }
    } catch (e) {
      _showSnackBar("Sync Failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalUserProvider, (prev, next) {
      if (!_isEditing && next != null && mounted) _loadData();
    });

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentClientProvider) ?? ref.watch(globalUserProvider);
    final isSensorEnabled = ref.watch(stepSensorEnabledProvider);

    if (user == null) return Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2)));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildPremiumAppBar(theme, cs),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 120, 20, MediaQuery.of(context).padding.bottom + 40),
        child: Column(
          children: [
            _buildIdentityHeader(user, theme, cs, isDark),
            const SizedBox(height: 40),

            _buildSectionLabel("CLINICAL IDENTITY", theme),
            _buildSettingsGroup(theme, [
              _buildTextField("Full Name", _nameCtrl, Icons.person_outline_rounded, theme, cs, isDark, isLocked: !_isEditing),
              _buildTextField("Gender", TextEditingController(text: user.gender), Icons.wc_rounded, theme, cs, isDark, isLocked: true),
              _buildDateDisplay("Date of Birth", user.dob, theme, cs),
            ]),

            const SizedBox(height: 32),

            _buildSectionLabel("CONTACT & LOCATION", theme),
            _buildSettingsGroup(theme, [
              _buildTextField("WhatsApp", _whatsappCtrl, FontAwesomeIcons.whatsapp, theme, cs, isDark, isLocked: !_isEditing),
              _buildTextField("Email", _emailCtrl, Icons.alternate_email_rounded, theme, cs, isDark, isLocked: !_isEditing),
              _buildTextField("Address", _addressCtrl, Icons.map_outlined, theme, cs, isDark, isLocked: !_isEditing),
              _buildGpsField(cs, theme, isDark),
            ]),

            const SizedBox(height: 32),

            _buildSectionLabel("PREFERENCES", theme),
            _buildSettingsGroup(theme, [
              _buildActionTile("Reminders", "Managed clinical alerts", Icons.notifications_none_rounded,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientReminderSettingsScreen(client: user))), theme, cs),
              _buildSwitchTile("Step Sensor", isSensorEnabled,
                      (val) => ref.read(stepSensorEnabledProvider.notifier).state = val, theme, cs),
              _buildActionTile("Privacy Policy", "Data protection details", Icons.shield_outlined, _launchPrivacyPolicy, theme, cs),
            ]),

            const SizedBox(height: 32),

            _buildSectionLabel("SECURITY", theme),
            _buildSettingsGroup(theme, [
              _buildActionTile("Change PIN", "Update security access", Icons.lock_outline_rounded, () => _showChangePasswordDialog(theme, cs), theme, cs),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Icon(Icons.logout_rounded, color: cs.error, size: 20),
                title: Text("Sign Out", style: TextStyle(fontFamily: kBodyFont, color: cs.error, fontWeight: FontWeight.w700, fontSize: 12)),
                onTap: () => _showLogoutConfirmation(theme, cs),
              )
            ]),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(ThemeData theme, ColorScheme cs) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.7),
            elevation: 0,
            title: Text("SETTINGS", style: TextStyle(fontFamily: kDisplayFont, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2, color: cs.onSurface)),
            centerTitle: true,
            actions: [
              if (_isEditing) IconButton(icon: Icon(Icons.close_rounded, color: cs.error, size: 20), onPressed: () { setState(() => _isEditing = false); _loadData(); }),
              IconButton(
                icon: _isSaving ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                    : Icon(_isEditing ? Icons.check_circle_rounded : Icons.edit_note_rounded, color: cs.primary, size: 24),
                onPressed: _isSaving ? null : (_isEditing ? _saveProfile : () => setState(() => _isEditing = true)),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityHeader(ClientModel user, ThemeData theme, ColorScheme cs, bool isDark) {
    ImageProvider? avatar;

    if (_pickedImageFile != null) {
      avatar = FileImage(_pickedImageFile!);
    } else if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      avatar = CachedNetworkImageProvider(user.photoUrl!);
    }  return Column(
      children: [
        GestureDetector(
          onTap: _isEditing ? _pickProfilePhoto : null,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.primary.withOpacity(0.2))),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: theme.dividerColor.withOpacity(0.05),
                  backgroundImage: avatar,
                  child: avatar == null ? Icon(Icons.person_rounded, size: 40, color: theme.hintColor.withOpacity(0.2)) : null,
                ),
              ),
              if (_isEditing) CircleAvatar(radius: 14, backgroundColor: cs.primary, child: const Icon(Icons.add_a_photo_rounded, size: 14, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(user.name?.toUpperCase() ?? "USER", style: TextStyle(fontFamily: kDisplayFont, fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text("PATIENT ID: ${user.patientId}", style: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, ThemeData theme, ColorScheme cs, bool isDark, {bool isLocked = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: ctrl,
        enabled: !isLocked,
        style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: isLocked ? theme.hintColor : cs.onSurface),
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          labelStyle: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1),
          prefixIcon: Icon(icon, size: 18, color: isLocked ? theme.hintColor.withOpacity(0.3) : cs.primary.withOpacity(0.7)),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGpsField(ColorScheme cs, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _gpsCtrl,
              enabled: false,
              style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700, color: theme.hintColor),
              decoration: InputDecoration(
                labelText: "GEOLOCATION",
                labelStyle: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1),
                prefixIcon: Icon(Icons.gps_fixed_rounded, size: 18, color: theme.hintColor.withOpacity(0.3)),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_isEditing) IconButton(icon: Icon(Icons.my_location_rounded, color: cs.primary, size: 20), onPressed: _fetchActualLocation),
        ],
      ),
    );
  }

  Widget _buildDateDisplay(String label, DateTime? date, ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Icon(Icons.cake_outlined, size: 18, color: theme.hintColor.withOpacity(0.3)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: TextStyle(fontFamily: kDisplayFont, fontSize: 8, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1)),
              Text(date != null ? DateFormat('dd MMM yyyy').format(date) : "N/A", style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w600, color: theme.hintColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(ThemeData theme, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor.withOpacity(0.05))),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, ThemeData theme, ColorScheme cs) {
    return ListTile(
      leading: Icon(icon, color: theme.hintColor.withOpacity(0.5), size: 20),
      title: Text(title, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(fontFamily: kBodyFont, fontSize: 10, color: theme.hintColor)),
      trailing: Icon(Icons.chevron_right_rounded, size: 16, color: theme.hintColor.withOpacity(0.3)),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged, ThemeData theme, ColorScheme cs) {
    return SwitchListTile.adaptive(
      secondary: Icon(value ? Icons.sensors_rounded : Icons.sensors_off_rounded, color: value ? cs.primary : theme.hintColor, size: 20),
      title: Text(title, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
      value: value,
      onChanged: (val) { HapticFeedback.selectionClick(); onChanged(val); },
      activeColor: cs.primary,
    );
  }

  Widget _buildSectionLabel(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(fontFamily: kDisplayFont, fontSize: 9, fontWeight: FontWeight.w700, color: theme.hintColor, letterSpacing: 1.5))),
    );
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: kBodyFont, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      backgroundColor: isError ? Colors.redAccent : (isSuccess ? Colors.green : Theme.of(context).colorScheme.primary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(20),
    ));
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://nutricarewellness.com/privacy-policy');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) _showSnackBar("URL Error", isError: true);
  }

  void _showChangePasswordDialog(ThemeData theme, ColorScheme cs) {
    showDialog(context: context, builder: (_) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text("RESET SECURITY PIN", style: TextStyle(fontFamily: kDisplayFont, fontSize: 14, fontWeight: FontWeight.w700)),
      content: Text("To reset your 4-digit PIN, please Sign Out and use the 'ACTIVATE ACCOUNT' flow with your clinical code.", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700, color: theme.hintColor))),
        FilledButton(onPressed: () { Navigator.pop(context); _performLogout(); }, style: FilledButton.styleFrom(backgroundColor: cs.primary, elevation: 0), child: const Text("SIGN OUT & RESET", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700))),
      ],
    )));
  }

  void _showLogoutConfirmation(ThemeData theme, ColorScheme cs) {
    showDialog(context: context, builder: (_) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text("SIGN OUT", style: TextStyle(fontFamily: kDisplayFont, fontSize: 14, fontWeight: FontWeight.w700, color: cs.error)),
      content: Text("Are you sure you want to end your active session?", style: TextStyle(fontFamily: kBodyFont, fontSize: 12, color: theme.hintColor)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700, color: theme.hintColor))),
        FilledButton(onPressed: _performLogout, style: FilledButton.styleFrom(backgroundColor: cs.error, elevation: 0), child: const Text("SIGN OUT", style: TextStyle(fontFamily: kDisplayFont, fontSize: 11, fontWeight: FontWeight.w700))),
      ],
    )));
  }

  Future<void> _performLogout() async {
    final user = ref.read(globalUserProvider) ?? ref.read(currentClientProvider);
    if (user != null) await NotificationService().clearTokenOnLogout(userId: user.id, collectionName: 'clients');
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ClientAuthScreen()), (route) => false);
  }
}