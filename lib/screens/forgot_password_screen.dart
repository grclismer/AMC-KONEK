import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import '../theme/animations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _resetPassword() async {
    if (_emailController.text.isEmpty) {
      GlassmorphicEffects.showGlassSnackBar(context, message: 'Please enter your email', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(_emailController.text);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('Email Sent', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Check your inbox for password reset instructions.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK', style: TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        GlassmorphicEffects.showGlassSnackBar(context, message: e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BounceClick(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInStaggered(
                index: 0,
                child: ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: const Icon(Icons.lock_reset_rounded, size: 80, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const FadeInStaggered(
                index: 1,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              FadeInStaggered(
                index: 2,
                child: Text(
                  'Enter your email address and we\'ll send you instructions to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ),
              const SizedBox(height: 48),
              
              FadeInStaggered(
                index: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                      hintText: 'Email Address',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              FadeInStaggered(
                index: 4,
                child: BounceClick(
                  onTap: _resetPassword,
                  child: GlassmorphicEffects.gradientButton(
                    text: 'Send Reset Link',
                    height: 52,
                    isLoading: _isLoading,
                    onPressed: _resetPassword,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
