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

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});
  
  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
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
                  
                  const SizedBox(height: 24),
                  
                  // Menu items
                  _buildMenuSection(context),
                  
                  const SizedBox(height: 24),
                  
                  // Switch Account Button (NEW)
                  _buildSwitchAccountButton(context, authService),
                  
                  const SizedBox(height: 12),
                  
                  // Logout button
                  _buildLogoutButton(context, authService, userData),
                  
                  const SizedBox(height: 40),
                  
                  // App version
                  _buildAppVersion(),
                  
                  const SizedBox(height: 100), // Space for bottom nav
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
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
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
          
          const SizedBox(height: 12),
          
          // Display Name
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Username
          if (username.isNotEmpty)
            Text(
              '@$username',
              style: const TextStyle(
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'My Profile',
            onTap: () => Navigator.push(context, SlidePageRoute(page: const ProfileScreen())),
          ),
          _buildMenuItem(
            icon: Icons.group_outlined,
            title: 'Kakonek Center',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KakonekCenterScreen())),
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _buildMenuItem(
            icon: Icons.bug_report_outlined,
            title: 'Report a Problem',
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
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitchAccountButton(
    BuildContext context, 
    AuthService authService
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          icon: const Icon(
            Icons.swap_horiz,
            color: AppTheme.primaryPurple,
          ),
          label: const Text(
            'Switch Account',
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

  Future<void> _showSwitchAccountDialog(
    BuildContext context,
    AuthService authService,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('saved_accounts');
    
    if (accountsJson == null || accountsJson.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved accounts found'),
        ),
      );
      return;
    }
    
    final List<dynamic> decoded = jsonDecode(accountsJson);
    final savedAccounts = decoded.cast<Map<String, dynamic>>();
    final currentEmail = authService.currentUser?.email;
    
    // Remove current account from list
    final otherAccounts = savedAccounts
      .where((acc) => acc['email'] != currentEmail)
      .toList();
    
    if (otherAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other accounts to switch to'),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Switch Account',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: otherAccounts.length,
            itemBuilder: (context, index) {
              final account = otherAccounts[index];
              return _buildAccountListItem(
                context, 
                account, 
                authService
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
      leading: UserPhotoWidget(
        userId: account['uid'] ?? '',
        radius: 20,
      ),
      title: Text(
        account['displayName'] ?? 'User',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        account['email'] ?? '',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final email = account['email'];
      final password = account['password'];
      final provider = account['provider'];
      
      await authService.signOut();
      
      if (provider == 'google') {
        final credential = await authService.signInWithGoogle();
        if (credential != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('temp_provider', 'google');
          await prefs.remove('temp_password');
        }
      } else if (password != null) {
        await authService.signInWithEmail(email, password);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('temp_password', password);
        await prefs.setString('temp_provider', 'email');
      }
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        // StreamBuilder in main.dart will automatically switch to MainScreen
        // when it detects the new auth state. No manual push needed.
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch: $e')),
        );
      }
    }
  }

  Widget _buildLogoutButton(BuildContext context, AuthService authService, Map<String, dynamic> userData) {
    bool saveAccount = true;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (dialogContext) => StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                  backgroundColor: AppTheme.surfaceDark,
                  title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Are you sure you want to log out?'),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Save account on this device', style: TextStyle(fontSize: 14)),
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
                      child: const Text('Cancel'),
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
                      child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
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
          icon: const Icon(Icons.logout),
          label: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return Text(
      'Konek v1.0.0',
      style: TextStyle(
        fontSize: 12,
        color: AppTheme.textSecondary.withOpacity(0.3),
      ),
    );
  }
}
