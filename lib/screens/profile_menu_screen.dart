import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import 'profile_screen.dart';
import 'kakonek_center_screen.dart';
import 'settings_screen.dart';
import 'report_problem_screen.dart';
import '../widgets/user_photo_widget.dart';
import '../utils/error_handler.dart';
import '../utils/app_localizations.dart';

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});
  
  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  AppLocalizations get _l => AppLocalizations.instance;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: authService.getUserDataStream(),
          builder: (context, snapshot) {
            final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final currentUser = authService.currentUser;
            
            final displayName = userData['displayName'] ?? 
                              currentUser?.displayName ?? 
                              'User';
            final username = userData['username'] ?? 
                           currentUser?.email?.split('@')[0] ?? 
                           '';
            final photoURL = userData['photoURL'] ?? 
                           currentUser?.photoURL;
            
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Header with user info
                  _buildHeader(context, displayName, username, photoURL, authService),
                  
                  SizedBox(height: 24),
                  
                  // Menu items
                  _buildMenuSection(context),
                  
                  SizedBox(height: 24),
                  
                  // Switch Account Button (NEW)
                  _buildSwitchAccountButton(context, authService),
                  
                  SizedBox(height: 12),
                  
                  // Logout button
                  _buildLogoutButton(context, authService, userData),
                  
                  SizedBox(height: 40),
                  
                  // App version
                  _buildAppVersion(),
                  
                  SizedBox(height: 100), // Space for bottom nav
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, 
    String displayName, 
    String username, 
    String? photoURL,
    AuthService authService
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Profile picture with UserPhotoWidget
          UserPhotoWidget(
            userId: authService.currentUser?.uid ?? '',
            radius: 45,
            showBorder: true,
            borderColor: Colors.white,
            borderWidth: 3,
          ),
          
          SizedBox(height: 12),
          
          // Display Name
          Text(
            displayName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: 4),
          
          // Username
          if (username.isNotEmpty)
            Text(
              '@$username',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.adaptiveText(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.person_outline,
            title: _l.t('nav_me'),
            onTap: () => Navigator.push(context, SlidePageRoute(page: ProfileScreen())),
          ),
          _buildMenuItem(
            icon: Icons.group_outlined,
            title: _l.t('menu_kakonek_center'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KakonekCenterScreen())),
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: _l.t('menu_settings'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _buildMenuItem(
            icon: Icons.bug_report_outlined,
            title: _l.t('menu_report_problem'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportProblemScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.adaptiveText(context)),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppTheme.adaptiveText(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: AppTheme.adaptiveSubtle(context), size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitchAccountButton(
    BuildContext context, 
    AuthService authService
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => _showSwitchAccountDialog(context, authService),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: AppTheme.primaryPurple.withOpacity(0.5),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(
            Icons.swap_horiz,
            color: AppTheme.primaryPurple,
          ),
          label: Text(
            _l.t('menu_switch_account'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryPurple,
            ),
          ),
        ),
      ),
    );
  }

  void _showSwitchAccountDialog(
    BuildContext context,
    AuthService authService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        title: Text(
          _l.t('menu_switch_account'),
          style: TextStyle(color: AppTheme.adaptiveText(context)),
        ),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadOtherAccounts(authService.currentUser?.email),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final otherAccounts = snapshot.data!;
            if (otherAccounts.isEmpty) {
              return Text(_l.t('menu_no_other_accounts'),
                style: TextStyle(color: AppTheme.adaptiveTextSecondary(context)));
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: otherAccounts.length,
                itemBuilder: (context, index) =>
                  _buildAccountListItem(context, otherAccounts[index], authService),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l.t('cancel')),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountListItem(
    BuildContext context,
    Map<String, dynamic> account,
    AuthService authService,
  ) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[800],
        backgroundImage: _getAccountImage(account['photoURL']),
        child: _getAccountImage(account['photoURL']) == null
            ? Icon(Icons.person, size: 20, color: Colors.grey)
            : null,
      ),
      title: Text(
        account['displayName'] ?? 'User',
        style: TextStyle(color: AppTheme.adaptiveText(context)),
      ),
      subtitle: Text(
        account['email'] ?? '',
        style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 12),
      ),
      onTap: () {
        Navigator.pop(context); // Close dialog
        _switchAccount(context, account, authService);
      },
    );
  }

  Future<void> _switchAccount(
    BuildContext context,
    Map<String, dynamic> account,
    AuthService authService
  ) async {
    final email = account['email'];
    final password = account['password'];
    final provider = account['provider'];

    // Show inline loading snackbar instead of dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(_l.t('menu_switching_account')),
          ],
        ),
        duration: Duration(seconds: 10),
        backgroundColor: Colors.black87,
      ),
    );


    try {
      await authService.signOut();
      // Let auth state settle before signing in
      await Future.delayed(const Duration(milliseconds: 400));

      if (provider == 'google') {
        final credential = await authService.signInWithGoogle();
        if (credential != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('temp_provider', 'google');
          await prefs.remove('temp_password');
        }
      } else if (password != null && password.toString().isNotEmpty) {
        await authService.signInWithEmail(email, password);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('temp_password', password);
        await prefs.setString('temp_provider', 'email');
      }
      // main.dart StreamBuilder handles navigation automatically
      // No Navigator.pop needed — no dialog was pushed

    } catch (e) {
      // ScaffoldMessenger may be gone after signOut rebuilds tree, so guard it
      try {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.switchError(e)),
            backgroundColor: Colors.red,
          ),
        );
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> _loadOtherAccounts(String? currentEmail) async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('saved_accounts');
    if (accountsJson == null || accountsJson.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      return decoded
        .cast<Map<String, dynamic>>()
        .where((acc) => acc['email'] != currentEmail)
        .toList();
    } catch (_) {
      return [];
    }
  }

  ImageProvider? _getAccountImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try { return MemoryImage(base64Decode(url.split(',').last)); } catch (_) { return null; }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  Widget _buildLogoutButton(BuildContext context, AuthService authService, Map<String, dynamic> userData) {
    bool saveAccount = true;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (dialogContext) => StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                  backgroundColor: AppTheme.surface(context),
                  title: Text(_l.t('menu_logout_confirm'), style: TextStyle(color: AppTheme.adaptiveText(context))),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_l.t('menu_logout_message')),
                      SizedBox(height: 16),
                      CheckboxListTile(
                        title: Text(_l.t('menu_save_account'), style: TextStyle(fontSize: 14)),
                        value: saveAccount,
                        onChanged: (val) {
                          setDialogState(() => saveAccount = val!);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(_l.t('cancel')),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final currentUser = authService.currentUser;
                          
                          if (saveAccount) {
                            final currentEmail = userData['email'] ?? currentUser?.email ?? '';
                            final accountData = <String, dynamic>{
                              'uid': currentUser?.uid ?? '',
                              'email': currentEmail,
                              'displayName': userData['displayName'] ?? currentUser?.displayName ?? '',
                              'username': userData['username'] ?? '',
                              'photoURL': userData['photoURL'] ?? currentUser?.photoURL ?? '',
                              'provider': prefs.getString('temp_provider') ?? 'email',
                            };
                            
                            final tempPass = prefs.getString('temp_password');
                            if (tempPass != null) accountData['password'] = tempPass;

                            final accountsJson = prefs.getString('saved_accounts') ?? '[]';
                            final List<dynamic> decoded = jsonDecode(accountsJson);
                            final accounts = decoded.cast<Map<String, dynamic>>();
                            
                            accounts.removeWhere((acc) => acc['email'] == currentEmail);
                            accounts.insert(0, accountData);
                            if (accounts.length > 5) accounts.removeRange(5, accounts.length);
                            
                            await prefs.setString('saved_accounts', jsonEncode(accounts));
                          }
                          
                          Navigator.pop(dialogContext);
                          await authService.signOut();
                        } catch (e) {
                          debugPrint('Logout error: $e');
                        }
                      },
                      child: Text(_l.t('menu_logout'), style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
            foregroundColor: Colors.red,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.withOpacity(0.2)),
            ),
          ),
          icon: Icon(Icons.logout),
          label: Text(_l.t('menu_logout'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return Text(
      'Konek v1.0.0',
      style: TextStyle(
        fontSize: 12,
        color: AppTheme.adaptiveTextSecondary(context).withOpacity(0.3),
      ),
    );
  }
}
