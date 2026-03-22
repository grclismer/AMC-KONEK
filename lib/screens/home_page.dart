import 'package:flutter/material.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _unreadCount = 2;
  final AuthService _authService = AuthService();

  bool _isDiscoverMode = false;
  bool _showingSearchResults = false;
  String _searchQuery = '';

  void _showCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreatePostModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
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
                color: AppTheme.surfaceDark.withOpacity(0.8),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
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
                        child: const Text(
                          "KONEK",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    
                    if (_showingSearchResults)
                      const SizedBox(width: 8),

                    // Icons and Search
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedSearchBar(
                            hintText: 'Search people...',
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
                            const SizedBox(width: 12),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _AnimatedIconBtn(
                                  icon: Icons.notifications_none_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    SlidePageRoute(page: const NotificationsScreen()),
                                  ),
                                ),
                                if (_unreadCount > 0)
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
                                          style: const TextStyle(
                                            color: Colors.white,
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
        constraints: const BoxConstraints(maxWidth: 600),
        child: RefreshIndicator(
          backgroundColor: AppTheme.surfaceDark,
          color: AppTheme.primaryPurple,
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            children: [
              const SizedBox(height: 8),
              const StoriesBar(),
              const SizedBox(height: 12),
              const FriendRecommendations(),
              const SizedBox(height: 12),

              // Feed Type Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFeedToggle('Friends', !_isDiscoverMode),
                    const SizedBox(width: 12),
                    _buildFeedToggle('Discover', _isDiscoverMode),
                  ],
                ),
              ),

              // Create Post Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    UserPhotoWidget(
                      userId: _authService.currentUser?.uid ?? '',
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showCreatePostModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLighter.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Text(
                            "What's on your mind?",
                            style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6)),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _showCreatePostModal,
                      icon: const Icon(Icons.image_outlined, color: Colors.green),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10),

              // Posts Stream
              StreamBuilder<List<Post>>(
                stream: _isDiscoverMode 
                    ? PostService.instance.getDiscoverPostsStream()
                    : PostService.instance.getPostsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 3,
                      itemBuilder: (context, index) => _buildPostPlaceholder(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }

                  final posts = snapshot.data ?? [];
                  if (posts.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text("No posts found", style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    itemBuilder: (context, index) => FadeInStaggered(
                      index: index,
                      child: PostWidget(post: posts[index]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedToggle(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isDiscoverMode = label == 'Discover'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppTheme.primaryGradient : null,
          color: isActive ? null : AppTheme.surfaceLighter.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPostPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerBox(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 100, height: 12),
                  SizedBox(height: 6),
                  ShimmerBox(width: 60, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ShimmerBox(width: double.infinity, height: 200, borderRadius: 12),
        ],
      ),
    );
  }
}

class _AnimatedIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedIconBtn({required this.icon, required this.onTap});

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
      duration: const Duration(milliseconds: 100),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
          ),
          child: Icon(
            widget.icon,
            size: 24,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}
