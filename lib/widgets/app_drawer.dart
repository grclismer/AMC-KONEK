import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/saved_posts_screen.dart';
import '../screens/kakonek_center_screen.dart';
import '../screens/report_problem_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import '../theme/animations.dart';
import '../widgets/user_photo_widget.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  bool _saveAccount = false;

  void _confirmLogout(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    
    final accountsJson = prefs.getString('saved_accounts');
    List<Map<String, dynamic>> savedAccounts = [];
    if (accountsJson != null && accountsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(accountsJson);
        savedAccounts = decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    
    final currentEmail = _authService.currentUser?.email ?? userData['email'] ?? '';
    final isAlreadySaved = savedAccounts.any((acc) => acc['email'] == currentEmail);
    _saveAccount = isAlreadySaved;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to log out of your account?'),
              const SizedBox(height: 16),
              if (!isAlreadySaved)
                CheckboxListTile(
                  title: const Text('Save account on this device', style: TextStyle(fontSize: 14, color: Colors.white)),
                  value: _saveAccount,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primaryPurple,
                  checkColor: Colors.white,
                  onChanged: (val) {
                    setDialogState(() => _saveAccount = val!);
                  },
                ),
              if (isAlreadySaved)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Your account is saved on this device.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))
            ),
            BounceClick(
              onTap: () {}, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: () async {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final currentEmail = userData['email'] ?? _authService.currentUser?.email ?? '';
                    final accountsJson = prefs.getString('saved_accounts') ?? '[]';
                    List<dynamic> accounts = [];
                    try {
                      accounts = jsonDecode(accountsJson);
                    } catch (_) {}

                    if (_saveAccount) {
                      final newAccount = {
                        'uid': _authService.currentUser?.uid ?? '',
                        'email': currentEmail,
                        'displayName': userData['displayName'] ?? _authService.currentUser?.displayName ?? '',
                        'username': userData['username'] ?? '',
                        'photoURL': userData['photoURL'] ?? _authService.currentUser?.photoURL ?? '',
                        'provider': prefs.getString('temp_provider') ?? 'email',
                      };
                      
                      final tempPass = prefs.getString('temp_password');
                      if (tempPass != null && tempPass.isNotEmpty) {
                        newAccount['password'] = tempPass;
                      }
                      
                      accounts.removeWhere((acc) => acc['email'] == currentEmail);
                      accounts.insert(0, newAccount);
                      if (accounts.length > 5) accounts.removeRange(5, accounts.length);
                      await prefs.setString('saved_accounts', jsonEncode(accounts));
                    } else {
                      accounts.removeWhere((acc) => acc['email'] == currentEmail);
                      await prefs.setString('saved_accounts', jsonEncode(accounts));
                    }
                    
                    await prefs.remove('temp_password');
                    await prefs.remove('temp_provider');
                    
                    Navigator.of(dialogContext).pop();
                    try {
                      await _authService.signOut();
                    } catch (e) {
                      debugPrint('Signout error: $e');
                    }
                  } catch (e) {
                    debugPrint('Logout error: $e');
                  }
                },
                child: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadImage(Map<String, dynamic> userData) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 50, 
      maxWidth: 400, 
      maxHeight: 400
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await _authService.saveUserData({'photoURL': base64Image});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated')));
      }
    }
  }

  void _removeImage(Map<String, dynamic> userData) async {
    await _authService.saveUserData({'photoURL': ''});
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture removed')));
    }
  }

  void _showImageOptions(Map<String, dynamic> userData, String? photoURL) {
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
                  _uploadImage(userData);
                },
              ),
              if (photoURL != null && photoURL.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage(userData);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileModal(Map<String, dynamic> userData) {
    final nameController = TextEditingController(text: userData['displayName'] ?? '');
    final usernameController = TextEditingController(text: userData['username'] ?? '');
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
                        'bio': bioController.text.trim(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setModalState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: Colors.orange, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _authService.getUserDataStream(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final displayName = userData['displayName'] ??
            _authService.currentUser?.displayName ??
            _authService.currentUser?.email?.split('@')[0] ??
            "Guest";
        final username = userData['username'] ?? _authService.currentUser?.email?.split('@')[0] ?? '';
        final photoURL = userData['photoURL'] ?? _authService.currentUser?.photoURL;

        return Theme(
          data: AppTheme.darkTheme(),
          child: Drawer(
            backgroundColor: AppTheme.backgroundDark,
            child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showImageOptions(userData, photoURL),
                          child: UserPhotoWidget(
                            userId: _authService.currentUser?.uid ?? '',
                            radius: 35,
                            showBorder: true,
                            borderColor: Colors.white,
                            borderWidth: 2,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showImageOptions(userData, photoURL),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.orange, width: 1),
                              ),
                              child: const Icon(Icons.more_horiz, size: 14, color: Colors.orange),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (username.isNotEmpty)
                            Text(
                              "@$username",
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _showEditProfileModal(userData),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withOpacity(0.6)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text("Edit Profile", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text("Profile"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, SlidePageRoute(page: const ProfileScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text("Saved Posts"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPostsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text("Kakonek Center"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const KakonekCenterScreen()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text("Settings"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text("Report a Problem"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportProblemScreen()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Logout", style: TextStyle(color: Colors.red)),
                onTap: () => _confirmLogout(userData),
              ),
            ],
          ),
        ),
      );
    },
  );
}
}
