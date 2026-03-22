import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import '../theme/animations.dart';
import '../widgets/user_photo_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<List<Map<String, dynamic>>> _getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString('saved_accounts');
    
    if (accountsJson == null || accountsJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> _removeSavedAccount(Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await _getSavedAccounts();
    accounts.removeWhere((acc) => acc['email'] == account['email']);
    await prefs.setString('saved_accounts', jsonEncode(accounts));
    setState(() {}); // Refereshes FutureBuilder
  }

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      GlassmorphicEffects.showGlassSnackBar(context, message: 'Please fill in all fields', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(_emailController.text, _passwordController.text);
      if (!mounted) return;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('temp_password', _passwordController.text);
      await prefs.setString('temp_provider', 'email');
      // StreamBuilder in main.dart will handle navigation
      // when it detects authStateChanges()
    } catch (e) {
      if (mounted) {
        GlassmorphicEffects.showGlassSnackBar(context, message: 'Login Failed: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('temp_provider', 'google');
        await prefs.remove('temp_password');
        await prefs.remove('temp_password');
        // StreamBuilder in main.dart will handle navigation
      }
    } catch (e) {
      if (mounted) {
        GlassmorphicEffects.showGlassSnackBar(context, message: 'Google Sign-In Failed: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GradientUtils.gradientText(
                  child: const Text(
                    'KONEK',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getSavedAccounts(),
                  builder: (context, snapshot) {
                    // Filter only accounts with a valid uid
                    final savedAccounts = (snapshot.data ?? [])
                        .where((acc) => acc['uid'] != null && acc['uid'].toString().isNotEmpty)
                        .toList();
                    
                    if (savedAccounts.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    return Column(
                      children: [
                        const Text(
                          'Continue as saved account',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        SizedBox(
                          height: 110,
                          child: Center(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              itemCount: savedAccounts.length,
                              itemBuilder: (context, index) {
                                final account = savedAccounts[index];
                                return _buildSavedAccountItem(account);
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        const Text("— or sign in —", style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),

                FadeInStaggered(
                  index: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark, 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                        hintText: '@username or email',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                FadeInStaggered(
                  index: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark, 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textSecondary),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
 
                FadeInStaggered(
                  index: 3,
                  child: BounceClick(
                    onTap: _login,
                    child: GlassmorphicEffects.gradientButton(
                      text: 'Log In',
                      height: 52,
                      isLoading: _isLoading,
                      onPressed: _login,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text('Forgot password?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    ),
                    const Text(' • ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.push(context, SlidePageRoute(page: const SignUpScreen())),
                      child: const Text('Create account', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                FadeInStaggered(
                  index: 4,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: BounceClick(
                      onTap: _isLoading ? null : _loginWithGoogle,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _loginWithGoogle,
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.white),
                        label: const Text('Continue with Google', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedAccountItem(Map<String, dynamic> account) {
    return GestureDetector(
      onTap: () => _loginWithSavedAccount(account),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('Remove account?', style: TextStyle(color: Colors.white)),
            content: Text('Remove ${account['email']} from saved accounts?', style: const TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _removeSavedAccount(account);
                },
                child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            UserPhotoWidget(
              userId: account['uid'] ?? '',
              radius: 32,
              showBorder: true,
              borderGradient: AppTheme.primaryGradient,
              borderWidth: 2,
            ),
            const SizedBox(height: 8),
            Text(
              account['username'] ?? 
              account['displayName'] ?? 
              account['email']?.split('@')[0] ?? 
              'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginWithSavedAccount(Map<String, dynamic> account) async {
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
      
      if (provider == 'google') {
        final credential = await _authService.signInWithGoogle();
        if (credential != null && mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('temp_provider', 'google');
          await prefs.remove('temp_password');
        }
      } else if (password != null && password.isNotEmpty) {
        await _authService.signInWithEmail(email, password);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('temp_password', password);
        await prefs.setString('temp_provider', 'email');
      } else {
        if (mounted) {
          Navigator.pop(context); // Close loading
          _showPasswordDialog(email);
          return;
        }
      }
      
      if (mounted) {
        Navigator.pop(context); // Close loading
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        GlassmorphicEffects.showGlassSnackBar(context, message: 'Login failed: $e', isError: true);
      }
    }
  }

  void _showPasswordDialog(String email) {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Enter Password',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Password',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) return;
              
              Navigator.pop(context); // Close dialog
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              try {
                await _authService.signInWithEmail(email, password);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('temp_password', password);
                await prefs.setString('temp_provider', 'email');
                
                if (mounted) {
                  Navigator.pop(context); // Close loading
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  GlassmorphicEffects.showGlassSnackBar(context, message: 'Login failed: $e', isError: true);
                }
              }
            },
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }
}
