import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/auth_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/diet_plan_provider.dart' hide clientServiceProvider; // For sensor provider
import 'package:nutricare_connect/features/dietplan/PRESENTATION/providers/global_user_provider.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_auth_screen.dart';
import 'package:nutricare_connect/features/dietplan/PRESENTATION/screens/client_reminder_setting_screen.dart';
import 'package:nutricare_connect/services/client_service.dart';
import 'dart:io';

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

  bool _isEditing = false;
  bool _isSaving = false;


  void _showLanguageDialog() {
    final user = ref.read(globalUserProvider);
    if (user == null || user.reminderConfig == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Language"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _langOption(ctx, user, "English", "en-US"),
            _langOption(ctx, user, "Hindi (हिंदी)", "hi-IN"),
            _langOption(ctx, user, "Oriya (ଓଡିଆ)", "or-IN"),
          ],
        ),
      ),
    );
  }

  Widget _langOption(BuildContext ctx, ClientModel user, String label, String code) {
    return ListTile(
      title: Text(label),
      leading: Radio<String>(
        value: code,
        groupValue: user.reminderConfig!.languageCode,
        onChanged: (val) async {
          Navigator.pop(ctx);

          // 1. Update Model
          final updatedConfig = user.reminderConfig!.copyWith(languageCode: val);
          final updatedUser = user.copyWith(reminderConfig: updatedConfig);

          // 2. Save to Firestore
          await ref.read(clientServiceProvider).updateClient(updatedUser);

          // 3. Update Global State
          ref.read(globalUserProvider.notifier).setUser(updatedUser);

          // 4. Provide Feedback
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Language Updated! Reminders will now speak in this language.")));
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final user = ref.read(globalUserProvider);
    if (user != null) {
      _nameCtrl.text = user.name ?? '';
      _emailCtrl.text = user.email ?? '';
      _whatsappCtrl.text = user.whatsappNumber ?? '';
      _addressCtrl.text = user.address ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(globalUserProvider);
    final bool isSensorEnabled = ref.watch(stepSensorEnabledProvider);

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.teal),
            onPressed: _isEditing ? _saveProfile : () => setState(() => _isEditing = true),
            tooltip: _isEditing ? "Save Changes" : "Edit Profile",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. IDENTITY HEADER
            _buildIdentityHeader(user),
            const SizedBox(height: 30),

            // 2. PERSONAL DETAILS
            _buildSectionTitle("Personal Details"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildTextField("Full Name", _nameCtrl, Icons.person, isLocked: (user.name ?? '').isNotEmpty),
                  const SizedBox(height: 16),
                  _buildTextField("Gender", TextEditingController(text: user.gender), Icons.wc, isLocked: true),
                  const SizedBox(height: 16),
                  _buildDateSelector("Date of Birth", user.dob, (user.dob == null)),
                  const Divider(height: 30),
                  _buildTextField("WhatsApp Number", _whatsappCtrl, FontAwesomeIcons.whatsapp, isLocked: !_isEditing),
                  const SizedBox(height: 16),
                  _buildTextField("Email Address", _emailCtrl, Icons.email, isLocked: !_isEditing),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("Address", _addressCtrl, Icons.home, isLocked: !_isEditing)),
                      if (_isEditing)
                        IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.blue),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching GPS...")));
                            setState(() => _addressCtrl.text = "123, Mock Street, City");
                          },
                        )
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 3. APP SETTINGS & PREFERENCES (Consolidated)
            _buildSectionTitle("Settings & Preferences"),
            _buildSettingsGroup([
              _buildActionTile("App Language", "English", Icons.language, () {}),
              _buildActionTile("Notifications", "Manage Alerts", Icons.notifications, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientReminderSettingsScreen(client: user)))),
              // 🎯 SENSOR TOGGLE MOVED HERE
              _buildSwitchTile("Step Sensor", isSensorEnabled, (val) => ref.read(stepSensorEnabledProvider.notifier).state = val),
              _buildActionTile("Privacy Policy", "Read", Icons.privacy_tip, () {}),
            ]),

            const SizedBox(height: 30),

            // 4. SECURITY
            _buildSettingsGroup([
              _buildActionTile("Change Password", "Update Securely", Icons.lock, () => _showChangePasswordDialog()),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  // In CoachTab or Profile Screen
                  onTap: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const ClientAuthScreen()),
                            (route) => false
                    );
                  }
              )
            ]),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---
  Widget _buildIdentityHeader(ClientModel user) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty ? NetworkImage(user.photoUrl!) : null,
              backgroundColor: Colors.teal.shade100,
              child: (user.photoUrl == null) ? Text(user.name?[0] ?? 'U', style: const TextStyle(fontSize: 40, color: Colors.teal)) : null,
            ),
            Positioned(
              bottom: 0, right: 0,
              child: CircleAvatar(
                radius: 16, backgroundColor: Colors.white,
                child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.camera_alt, size: 18, color: Colors.grey), onPressed: _pickProfilePhoto),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        Text(user.name ?? "Wellness Warrior", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text("ID: ${user.patientId}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: Icon(value ? Icons.toggle_on : Icons.toggle_off, color: value ? Colors.teal : Colors.grey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.teal,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey))));
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {bool isLocked = false}) {
    return TextField(
      controller: ctrl, enabled: !isLocked,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: isLocked ? Colors.grey : Colors.teal), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: isLocked, fillColor: Colors.grey.shade100),
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, bool isEditable) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.cake), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: !isEditable, fillColor: Colors.grey.shade100),
      child: Text(date != null ? DateFormat('dd MMM yyyy').format(date) : "Not Set"),
    );
  }

  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; });
    final user = ref.read(globalUserProvider);
    if (user == null) return;

    final updatedUser = user.copyWith(email: _emailCtrl.text.trim(), whatsappNumber: _whatsappCtrl.text.trim(), address: _addressCtrl.text.trim());

    try {
      await ref.read(clientServiceProvider).updateClient(updatedUser);
      ref.read(globalUserProvider.notifier).setUser(updatedUser);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!"), backgroundColor: Colors.green));
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  void _pickProfilePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading Photo...")));
  }

  void _showChangePasswordDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Change Password"), content: const Text("Contact Admin to reset password.")));
  }
}