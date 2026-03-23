import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import '../theme/animations.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/user_photo_widget.dart';
import '../services/storage_service.dart';
import '../utils/error_handler.dart';
import '../utils/app_localizations.dart';
import '../main.dart' show themeNotifier;

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
  AppLocalizations get _l => AppLocalizations.instance;

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
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(_l.t('settings_title'), style: TextStyle(color: AppTheme.adaptiveText(context), fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.adaptiveText(context)),
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
              
              _sectionHeader(_l.t('settings_section_preferences')),
              _settingsTile(
                icon: Icons.notifications_none_rounded,
                title: _l.t('settings_notifications'),
                subtitle: _l.t('settings_notifications_desc'),
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
                title: _l.t('settings_dark_mode'),
                subtitle: _l.t('settings_dark_mode_desc'),
                trailing: Switch(
                  value: _darkMode,
                  onChanged: (val) {
                    setState(() => _darkMode = val);
                    _updatePreference('pref_dark_mode', val);
                    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                  },
                  activeColor: AppTheme.primaryPurple,
                ),
              ),
              _settingsTile(
                icon: Icons.language_rounded,
                title: _l.t('settings_language'),
                subtitle: _selectedLanguage,
                onTap: () => _showLanguageDialog(),
              ),
              
              _sectionHeader(_l.t('settings_section_account')),
              _settingsTile(
                icon: Icons.person_outline,
                title: _l.t('settings_edit_profile'),
                onTap: () => _showEditProfileModal(userData),
              ),
              _settingsTile(
                icon: Icons.security_outlined,
                title: _l.t('settings_security'),
                subtitle: _l.t('settings_change_password'),
                onTap: () => _showChangePasswordModal(),
              ),
              
              _sectionHeader(_l.t('settings_section_legal')),
              _settingsTile(
                icon: Icons.description_outlined,
                title: _l.t('settings_terms'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
              ),
              _settingsTile(
                icon: Icons.privacy_tip_outlined,
                title: _l.t('settings_privacy'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
              ),
              
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextButton(
                  onPressed: () => _showDeleteAccountConfirm(),
                  child: Text(_l.t('settings_delete_account'), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
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
          color: AppTheme.adaptiveTextSecondary(context).withOpacity(0.7),
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
        color: AppTheme.surface(context),
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
            color: enabled ? AppTheme.adaptiveText(context) : AppTheme.adaptiveSubtle(context),
            fontSize: 15,
          )
        ),
        subtitle: subtitle != null 
          ? Text(subtitle, style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 12)) 
          : null,
        trailing: trailing ?? Icon(Icons.chevron_right, color: AppTheme.adaptiveTextSecondary(context).withOpacity(0.5), size: 20),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Widget _buildProfilePictureSection(String displayName, String email, String? photoURL) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
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
                      border: Border.all(color: AppTheme.surface(context), width: 2),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.adaptiveText(context)),
                ),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: AppTheme.adaptiveTextSecondary(context)),
                ),
                const SizedBox(height: 10),
                Text(
                  _l.t('settings_tap_to_update_photo'),
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
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_l.t('drawer_profile_photo'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.adaptiveText(context))),
              ),
              ListTile(
                leading: Icon(Icons.image_outlined, color: AppTheme.adaptiveText(context)),
                title: Text(_l.t('drawer_upload_gallery'), style: TextStyle(color: AppTheme.adaptiveText(context))),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (photoURL != null && photoURL.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text(_l.t('drawer_remove_photo'), style: const TextStyle(color: Colors.redAccent)),
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
            message: _l.t('drawer_photo_updated'));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        GlassmorphicEffects.showGlassSnackBar(context,
            message: AppErrorHandler.profileError(e), isError: true);
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
          decoration: BoxDecoration(
            color: AppTheme.background(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Text(_l.t('settings_edit_profile'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.adaptiveText(context))),
              const SizedBox(height: 24),
              _buildEditField(Icons.person_outline, _l.t('drawer_display_name'), nameController),
              const SizedBox(height: 16),
              _buildEditField(Icons.alternate_email, _l.t('drawer_username'), usernameController),
              const SizedBox(height: 16),
              _buildEditField(Icons.info_outline, _l.t('drawer_bio'), bioController, maxLines: 3),
              const SizedBox(height: 16),
              _buildEditField(Icons.phone_android_outlined, _l.t('phone_number'), phoneController),
              const SizedBox(height: 16),
              _buildEditField(Icons.email_outlined, _l.t('email_label'), emailController),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: GlassmorphicEffects.gradientButton(
                  text: _l.t('drawer_save_changes'),
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
                        GlassmorphicEffects.showGlassSnackBar(context, message: _l.t('settings_profile_updated_success'));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setModalState(() => isLoading = false);
                        GlassmorphicEffects.showGlassSnackBar(context, message: AppErrorHandler.profileError(e), isError: true);
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
      style: TextStyle(color: AppTheme.adaptiveText(context), fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
        prefixIcon: Icon(icon, color: AppTheme.primaryPurple, size: 20),
        filled: true,
        fillColor: AppTheme.surfaceColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showChangePasswordModal() {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.adaptiveSubtle(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(_l.t('settings_change_password_title'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: AppTheme.adaptiveText(context))),
                const SizedBox(height: 20),
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                _passwordField(ctx, currentPasswordCtrl, _l.t('settings_current_password'), Icons.lock_outline),
                const SizedBox(height: 12),
                _passwordField(ctx, newPasswordCtrl, _l.t('settings_new_password'), Icons.lock_reset_outlined),
                const SizedBox(height: 12),
                _passwordField(ctx, confirmPasswordCtrl, _l.t('settings_confirm_new_password'), Icons.lock_outline),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      final current = currentPasswordCtrl.text.trim();
                      final newPass = newPasswordCtrl.text.trim();
                      final confirm = confirmPasswordCtrl.text.trim();

                      if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                        setModalState(() => errorMessage = _l.t('settings_fields_required'));
                        return;
                      }
                      if (newPass.length < 6) {
                        setModalState(() => errorMessage = _l.t('settings_password_too_short'));
                        return;
                      }
                      if (newPass != confirm) {
                        setModalState(() => errorMessage = _l.t('settings_passwords_mismatch'));
                        return;
                      }

                      setModalState(() { isLoading = true; errorMessage = null; });

                      try {
                        final user = _authService.currentUser;
                        if (user == null || user.email == null) throw Exception('Not logged in');

                        // Re-authenticate then update password
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: current,
                        );
                        await user.reauthenticateWithCredential(credential);
                        await user.updatePassword(newPass);

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_l.t('settings_password_updated')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        String msg = AppErrorHandler.profileError(e);
                        setModalState(() { isLoading = false; errorMessage = msg; });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_l.t('settings_update_password_button'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField(BuildContext ctx, TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: TextStyle(color: AppTheme.adaptiveText(ctx)),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppTheme.adaptiveTextSecondary(ctx), size: 20),
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(ctx)),
        filled: true,
        fillColor: AppTheme.surfaceColor(ctx),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = [
      {'name': 'English', 'code': 'en'},
      {'name': 'Filipino', 'code': 'fil'},
      {'name': 'Spanish', 'code': 'es'},
      {'name': 'French', 'code': 'fr'},
      {'name': 'German', 'code': 'de'},
      {'name': 'Japanese', 'code': 'ja'},
      {'name': 'Korean', 'code': 'ko'},
      {'name': 'Chinese', 'code': 'zh'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.adaptiveSubtle(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(_l.t('settings_select_language'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppTheme.adaptiveText(context))),
              ),
              const Divider(height: 1),
              ...languages.map((lang) => ListTile(
                leading: Icon(Icons.language, color: AppTheme.primaryPurple, size: 20),
                title: Text(lang['name']!,
                    style: TextStyle(color: AppTheme.adaptiveText(context))),
                trailing: _selectedLanguage == lang['name']
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryPurple)
                    : null,
                onTap: () {
                  setState(() => _selectedLanguage = lang['name']!);
                  _updatePreference('pref_language', lang['name']!);
                  AppLocalizations.instance.setLanguage(lang['code']!);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.instance.t('settings_language') + 
                        ': ${lang['name']}'),
                      backgroundColor: AppTheme.primaryPurple,
                    ),
                  );
                },
              )),
              const SizedBox(height: 8),
            ],
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
          backgroundColor: AppTheme.surface(context),
          title: Text(_l.t('drawer_confirm_logout_title'), style: TextStyle(color: AppTheme.adaptiveText(context))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_l.t('drawer_confirm_logout_msg'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context))),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(_l.t('drawer_save_account'), style: TextStyle(fontSize: 14, color: AppTheme.adaptiveText(context))),
                value: saveAccount,
                activeColor: AppTheme.primaryPurple,
                onChanged: (val) => setDialogState(() => saveAccount = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_l.t('cancel'))),
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
              child: Text(_l.t('drawer_logout'), style: const TextStyle(color: Colors.redAccent)),
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
        backgroundColor: AppTheme.surface(context),
        title: Text(_l.t('settings_delete_account_title'), style: TextStyle(color: AppTheme.adaptiveText(context))),
        content: Text(_l.t('settings_delete_account_msg'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_l.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}