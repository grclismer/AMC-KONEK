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
import '../utils/error_handler.dart';
import '../utils/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  AppLocalizations get _l => AppLocalizations.instance;

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
      GlassmorphicEffects.showGlassSnackBar(context, message: _l.t('login_fill_fields'), isError: true);
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
        GlassmorphicEffects.showGlassSnackBar(context, message: AppErrorHandler.authError(e), isError: true);
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
        GlassmorphicEffects.showGlassSnackBar(context, message: AppErrorHandler.authError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ImageProvider? _getAccountImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) {
      return NetworkImage(url);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GradientUtils.gradientText(
                  child: Text(
                    'KONEK',
                    style: const TextStyle(color: Colors.white, letterSpacing: 2.0, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 48),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getSavedAccounts(),
                  builder: (context, snapshot) {
                    // Filter only accounts with a valid uid
                    final savedAccounts = (snapshot.data ?? [])
                        .where((acc) => acc['uid'] != null && acc['uid'].toString().isNotEmpty)
                        .toList();
                    
                    if (savedAccounts.isEmpty) {
                      return SizedBox.shrink();
                    }
                    
                    return Column(
                      children: [
                        Text(
                          _l.t('login_continue_saved'),
                          style: TextStyle(
                            color: AppTheme.adaptiveTextSecondary(context),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 16),
                        
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
                        
                        SizedBox(height: 24),
                        Text("— ${_l.t('login_or_sign_in')} —", style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 14)),
                        SizedBox(height: 24),
                      ],
                    );
                  },
                ),

                FadeInStaggered(
                  index: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      style: TextStyle(color: AppTheme.adaptiveText(context)),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, color: AppTheme.adaptiveTextSecondary(context)),
                        hintText: _l.t('login_email_hint'),
                        hintStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                FadeInStaggered(
                  index: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: AppTheme.adaptiveText(context)),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.adaptiveTextSecondary(context)),
                        hintText: _l.t('login_password_hint'),
                        hintStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.adaptiveTextSecondary(context)),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),
 
                FadeInStaggered(
                  index: 3,
                  child: BounceClick(
                    onTap: _login,
                    child: GlassmorphicEffects.gradientButton(
                      text: _l.t('login_button'),
                      height: 52,
                      isLoading: _isLoading,
                      onPressed: _login,
                    ),
                  ),
                ),
                SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotPasswordScreen())),
                      child: Text(_l.t('login_forgot_password'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 14)),
                    ),
                    Text(' • ', style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.push(context, SlidePageRoute(page: SignUpScreen())),
                      child: Text(_l.t('login_create_account'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 14)),
                    ),
                  ],
                ),
                
                SizedBox(height: 32),
                FadeInStaggered(
                  index: 4,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: BounceClick(
                      onTap: _isLoading ? null : _loginWithGoogle,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _loginWithGoogle,
                        icon: Icon(Icons.g_mobiledata_rounded, size: 28, color: AppTheme.adaptiveText(context)),
                        label: Text(_l.t('login_google_button'), style: TextStyle(color: AppTheme.adaptiveText(context))),
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
            backgroundColor: AppTheme.surface(context),
            title: Text(_l.t('login_remove_confirm'), style: TextStyle(color: AppTheme.adaptiveText(context))),
            content: Text('${_l.t('login_remove_message')} ${account['email']}?', style: TextStyle(color: AppTheme.adaptiveTextSecondary(context))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(_l.t('cancel'))),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _removeSavedAccount(account);
                },
                child: Text(_l.t('remove'), style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 80,
        margin: EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey[800],
                backgroundImage: _getAccountImage(account['photoURL']),
                child: _getAccountImage(account['photoURL']) == null
                    ? Icon(Icons.person, size: 32, color: Colors.grey)
                    : null,
              ),
            ),
            SizedBox(height: 8),
            Text(
              account['username'] ?? 
              account['displayName'] ?? 
              account['email']?.split('@')[0] ?? 
              'User',
              style: TextStyle(
                color: AppTheme.adaptiveText(context),
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
        builder: (context) => Center(
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
        GlassmorphicEffects.showGlassSnackBar(context, message: AppErrorHandler.authError(e), isError: true);
      }
    }
  }

  void _showPasswordDialog(String email) {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        title: Text(
          _l.t('login_enter_password'),
          style: TextStyle(color: AppTheme.adaptiveText(context)),
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: TextStyle(color: AppTheme.adaptiveText(context)),
          decoration: InputDecoration(
            hintText: _l.t('login_password_hint'),
            hintStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l.t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) return;
              
              Navigator.pop(context); // Close dialog
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(child: CircularProgressIndicator()),
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
                  GlassmorphicEffects.showGlassSnackBar(context, message: AppErrorHandler.authError(e), isError: true);
                }
              }
            },
            child: Text(_l.t('login_button')),
          ),
        ],
      ),
    );
  }
}
