import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/reel_service.dart';
import '../services/friends_service.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import 'settings_screen.dart';
import '../widgets/user_photo_widget.dart';
import '../widgets/post_widget.dart';

// ─── Profile Screen ───────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final String? userId; // null = current logged-in user
  final bool isStandalone;
  const ProfileScreen({super.key, this.userId, this.isStandalone = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final PostService _postService = PostService();
  final FriendsService _friendsService = FriendsService();
  late final TabController _tabController;

  String get targetUid =>
      widget.userId ?? _authService.currentUser?.uid ?? '';
  bool get isOwnProfile =>
      targetUid == _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _authService.getUserStream(targetUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryPurple)),
          );
        }

        final userData =
            snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final displayName = userData['displayName'] ?? 'User';
        final username = userData['username'] ?? 'username';
        final bio = userData['bio'] ?? '';

        String joinDate = 'Joined recently';
        final createdAt = userData['createdAt'];
        if (createdAt is Timestamp) {
          final date = createdAt.toDate();
          final months = [
            '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ];
          joinDate = 'Joined ${months[date.month]} ${date.year}';
        }

        final content = _buildProfileContent(
            displayName, username, bio, joinDate, userData);

        if (!widget.isStandalone) return content;

        return Scaffold(
          backgroundColor: AppTheme.backgroundDark,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              '@$username',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    SlidePageRoute(page: const SettingsScreen()),
                  ),
                ),
            ],
          ),
          body: content,
        );
      },
    );
  }

  // ─── Profile Header ──────────────────────────────────────────────────────────

  Widget _buildProfileContent(
    String displayName,
    String username,
    String bio,
    String joinDate,
    Map<String, dynamic> userData,
  ) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + Stats row ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    UserPhotoWidget(
                      userId: targetUid,
                      radius: 42,
                      showBorder: true,
                      borderGradient: AppTheme.primaryGradient,
                      borderWidth: 3,
                    ),
                    const SizedBox(width: 24),
                    // Stats — live counts from streams
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _LiveStatColumn(
                            label: 'Posts',
                            userId: targetUid,
                            stream: _postService
                                .getPostsByUserStream(targetUid),
                            valueFromData: (posts) =>
                                posts.length.toString(),
                          ),
                          _LiveStatColumn(
                            label: 'Reels',
                            userId: targetUid,
                            stream: ReelService.instance
                                .getUserReelsStream(targetUid),
                            valueFromData: (reels) =>
                                reels.length.toString(),
                          ),
                          _buildStatColumn(
                            'Kakonek',
                            userData['friendCount']?.toString() ?? '0',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Name, @username, bio, joined ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        bio,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(joinDate,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ]),
                  ],
                ),
              ),

              // ── Action buttons ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _buildActionButtons(userData),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Tab bar ───────────────────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBarDelegate(
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryPurple,
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.grid_on_outlined)),
                Tab(icon: Icon(Icons.video_library_outlined)),
                Tab(icon: Icon(Icons.person_pin_outlined)),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostsGridTab(userId: targetUid, postService: _postService),
          _ReelsGridTab(userId: targetUid),
          _TaggedTab(),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> userData) {
    if (isOwnProfile) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surfaceDark,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    BorderSide(color: Colors.white.withOpacity(0.15))),
          ),
          child: const Text('Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Row(children: [
      Expanded(
        child: StreamBuilder<bool>(
          stream: _friendsService.isFriendStream(targetUid),
          builder: (context, snap) {
            final isFriend = snap.data ?? false;
            return ElevatedButton(
              onPressed: () => _toggleFriend(userData),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFriend
                    ? AppTheme.surfaceDark
                    : AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isFriend ? 'Kakonek ✓' : 'Add Kakonek'),
            );
          },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side:
                BorderSide(color: Colors.white.withOpacity(0.2)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Message'),
        ),
      ),
    ]);
  }

  Future<void> _toggleFriend(Map<String, dynamic> userData) async {
    try {
      final isFriend =
          await _friendsService.isFriendStream(targetUid).first;
      if (isFriend) {
        await _friendsService.removeFriend(targetUid);
      } else {
        await _friendsService.sendFriendRequest(targetUid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─── Live Stat Column (counts from real stream) ───────────────────────────────

class _LiveStatColumn<T> extends StatelessWidget {
  final String label;
  final String userId;
  final Stream<List<T>> stream;
  final String Function(List<T>) valueFromData;

  const _LiveStatColumn({
    required this.label,
    required this.userId,
    required this.stream,
    required this.valueFromData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snap) {
        final value = snap.hasData ? valueFromData(snap.data!) : '—';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        );
      },
    );
  }
}

// ─── Sticky TabBar Delegate ───────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBarDelegate(this.tabBar);

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        color: AppTheme.backgroundDark,
        child: tabBar,
      );

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => tabBar != old.tabBar;
}

// ─── Tab 1: Posts Grid ────────────────────────────────────────────────────────

class _PostsGridTab extends StatelessWidget {
  final String userId;
  final PostService postService;

  const _PostsGridTab({required this.userId, required this.postService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: postService.getPostsByUserStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryPurple));
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_off_outlined,
                    size: 56, color: Colors.grey[700]),
                const SizedBox(height: 12),
                const Text('No posts yet',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () => _showPostDetail(context, post),
              child: _PostGridCell(post: post),
            );
          },
        );
      },
    );
  }

  void _showPostDetail(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: PostWidget(post: post),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Post Grid Cell ───────────────────────────────────────────────────────────

class _PostGridCell extends StatelessWidget {
  final Post post;
  const _PostGridCell({required this.post});

  ImageProvider? _getImage(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // ── Image post — show the image ──────────────────────────────────────────
    if (post.type == PostType.image) {
      final imageProvider = _getImage(post.content);
      return Stack(fit: StackFit.expand, children: [
        imageProvider != null
            ? Image(image: imageProvider, fit: BoxFit.cover)
            : Container(color: AppTheme.surfaceDark),
        // Image indicator icon (top-right)
        Positioned(
          top: 6,
          right: 6,
          child: Icon(Icons.image,
              size: 14, color: Colors.white.withOpacity(0.8)),
        ),
      ]);
    }

    // ── Text post — show card preview ────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withOpacity(0.4),
            AppTheme.surfaceDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Text snippet
          Text(
            post.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Like count at bottom
          Row(children: [
            const Icon(Icons.favorite_border,
                size: 10, color: AppTheme.textSecondary),
            const SizedBox(width: 3),
            Text(
              '${post.likes}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Tab 2: Reels Grid ────────────────────────────────────────────────────────

class _ReelsGridTab extends StatelessWidget {
  final String userId;
  const _ReelsGridTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reel>>(
      stream: ReelService.instance.getUserReelsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryPurple));
        }

        final reels = snapshot.data ?? [];

        if (reels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off_outlined,
                    size: 56, color: Colors.grey[700]),
                const SizedBox(height: 12),
                const Text('No reels yet',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: reels.length,
          itemBuilder: (context, index) {
            final reel = reels[index];
            return GestureDetector(
              onTap: () => _showReelDetail(context, reel),
              child: _ReelGridCell(reel: reel),
            );
          },
        );
      },
    );
  }

  void _showReelDetail(BuildContext context, Reel reel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Play icon
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      size: 60, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),
              Text(reel.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 4),
              Text(reel.caption,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 12),
              Row(children: [
                _ReelStat(Icons.favorite_border, '${reel.likes}'),
                const SizedBox(width: 16),
                _ReelStat(
                    Icons.remove_red_eye_outlined, '${reel.views}'),
                const SizedBox(width: 16),
                _ReelStat(Icons.chat_bubble_outline, '${reel.comments}'),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelStat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _ReelStat(this.icon, this.value);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      ]);
}

// ─── Reel Grid Cell ───────────────────────────────────────────────────────────

class _ReelGridCell extends StatelessWidget {
  final Reel reel;
  const _ReelGridCell({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withOpacity(0.5),
            Colors.black,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        // Play icon in center
        const Center(
          child: Icon(Icons.play_circle_outline,
              size: 32, color: Colors.white54),
        ),
        // Views at bottom left
        Positioned(
          bottom: 6,
          left: 6,
          child: Row(children: [
            const Icon(Icons.remove_red_eye,
                size: 11, color: Colors.white70),
            const SizedBox(width: 3),
            Text(
              _fmt(reel.views),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        // Video badge top right
        Positioned(
          top: 6,
          right: 6,
          child: Icon(Icons.videocam,
              size: 14, color: Colors.white.withOpacity(0.8)),
        ),
      ]),
    );
  }

  String _fmt(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return '$c';
  }
}

// ─── Tab 3: Tagged ────────────────────────────────────────────────────────────

class _TaggedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_pin_outlined,
              size: 56, color: Colors.grey[700]),
          const SizedBox(height: 12),
          const Text(
            'Tagged posts\ncoming soon',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
