import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';

class ProfileCompletionModal extends StatefulWidget {
  const ProfileCompletionModal({super.key});

  @override
  State<ProfileCompletionModal> createState() => _ProfileCompletionModalState();
}

class _ProfileCompletionModalState extends State<ProfileCompletionModal> {
  final _usernameController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _completeProfile() async {
    if (_usernameController.text.trim().isEmpty) {
      GlassmorphicEffects.showGlassSnackBar(context, message: 'Please enter a username', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final username = _usernameController.text.trim();
      
      // Update Firebase Auth
      final user = _authService.currentUser;
      if (user != null) {
        await user.updateDisplayName(username);
        await user.reload();
      }

      // Update Firestore
      await _authService.saveUserData({
        'username': username,
        'displayName': username,
        'hasCompletedProfile': true,
      });

      if (mounted) {
        Navigator.pop(context);
        GlassmorphicEffects.showGlassSnackBar(context, message: 'Profile completed! Welcome, $username', icon: Icons.celebration_rounded);
      }
    } catch (e) {
      if (mounted) {
        GlassmorphicEffects.showGlassSnackBar(context, message: 'Failed to update: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent closing without completing
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: const Icon(Icons.stars_rounded, size: 64, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set a username to start sharing with the community.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLighter.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: TextField(
                    controller: _usernameController,
                    style: TextStyle(color: AppTheme.adaptiveText(context)),
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.alternate_email_rounded, color: AppTheme.adaptiveTextSecondary(context)),
                      hintText: 'Username',
                      hintStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GlassmorphicEffects.gradientButton(
                    text: 'Save & Continue',
                    isLoading: _isLoading,
                    onPressed: _completeProfile,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
