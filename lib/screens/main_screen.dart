import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'home_page.dart';
import 'reels_page.dart';
import 'messages_screen.dart';
import 'profile_menu_screen.dart';
import '../widgets/create_post_modal.dart';
import '../widgets/profile_completion_modal.dart';
import '../services/auth_service.dart';
import '../widgets/user_photo_widget.dart';
import '../utils/app_localizations.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final GlobalKey<ReelsPageState> _reelsKey = GlobalKey<ReelsPageState>();
  AppLocalizations get _l => AppLocalizations.instance;

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();

    // Ensure Reels are silenced on app start since Home is the initial tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reelsKey.currentState?.setTabActive(false);
    });
  }

  void _checkProfileCompletion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = _authService.currentUser;
      if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (context) => const ProfileCompletionModal(),
        );
      }
    });
  }

  void _showCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreatePostModal(),
    );
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      print('🔊 MainScreen: Tab switching, toggling Reels active state: ${index == 1}');
      _reelsKey.currentState?.setTabActive(index == 1);
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return HomePage();
      case 1: return ReelsPage(key: _reelsKey);
      case 2: return MessagesScreen();
      case 3: return ProfileMenuScreen();
      default: return HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 85 + MediaQuery.of(context).padding.bottom,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
              left: 8,
              right: 8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surface(context).withOpacity(0.7),
              border: Border(
                top: BorderSide(
                  color: AppTheme.adaptiveSubtle(context),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: _l.t('nav_home'),
                  isActive: _selectedIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _NavItem(
                  icon: Icons.play_circle_fill_rounded,
                  label: _l.t('nav_reels'),
                  isActive: _selectedIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                
                // CENTER CREATE POST BUTTON
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: _showCreatePostModal,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: AppTheme.adaptiveText(context),
                        size: 32,
                      ),
                    ),
                  ),
                ),

                _NavItem(
                  icon: Icons.chat_bubble_rounded,
                  label: _l.t('nav_messages'),
                  isActive: _selectedIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
                
                // USER PROFILE AVATAR NAV ITEM
                _buildProfileNavItem(
                  isActive: _selectedIndex == 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileNavItem({required bool isActive}) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return SizedBox.shrink();

    return GestureDetector(
      onTap: () => _onItemTapped(3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserPhotoWidget(
            userId: currentUser.uid,
            radius: 12,
            showBorder: isActive,
            borderGradient: isActive ? AppTheme.primaryGradient : null,
            borderWidth: 1.5,
          ),
          SizedBox(height: 4),
          Text(
            _l.t('nav_me'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppTheme.primaryPurple : AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryPurple.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? AppTheme.primaryPurple : AppTheme.textSecondaryColor(context),
              size: 26,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppTheme.primaryPurple : AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
