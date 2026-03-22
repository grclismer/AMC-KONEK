import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import '../theme/animations.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

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

  void _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      GlassmorphicEffects.showGlassSnackBar(context, message: 'Please fill in all fields', isError: true);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      GlassmorphicEffects.showGlassSnackBar(context, message: 'Passwords do not match', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signUpWithEmail(_emailController.text, _passwordController.text, _nameController.text);
      if (mounted) {
        Navigator.pop(context);
        GlassmorphicEffects.showGlassSnackBar(context, message: 'Account created successfully! Please log in.', icon: Icons.check_circle_outline);
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeInStaggered(
                  index: 0,
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                    child: const Icon(Icons.person_add_rounded, size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                const FadeInStaggered(
                  index: 1,
                  child: Text(
                    'Create Account',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 8),
                const FadeInStaggered(
                  index: 2,
                  child: Text(
                    'Join the KONEK community',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 40),
                
                _buildField(index: 3, controller: _nameController, hint: 'Full Name', icon: Icons.person_outline),
                const SizedBox(height: 16),
                _buildField(index: 4, controller: _emailController, hint: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildField(index: 5, controller: _passwordController, hint: 'Password', icon: Icons.lock_outline, obscureText: _obscurePassword, isPassword: true),
                const SizedBox(height: 16),
                _buildField(index: 6, controller: _confirmPasswordController, hint: 'Confirm Password', icon: Icons.lock_reset_rounded, obscureText: _obscurePassword),
                
                const SizedBox(height: 32),
                FadeInStaggered(
                  index: 7,
                  child: BounceClick(
                    onTap: _signUp,
                    child: GlassmorphicEffects.gradientButton(
                      text: 'Sign Up',
                      height: 52,
                      isLoading: _isLoading,
                      onPressed: _signUp,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.textSecondary),
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textSecondary),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          ),
        ),
      ),
    );
  }
}
