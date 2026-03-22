import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import '../theme/animations.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/user_photo_widget.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = true;
  String _selectedLanguage = 'English';
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('pref_notifications') ?? true;
      _darkMode = prefs.getBool('pref_dark_mode') ?? true;
      _selectedLanguage = prefs.getString('pref_language') ?? 'English';
    });
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _authService.getUserDataStream(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final currentEmail = userData['email'] ?? _authService.currentUser?.email ?? '';
          final displayName = userData['displayName'] ?? 'User';
          final photoURL = userData['photoURL'];

          return ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildProfilePictureSection(displayName, currentEmail, photoURL),
              
              _sectionHeader('Preferences'),
              _settingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Push notifications & sounds',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                    _updatePreference('pref_notifications', val);
                  },
                  activeColor: AppTheme.primaryPurple,
                ),
              ),
              _settingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Dark theme for the app',
                trailing: Switch(
                  value: _darkMode,
                  onChanged: (val) {
                    setState(() => _darkMode = val);
                    _updatePreference('pref_dark_mode', val);
                  },
                  activeColor: AppTheme.primaryPurple,
                ),
              ),
              _settingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: _selectedLanguage,
                onTap: () => _showLanguageDialog(),
              ),
              
              _sectionHeader('Account'),
              _settingsTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                onTap: () => _showEditProfileModal(userData),
              ),
              _settingsTile(
                icon: Icons.security_outlined,
                title: 'Security',
              ),
              
              _sectionHeader('Legal'),
              _settingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
              ),
              _settingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
              ),
              
              _sectionHeader('Account Actions'),
              _settingsTile(
                icon: Icons.logout,
                title: 'Logout',
                iconColor: Colors.redAccent,
                onTap: () => _showLogoutConfirm(userData),
              ),
              
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextButton(
                  onPressed: () => _showDeleteAccountConfirm(),
                  child: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary.withOpacity(0.7),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? AppTheme.primaryPurple).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor ?? AppTheme.primaryPurple, size: 22),
        ),
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            color: enabled ? Colors.white : Colors.white24,
            fontSize: 15,
          )
        ),
        subtitle: subtitle != null 
          ? Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)) 
          : null,
        trailing: trailing ?? Icon(Icons.chevron_right, color: AppTheme.textSecondary.withOpacity(0.5), size: 20),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Widget _buildProfilePictureSection(String displayName, String email, String? photoURL) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          BounceClick(
            onTap: () => _showProfilePictureOptions(photoURL),
            child: Stack(
              children: [
                UserPhotoWidget(
                  userId: _authService.currentUser?.uid ?? '',
                  radius: 40,
                  showBorder: true,
                  borderGradient: AppTheme.primaryGradient,
                  borderWidth: 3,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.surfaceDark, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap to update photo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfilePictureOptions(String? photoURL) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Profile Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined, color: Colors.white),
                title: const Text('Upload from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (photoURL != null && photoURL.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _authService.saveUserData({'photoURL': ''});
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPurple),
      ),
    );

    try {
      final photoURL =
          await StorageService.instance.uploadProfilePicture(image.path);
      await _authService.saveUserData({'photoURL': photoURL});
      if (mounted) {
        Navigator.pop(context); // Close loading
        GlassmorphicEffects.showGlassSnackBar(context,
            message: 'Profile picture updated!');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        GlassmorphicEffects.showGlassSnackBar(context,
            message: 'Failed to upload: $e', isError: true);
      }
    }
  }

  void _showEditProfileModal(Map<String, dynamic> userData) {
    final nameController = TextEditingController(text: userData['displayName'] ?? '');
    final usernameController = TextEditingController(text: userData['username'] ?? '');
    final phoneController = TextEditingController(text: userData['phoneNumber'] ?? '');
    final emailController = TextEditingController(text: userData['email'] ?? '');
    final bioController = TextEditingController(text: userData['bio'] ?? '');
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Edit Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              _buildEditField(Icons.person_outline, 'Display Name', nameController),
              const SizedBox(height: 16),
              _buildEditField(Icons.alternate_email, 'Username', usernameController),
              const SizedBox(height: 16),
              _buildEditField(Icons.info_outline, 'Bio', bioController, maxLines: 3),
              const SizedBox(height: 16),
              _buildEditField(Icons.phone_android_outlined, 'Mobile Number', phoneController),
              const SizedBox(height: 16),
              _buildEditField(Icons.email_outlined, 'Email Address', emailController),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: GlassmorphicEffects.gradientButton(
                  text: 'Save Changes',
                  isLoading: isLoading,
                  onPressed: () async {
                    setModalState(() => isLoading = true);
                    try {
                      await _authService.saveUserData({
                        'displayName': nameController.text.trim(),
                        'username': usernameController.text.trim(),
                        'phoneNumber': phoneController.text.trim(),
                        'email': emailController.text.trim(),
                        'bio': bioController.text.trim(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        GlassmorphicEffects.showGlassSnackBar(context, message: 'Profile updated successfully!');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setModalState(() => isLoading = false);
                        GlassmorphicEffects.showGlassSnackBar(context, message: 'Failed to update: $e', isError: true);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(IconData icon, String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.primaryPurple, size: 20),
        filled: true,
        fillColor: AppTheme.surfaceDark.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = ['English', 'Spanish', 'French', 'German', 'Filipino', 'Japanese'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Select Language', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(languages[index], style: const TextStyle(color: Colors.white)),
              trailing: _selectedLanguage == languages[index] ? const Icon(Icons.check, color: AppTheme.primaryPurple) : null,
              onTap: () {
                setState(() => _selectedLanguage = languages[index]);
                _updatePreference('pref_language', languages[index]);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirm(Map<String, dynamic> userData) {
    bool saveAccount = true;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to log out?', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Save account on this device', style: TextStyle(fontSize: 14, color: Colors.white)),
                value: saveAccount,
                activeColor: AppTheme.primaryPurple,
                onChanged: (val) => setDialogState(() => saveAccount = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final currentUser = _authService.currentUser;
                  if (saveAccount && currentUser != null) {
                    final currentEmail = userData['email'] ?? currentUser.email ?? '';
                    final accountData = {
                      'uid': currentUser.uid,
                      'email': currentEmail,
                      'displayName': userData['displayName'] ?? currentUser.displayName ?? '',
                      'username': userData['username'] ?? '',
                      'photoURL': userData['photoURL'] ?? currentUser.photoURL ?? '',
                      'provider': prefs.getString('temp_provider') ?? 'email',
                    };
                    final tempPass = prefs.getString('temp_password');
                    if (tempPass != null) accountData['password'] = tempPass;
                    
                    final accountsJson = prefs.getString('saved_accounts') ?? '[]';
                    final List<dynamic> accounts = jsonDecode(accountsJson);
                    accounts.removeWhere((acc) => acc['email'] == currentEmail);
                    accounts.insert(0, accountData);
                    if (accounts.length > 5) accounts.removeRange(5, accounts.length);
                    await prefs.setString('saved_accounts', jsonEncode(accounts));
                  }
                  Navigator.pop(dialogContext);
                  await _authService.signOut();
                } catch (e) {
                  debugPrint('Logout error: $e');
                }
              },
              child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
        content: const Text('This action is permanent and cannot be undone.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}
