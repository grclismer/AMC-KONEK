import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/reel_service.dart';
import '../services/friends_service.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import 'package:social_media_app/utils/app_localizations.dart';
import 'settings_screen.dart';
import '../widgets/user_photo_widget.dart';
import '../widgets/post_widget.dart';
import 'dart:developer' as developer;
import '../utils/error_handler.dart';
import '../utils/app_localizations.dart';

// ─── Profile Screen ───────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final String? userId; // null = current logged-in user
  final bool isStandalone;
  ProfileScreen({super.key, this.userId, this.isStandalone = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final PostService _postService = PostService();
  final FriendsService _friendsService = FriendsService();
  late final TabController _tabController;
  AppLocalizations get _l => AppLocalizations.instance;

  String get targetUid =>
      widget.userId ?? _authService.currentUser?.uid ?? '';
  bool get isOwnProfile =>
      targetUid == _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isOwnProfile ? 5 : 3, vsync: this);
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
          return Scaffold(
            backgroundColor: AppTheme.background(context),
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
            '', _l.t('month_jan'), _l.t('month_feb'), _l.t('month_mar'), _l.t('month_apr'), _l.t('month_may'), _l.t('month_jun'),
            _l.t('month_jul'), _l.t('month_aug'), _l.t('month_sep'), _l.t('month_oct'), _l.t('month_nov'), _l.t('month_dec')
          ];
          joinDate = '${_l.t('profile_joined')} ${months[date.month]} ${date.year}';
        }

        final content = _buildProfileContent(
            displayName, username, bio, joinDate, userData);

        if (!widget.isStandalone) return content;

        return Scaffold(
          backgroundColor: AppTheme.background(context),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              '@$username',
              style: TextStyle(
                  color: AppTheme.adaptiveText(context), fontWeight: FontWeight.bold),
            ),
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: Icon(Icons.settings_outlined,
                      color: AppTheme.adaptiveText(context)),
                  onPressed: () => Navigator.push(
                    context,
                    SlidePageRoute(page: SettingsScreen()),
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
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () => _showProfilePictureFullscreen(context),
                      child: UserPhotoWidget(
                        userId: targetUid,
                        radius: 42,
                        showBorder: true,
                        borderGradient: AppTheme.primaryGradient,
                        borderWidth: 3,
                      ),
                    ),
                    SizedBox(width: 24),
                    // Stats — live counts from streams
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _LiveStatColumn(
                            label: _l.t('profile_posts'),
                            userId: targetUid,
                            stream: _postService
                                .getPostsByUserStream(targetUid),
                            valueFromData: (posts) =>
                                posts.length.toString(),
                          ),
                          _LiveStatColumn(
                            label: _l.t('profile_reels'),
                            userId: targetUid,
                            stream: ReelService.instance
                                .getUserReelsStream(targetUid),
                            valueFromData: (reels) =>
                                reels.length.toString(),
                          ),
                          GestureDetector(
                            onTap: () => _showKakonekList(context),
                            child: _buildStatColumn(
                              _l.t('profile_kakonek'),
                              userData['friendCount']?.toString() ?? '0',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Name, @username, bio, joined ───────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: AppTheme.adaptiveText(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: TextStyle(
                          color: AppTheme.adaptiveTextSecondary(context), fontSize: 14),
                    ),
                    if (bio.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        bio,
                        style: TextStyle(
                            color: AppTheme.adaptiveText(context), fontSize: 14),
                      ),
                    ],
                    SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppTheme.adaptiveTextSecondary(context)),
                      SizedBox(width: 4),
                      Text(joinDate,
                          style: TextStyle(
                              color: AppTheme.adaptiveTextSecondary(context),
                              fontSize: 12)),
                    ]),
                  ],
                ),
              ),

              // ── Action buttons ─────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _buildActionButtons(userData),
              ),

              SizedBox(height: 12),
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
              labelColor: AppTheme.primaryPurple,
              unselectedLabelColor: AppTheme.adaptiveTextSecondary(context),
              tabs: [
                Tab(icon: Icon(Icons.grid_on_outlined)),
                Tab(icon: Icon(Icons.video_library_outlined)),
                Tab(icon: Icon(Icons.repeat_rounded)),
                if (isOwnProfile) Tab(icon: Icon(Icons.bookmark_border_rounded)),
                if (isOwnProfile) Tab(icon: Icon(Icons.lock_outline_rounded)),
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
          _RepostsGridTab(userId: targetUid, postService: _postService),
          if (isOwnProfile) _SavedTab(userId: targetUid),
          if (isOwnProfile) _PrivatePostsTab(userId: targetUid, postService: _postService),
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
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.adaptiveText(context)),
        ),
        SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
              fontSize: 12, color: AppTheme.adaptiveTextSecondary(context)),
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
            MaterialPageRoute(builder: (_) => SettingsScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surface(context),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    BorderSide(color: Colors.white.withOpacity(0.15))),
          ),
          child: Text(_l.t('profile_edit_profile'),
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
                    ? AppTheme.surface(context)
                    : AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isFriend ? '${_l.t('profile_kakonek')} ✓' : _l.t('profile_add_kakonek')),
            );
          },
        ),
      ),
      SizedBox(width: 10),
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
          child: Text(_l.t('profile_message')),
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
            .showSnackBar(SnackBar(content: Text(AppErrorHandler.postError(e))));
      }
    }
  }

  void _showKakonekList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: AppTheme.adaptiveSubtle(context), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kakonek', style: TextStyle(color: AppTheme.adaptiveText(context), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Divider(color: AppTheme.adaptiveSubtle(context)),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(targetUid).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Center(child: Text(_l.t('profile_no_kakonek'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context))));
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final friends = List<String>.from(data['friends'] ?? []);
                    if (friends.isEmpty) {
                      return Center(child: Text(_l.t('profile_no_kakonek'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context))));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friendId = friends[index];
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                          builder: (context, friendSnap) {
                            if (!friendSnap.hasData || !friendSnap.data!.exists) {
                              return SizedBox.shrink();
                            }
                            final friendData = friendSnap.data!.data() as Map<String, dynamic>;
                            final displayName = friendData['displayName'] ?? 'User';
                            final username = friendData['username'] ?? '';
                            return ListTile(
                              leading: UserPhotoWidget(userId: friendId, radius: 20),
                              title: Text(displayName, style: TextStyle(color: AppTheme.adaptiveText(context))),
                              subtitle: Text('@$username', style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 12)),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(this.context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: friendId)));
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfilePictureFullscreen(BuildContext context) {
    // Get user's photo URL
    final userStream = _authService.getUserStream(targetUid);
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Tap anywhere to close
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            
            // Profile picture
            Center(
              child: StreamBuilder<DocumentSnapshot>(
                stream: userStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return CircularProgressIndicator(
                      color: AppTheme.primaryPurple,
                    );
                  }
                  
                  final userData = snapshot.data?.data() as Map<String, dynamic>?;
                  final photoURL = userData?['photoURL'] ?? '';
                  
                  if (photoURL.isEmpty) {
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 100,
                        color: Colors.grey,
                      ),
                    );
                  }
                  
                  // Get image provider
                  ImageProvider? imageProvider;
                  if (photoURL.startsWith('data:image')) {
                    try {
                      final base64String = photoURL.split(',').last;
                      imageProvider = MemoryImage(base64Decode(base64String));
                    } catch (e) {
                      developer.log('Error decoding Base64: $e');
                    }
                  } else if (photoURL.startsWith('http')) {
                    imageProvider = NetworkImage(photoURL);
                  }
                  
                  if (imageProvider == null) {
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 100,
                        color: Colors.grey,
                      ),
                    );
                  }
                  
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: ClipOval(
                      child: Image(
                        image: imageProvider,
                        width: 300,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: AppTheme.adaptiveText(context),
                  size: 32,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live Stat Column (counts from real stream) ───────────────────────────────

class _LiveStatColumn<T> extends StatelessWidget {
  final String label;
  final String userId;
  final Stream<List<T>> stream;
  final String Function(List<T>) valueFromData;

  _LiveStatColumn({
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
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.adaptiveText(context)),
            ),
            SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.adaptiveTextSecondary(context)),
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
  _StickyTabBarDelegate(this.tabBar);

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        color: AppTheme.background(context),
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

  _PostsGridTab({required this.userId, required this.postService});
  AppLocalizations get _l => AppLocalizations.instance;

  @override
  Widget build(BuildContext context) {
    developer.log('=== BUILDING POSTS TAB ===');
    developer.log('User ID: $userId');

    return StreamBuilder<List<Post>>(
      stream: postService.getUserPostsStream(userId),
      builder: (context, snapshot) {
        developer.log('Stream state: ${snapshot.connectionState}');
        developer.log('Has data: ${snapshot.hasData}');
        
        if (snapshot.hasError) {
          developer.log('POSTS TAB ERROR: ${snapshot.error}');
          return Center(child: Text('${_l.t('profile_error_posts')}: ${snapshot.error}', style: TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryPurple));
        }

        final posts = snapshot.data ?? [];
        developer.log('Total posts received in tab: ${posts.length}');

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_off_outlined,
                    size: 56, color: Colors.grey[700]),
                SizedBox(height: 12),
                Text(_l.t('profile_no_posts'),
                    style: TextStyle(
                        color: AppTheme.adaptiveTextSecondary(context), fontSize: 15)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(1),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            developer.log('Building grid item $index for post: ${post.id}, Type: ${post.type.name}');
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                developer.log('GRID_ON_TAP: Post ${post.id}');
                _showPostDetail(context, post);
              },
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
            color: AppTheme.background(context),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                      color: AppTheme.adaptiveSubtle(context),
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
  final bool isRepost;
  _PostGridCell({required this.post, this.isRepost = false});

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
            : Container(color: AppTheme.surface(context)),
        if (isRepost)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.repeat_rounded,
                  size: 11, color: Colors.green),
            ),
          )
        else
          Positioned(
            top: 6,
            right: 6,
            child: Icon(Icons.image,
                size: 14, color: Colors.white.withOpacity(0.8)),
          ),
      ]);
    }

    // ── Mood post — show emoji and amber tint ───────────────────────────────
    if (post.type == PostType.mood) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.3),
              AppTheme.surface(context),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    post.moodEmoji ?? '😊',
                    style: TextStyle(fontSize: 28),
                  ),
                  SizedBox(height: 4),
                  Text(
                    post.moodLabel ?? 'Happy',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (isRepost)
              Positioned(
                bottom: 4,
                right: 4,
                child: Icon(Icons.repeat_rounded, size: 14, color: Colors.green),
              ),
          ],
        ),
      );
    }

    // ── Text post — show card preview ────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withOpacity(0.4),
            AppTheme.surface(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(8),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  color: AppTheme.adaptiveTextSecondary(context),
                  size: 24,
                ),
                SizedBox(height: 4),
                Text(
                  post.content,
                  style: TextStyle(
                    color: AppTheme.adaptiveText(context),
                    fontSize: 10,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (isRepost)
            Positioned(
              bottom: 0,
              right: 0,
              child: Icon(Icons.repeat_rounded, size: 14, color: Colors.green),
            )
          else
            Positioned(
              bottom: 0,
              left: 0,
              child: Row(children: [
                Icon(Icons.favorite_border,
                    size: 10, color: AppTheme.adaptiveTextSecondary(context)),
                SizedBox(width: 3),
                Text(
                  '${post.likes}',
                  style: TextStyle(
                      color: AppTheme.adaptiveTextSecondary(context), fontSize: 10),
                ),
                if (post.repostCount > 0) ...[
                  SizedBox(width: 8),
                  Icon(Icons.repeat_rounded, size: 10, color: Colors.green),
                  SizedBox(width: 3),
                  Text(
                    '${post.repostCount}',
                    style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 10),
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

// ─── Tab 2: Reels Grid ────────────────────────────────────────────────────────

class _ReelsGridTab extends StatelessWidget {
  final String userId;
  _ReelsGridTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reel>>(
      stream: ReelService.instance.getUserReelsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
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
                SizedBox(height: 12),
                Text('No reels yet',
                    style: TextStyle(
                        color: AppTheme.adaptiveTextSecondary(context), fontSize: 15)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(1),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
      builder: (_) => _ReelDetailSheet(reel: reel),
    );
  }
}

class _ReelDetailSheet extends StatefulWidget {
  final Reel reel;
  _ReelDetailSheet({required this.reel});

  @override
  State<_ReelDetailSheet> createState() => _ReelDetailSheetState();
}

class _ReelDetailSheetState extends State<_ReelDetailSheet> {
  VideoPlayerController? _controller;
  bool _isLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _isLiked = widget.reel.isLikedBy(currentUserId);
    _likesCount = widget.reel.likes;
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.reel.videoUrl;
    if (url.isEmpty) return;
    try {
      if (url.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else if (url.startsWith('data:video')) {
        if (kIsWeb) {
          _controller = VideoPlayerController.networkUrl(Uri.parse(url));
        } else {
          final bytes = base64Decode(url.split(',').last);
          final tempDir = await getTemporaryDirectory();
          final tempFile = io.File('${tempDir.path}/temp_reel_detail_${widget.reel.id}.mp4');
          await tempFile.writeAsBytes(bytes);
          _controller = VideoPlayerController.file(tempFile);
        }
      } else {
        return;
      }
      await _controller!.initialize();
      _controller!.setLooping(true);
      if (mounted) {
        setState(() {});
        _controller!.play();
      }
    } catch (e) {
      debugPrint('Error init detail video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    ReelService.instance.toggleLike(widget.reel.id).catchError((_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppTheme.adaptiveSubtle(context), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (_controller != null && _controller!.value.isInitialized)
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
                  ),
                ),
              SizedBox(height: 16),
              Text(widget.reel.displayName, style: TextStyle(color: AppTheme.adaptiveText(context), fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text(widget.reel.caption, style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 14)),
              SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : AppTheme.textSecondaryColor(context), size: 20),
                        SizedBox(width: 4),
                        Text('$_likesCount', style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 13)),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: AppTheme.adaptiveTextSecondary(context), size: 20),
                      SizedBox(width: 4),
                      Text('${widget.reel.comments}', style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 13)),
                    ],
                  ),
                  SizedBox(width: 16),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, color: AppTheme.adaptiveTextSecondary(context), size: 20),
                      SizedBox(width: 4),
                      Text('${widget.reel.views}', style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 13)),
                    ],
                  ),
                ],
              ),
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
  _ReelStat(this.icon, this.value);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppTheme.adaptiveTextSecondary(context)),
        SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                color: AppTheme.adaptiveTextSecondary(context), fontSize: 13)),
      ]);
}

// ─── Reel Grid Cell ───────────────────────────────────────────────────────────

class _ReelGridCell extends StatelessWidget {
  final Reel reel;
  _ReelGridCell({required this.reel});

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
        Center(
          child: Icon(Icons.play_circle_outline,
              size: 32, color: AppTheme.adaptiveTextSecondary(context)),
        ),
        // Views at bottom left
        Positioned(
          bottom: 6,
          left: 6,
          child: Row(children: [
            Icon(Icons.remove_red_eye,
                size: 11, color: AppTheme.adaptiveTextSecondary(context)),
            SizedBox(width: 3),
            Text(
              _fmt(reel.views),
              style: TextStyle(
                  color: AppTheme.adaptiveTextSecondary(context),
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

// ─── Tab 3: Reposts Grid ──────────────────────────────────────────────────────

class _RepostsGridTab extends StatelessWidget {
  final String userId;
  final PostService postService;

  _RepostsGridTab({required this.userId, required this.postService});

  @override
  Widget build(BuildContext context) {
    developer.log('=== BUILDING REPOSTS TAB ===');
    developer.log('User ID: $userId');

    return StreamBuilder<List<Post>>(
      stream: postService.getUserRepostsStream(userId),
      builder: (context, snapshot) {
        developer.log('Reposts Stream state: ${snapshot.connectionState}');
        developer.log('Has data: ${snapshot.hasData}');

        if (snapshot.hasError) {
          developer.log('REPOSTS TAB ERROR: ${snapshot.error}');
          return Center(child: Text('Error loading reposts: ${snapshot.error}', style: TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryPurple));
        }

        final reposts = snapshot.data ?? [];
        developer.log('Total reposts received: ${reposts.length}');

        if (reposts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.repeat_rounded,
                    size: 56, color: Colors.grey[700]),
                SizedBox(height: 12),
                Text('No reposts yet',
                    style: TextStyle(
                        color: AppTheme.adaptiveTextSecondary(context), fontSize: 15)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(1),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: reposts.length,
          itemBuilder: (context, index) {
            final post = reposts[index];
            developer.log('Building grid item $index for REPOST: ${post.id}, Type: ${post.type.name}');
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                developer.log('GRID_REPOST_ON_TAP: Post ${post.id}');
                _showPostDetailInProfile(context, post);
              },
              child: _PostGridCell(post: post, isRepost: true),
            );
          },
        );
      },
    );
  }

  void _showPostDetailInProfile(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.background(context),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                      color: AppTheme.adaptiveSubtle(context),
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

// ─── Saved Grid Tab (User's Saved Content) ──────────────────────────────────

class _SavedTab extends StatelessWidget {
  final String userId;
  _SavedTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPurple),
          );
        }

        final savedDocs = snapshot.data!.docs;

        if (savedDocs.isEmpty) {
          return Center(
            child: Text(
              'No saved content yet',
              style: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
            ),
          );
        }

        // Sort in memory by savedAt descending
        final sortedDocs = savedDocs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime = (bData['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime);
          });

        return GridView.builder(
          padding: EdgeInsets.all(2),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final saved = sortedDocs[index].data() as Map<String, dynamic>;
            final type = saved['type'] as String?;
            final itemId = type == 'reel' ? saved['reelId'] : saved['postId'];
            final collection = type == 'reel' ? 'reels' : 'posts';

            if (itemId == null) return Container(color: AppTheme.surface(context));

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection(collection)
                  .doc(itemId)
                  .get(),
              builder: (context, itemSnap) {
                if (!itemSnap.hasData || !itemSnap.data!.exists) {
                  return Container(
                    color: AppTheme.surface(context),
                    child: Center(
                      child: Icon(Icons.bookmark_border_rounded, color: AppTheme.adaptiveTextSecondary(context)),
                    ),
                  );
                }

                Widget childWidget;
                if (type == 'reel') {
                  childWidget = Container(
                    color: AppTheme.surface(context),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(child: Icon(Icons.play_circle_outline, color: AppTheme.adaptiveTextSecondary(context), size: 30)),
                        Positioned(
                          bottom: 4, right: 4,
                          child: Icon(Icons.video_library, color: AppTheme.adaptiveText(context), size: 14),
                        ),
                      ],
                    ),
                  );
                } else {
                  final post = Post.fromFirestore(itemSnap.data!);
                  if (post.type == PostType.image && post.content.isNotEmpty) {
                    childWidget = Image.network(post.content, fit: BoxFit.cover);
                  } else {
                    childWidget = Container(
                      color: AppTheme.surface(context),
                      child: Center(
                        child: Icon(
                          post.type == PostType.text ? Icons.text_snippet : Icons.article,
                          color: AppTheme.adaptiveTextSecondary(context),
                        ),
                      ),
                    );
                  }
                }

                return GestureDetector(
                  onTap: () {
                    if (type == 'post') {
                      final post = Post.fromFirestore(itemSnap.data!);
                      _showSavedPostDetail(context, post);
                    } else if (type == 'reel') {
                      final reel = Reel.fromFirestore(itemSnap.data!);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _ReelDetailSheet(reel: reel),
                      );
                    }
                  },
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppTheme.surface(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (bottomSheetContext) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: AppTheme.adaptiveSubtle(context), borderRadius: BorderRadius.circular(2)),
                          ),
                          ListTile(
                            leading: Icon(Icons.bookmark_remove_rounded, color: Colors.red),
                            title: Text('Remove from saved', style: TextStyle(color: Colors.red)),
                            onTap: () async {
                              Navigator.pop(bottomSheetContext);
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .collection('saved')
                                  .doc(sortedDocs[index].id)
                                  .delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Removed from saved')),
                                );
                              }
                            },
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                  child: childWidget,
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSavedPostDetail(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.background(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(color: AppTheme.adaptiveSubtle(context), borderRadius: BorderRadius.circular(2)),
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

// ─── Private Posts Tab ────────────────────────────────────────────────────────

class _PrivatePostsTab extends StatefulWidget {
  final String userId;
  final PostService postService;
  _PrivatePostsTab({required this.userId, required this.postService});

  @override
  State<_PrivatePostsTab> createState() => _PrivatePostsTabState();
}

class _PrivatePostsTabState extends State<_PrivatePostsTab> {
  void _showPostDetailInProfile(Post post, List<Post> posts, int index) {
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
            color: AppTheme.background(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                      color: AppTheme.adaptiveSubtle(context),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: widget.postService.getPrivatePostsStream(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPurple),
          );
        }

        final privatePosts = snapshot.data!;

        if (privatePosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, color: AppTheme.adaptiveSubtle(context), size: 60),
                SizedBox(height: 16),
                Text(
                  'No private posts',
                  style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 16),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.all(2),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: privatePosts.length,
          itemBuilder: (context, index) {
            final post = privatePosts[index];
            return GestureDetector(
              onTap: () => _showPostDetailInProfile(post, privatePosts, index),
              child: _buildGridItem(post),
            );
          },
        );
      },
    );
  }

  Widget _buildGridItem(Post post) {
    if (post.type == PostType.image && post.content.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(post.content, fit: BoxFit.cover),
          Positioned(
            top: 4, right: 4,
            child: Icon(Icons.lock, color: AppTheme.adaptiveText(context), size: 14),
          ),
        ],
      );
    }
    return Container(
      color: AppTheme.surface(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(
              post.type == PostType.text ? Icons.text_snippet : Icons.article,
              color: AppTheme.adaptiveTextSecondary(context),
            ),
          ),
          Positioned(
            top: 4, right: 4,
            child: Icon(Icons.lock, color: AppTheme.adaptiveText(context), size: 14),
          ),
        ],
      ),
    );
  }
}