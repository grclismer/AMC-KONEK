import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import '../theme/animations.dart';
import '../utils/error_handler.dart';
import '../utils/app_localizations.dart';

class SignUpScreen extends StatefulWidget {
  SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  AppLocalizations get _l => AppLocalizations.instance;

  void _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      GlassmorphicEffects.showGlassSnackBar(context, message: _l.t('login_fill_fields'), isError: true);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      GlassmorphicEffects.showGlassSnackBar(context, message: _l.t('signup_password_mismatch'), isError: true);
      return;
    }
    if (_passwordController.text.length < 6) {
      GlassmorphicEffects.showGlassSnackBar(context, 
        message: _l.t('signup_password_short'), isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signUpWithEmail(_emailController.text, _passwordController.text, _nameController.text);
      if (mounted) {
        Navigator.pop(context);
        GlassmorphicEffects.showGlassSnackBar(context, message: _l.t('signup_success'), icon: Icons.check_circle_outline);
      }
    } catch (e) {
      if (mounted) {
        GlassmorphicEffects.showGlassSnackBar(context, message: AppErrorHandler.authError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BounceClick(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.adaptiveText(context)),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeInStaggered(
                  index: 0,
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                    child: Icon(Icons.person_add_rounded, size: 80, color: Colors.white),
                  ),
                ),
                SizedBox(height: 24),
                FadeInStaggered(
                  index: 1,
                  child: Text(
                    _l.t('signup_title'),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.adaptiveText(context), letterSpacing: 1.2),
                  ),
                ),
                SizedBox(height: 8),
                FadeInStaggered(
                  index: 2,
                  child: Text(
                    _l.t('signup_subtitle'),
                    style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 16),
                  ),
                ),
                SizedBox(height: 40),
                
                _buildField(index: 3, controller: _nameController, hint: _l.t('signup_name_hint'), icon: Icons.person_outline),
                SizedBox(height: 16),
                _buildField(index: 4, controller: _emailController, hint: _l.t('signup_email_hint'), icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                SizedBox(height: 16),
                _buildField(index: 5, controller: _passwordController, hint: _l.t('login_password_hint'), icon: Icons.lock_outline, obscureText: _obscurePassword, isPassword: true),
                SizedBox(height: 16),
                _buildField(index: 6, controller: _confirmPasswordController, hint: _l.t('signup_confirm_password_hint'), icon: Icons.lock_reset_rounded, obscureText: _obscurePassword),
                
                SizedBox(height: 32),
                FadeInStaggered(
                  index: 7,
                  child: BounceClick(
                    onTap: _signUp,
                    child: GlassmorphicEffects.gradientButton(
                      text: _l.t('signup_button'),
                      height: 52,
                      isLoading: _isLoading,
                      onPressed: _signUp,
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required int index,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return FadeInStaggered(
      index: index,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(color: AppTheme.adaptiveText(context)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.adaptiveTextSecondary(context)),
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.adaptiveTextSecondary(context)),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          ),
        ),
      ),
    );
  }
}
