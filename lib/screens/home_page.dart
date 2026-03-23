import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../widgets/stories_bar.dart';
import '../widgets/post_widget.dart';
import 'notifications_screen.dart';
import '../services/auth_service.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/create_post_modal.dart';
import '../widgets/user_photo_widget.dart';
import '../widgets/friend_recommendations.dart';
import '../widgets/animated_search_bar.dart';
import '../widgets/search_results_view.dart';
import '../utils/app_localizations.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _unreadCount = 0;
  bool _notificationsEnabled = true;
  StreamSubscription? _notifSub;
  int _refreshKey = 0;
  final AuthService _authService = AuthService();
  AppLocalizations get _l => AppLocalizations.instance;

  @override
  void initState() {
    super.initState();
    _loadNotifPreference();
    _startNotifListener();
  }

  Future<void> _loadNotifPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _notificationsEnabled = prefs.getBool('pref_notifications') ?? true);
  }

  void _startNotifListener() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    _notifSub = FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .listen((snap) {
        if (mounted) setState(() => _unreadCount = snap.docs.length);
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadNotifPreference();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  bool _isDiscoverMode = false;
  bool _showingSearchResults = false;
  String _searchQuery = '';

  void _showCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(65),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surface(context).withOpacity(0.8),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.adaptiveSubtle(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: SizedBox(
                height: 65,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Konek Logo (Hidden when search expanded)
                    if (!_showingSearchResults)
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: Text(
                          "KONEK", 
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                      ),
                    
                    if (_showingSearchResults)
                      SizedBox(width: 8),

                    // Icons and Search
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedSearchBar(
                            hintText: _l.t('feed_search_people'),
                            onSearch: (query) {
                              setState(() => _searchQuery = query);
                            },
                            onExpanded: () {
                              setState(() => _showingSearchResults = true);
                            },
                            onCollapsed: () {
                              setState(() {
                                _showingSearchResults = false;
                                _searchQuery = '';
                              });
                            },
                          ),
                          if (!_showingSearchResults) ...[
                            SizedBox(width: 12),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _AnimatedIconBtn(
                                  icon: Icons.notifications_none_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    SlidePageRoute(page: NotificationsScreen()),
                                  ),
                                ),
                                if (_unreadCount > 0 && _notificationsEnabled)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryPurple.withOpacity(0.6),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$_unreadCount',
                                          style: TextStyle(
                                            color: AppTheme.adaptiveText(context),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: _showingSearchResults
          ? _buildSearchResultsView()
          : _buildFeedView(),
    );
  }

  Widget _buildSearchResultsView() {
    return SearchResultsView(query: _searchQuery);
  }

  Widget _buildFeedView() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 600),
        child: RefreshIndicator(
          backgroundColor: AppTheme.surface(context),
          color: AppTheme.primaryPurple,
          onRefresh: () async {
            setState(() => _refreshKey++);
          },
          child: ListView(
            children: [
              SizedBox(height: 8),
              StoriesBar(),
              SizedBox(height: 12),
              FriendRecommendations(),
              SizedBox(height: 12),

              // Feed Type Toggle
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFeedToggle(_l.t('feed_friends'), !_isDiscoverMode),
                    SizedBox(width: 12),
                    _buildFeedToggle(_l.t('feed_discover'), _isDiscoverMode),
                  ],
                ),
              ),

              // Create Post Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    UserPhotoWidget(
                      userId: _authService.currentUser?.uid ?? '',
                      radius: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showCreatePostModal,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor(context).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.borderColor(context)),
                          ),
                          child: Text(
                            _l.t('feed_whats_on_mind'),
                            style: TextStyle(color: AppTheme.adaptiveTextSecondary(context).withOpacity(0.6)),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _showCreatePostModal,
                      icon: Icon(Icons.image_outlined, color: Colors.green),
                    ),
                  ],
                ),
              ),

              Divider(color: AppTheme.adaptiveSubtle(context)),

              // Posts Stream
              StreamBuilder<List<Post>>(
                key: ValueKey(_refreshKey),
                stream: _isDiscoverMode 
                    ? PostService.instance.getDiscoverPostsStream()
                    : PostService.instance.getPostsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: 3,
                      itemBuilder: (context, index) => _buildPostPlaceholder(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                  }

                  final posts = snapshot.data ?? [];
                  if (posts.isEmpty) {
                    if (!_isDiscoverMode) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 60, color: AppTheme.adaptiveSubtle(context)),
                              SizedBox(height: 16),
                              Text(_l.t('feed_no_posts'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 15)),
                              SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () => setState(() => _isDiscoverMode = true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                child: Text(_l.t('feed_explore_discover')),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text(_l.t('feed_no_discover_posts'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context))),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      try {
                        return FadeInStaggered(
                          index: index,
                          child: PostWidget(post: posts[index]),
                        );
                      } catch (e, stackTrace) {
                        developer.log('Error rendering post at index $index', error: e, stackTrace: stackTrace);
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Something went wrong displaying this post',
                            style: TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedToggle(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isDiscoverMode = label == _l.t('feed_discover')),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppTheme.primaryGradient : null,
          color: isActive ? null : AppTheme.surfaceColor(context).withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPostPlaceholder() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 40, height: 40, borderRadius: 20),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 100, height: 12),
                  SizedBox(height: 6),
                  ShimmerBox(width: 60, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: 200, borderRadius: 12),
        ],
      ),
    );
  }
}

class _AnimatedIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  _AnimatedIconBtn({required this.icon, required this.onTap});

  @override
  State<_AnimatedIconBtn> createState() => _AnimatedIconBtnState();
}

class _AnimatedIconBtnState extends State<_AnimatedIconBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.adaptiveSubtle(context),
          ),
          child: Icon(
            widget.icon,
            size: 24,
            color: AppTheme.adaptiveText(context).withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}
