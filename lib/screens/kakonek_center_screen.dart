import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../services/friends_service.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_photo_widget.dart';
import '../widgets/animated_search_bar.dart';
import 'profile_screen.dart';
import '../utils/app_localizations.dart';

class KakonekCenterScreen extends StatefulWidget {
  final int initialIndex;
  const KakonekCenterScreen({super.key, this.initialIndex = 0});

  @override
  State<KakonekCenterScreen> createState() => _KakonekCenterScreenState();
}

class _KakonekCenterScreenState extends State<KakonekCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendsService _friendsService = FriendsService.instance;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.instance;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          l.t('kakonek_center_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        actions: [
          AnimatedSearchBar(
            hintText: AppLocalizations.instance.t('kakonek_search_hint'),
            onSearch: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            onCollapsed: () {
              setState(() {
                _searchQuery = '';
              });
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPurple,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorWeight: 3,
          tabs: [
            Tab(text: AppLocalizations.instance.t('kakonek_tab_my')),
            StreamBuilder<List<FriendRequest>>(
              stream: _friendsService.getPendingRequestsStream(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppLocalizations.instance.t('kakonek_tab_requests')),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryPurple,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Tab(text: AppLocalizations.instance.t('kakonek_tab_suggestions')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MyKakonekTab(searchQuery: _searchQuery),
          const RequestsTab(),
          SuggestionsTab(searchQuery: _searchQuery),
        ],
      ),
    );
  }
}

// --- TAB 1: MY KAKONEK ---
class MyKakonekTab extends StatefulWidget {
  final String searchQuery;
  const MyKakonekTab({super.key, required this.searchQuery});

  @override
  State<MyKakonekTab> createState() => _MyKakonekTabState();
}

class _MyKakonekTabState extends State<MyKakonekTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final friendsService = FriendsService.instance;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      backgroundColor: AppTheme.surfaceDark,
      color: AppTheme.primaryPurple,
      child: StreamBuilder<List<UserModel>>(
        stream: friendsService.getFriendsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
          }

          var friends = snapshot.data ?? [];
          if (widget.searchQuery.isNotEmpty) {
            friends = friends.where((u) =>
              u.username.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
              u.displayName.toLowerCase().contains(widget.searchQuery.toLowerCase())
            ).toList();
          }

          if (friends.isEmpty) {
            final l = AppLocalizations.instance;
            return _buildEmptyState(context,
              icon: widget.searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
              message: widget.searchQuery.isEmpty ? l.t('kakonek_no_kakonek') : l.t('kakonek_no_friends_found'),
              subtitle: widget.searchQuery.isEmpty
                ? l.t('kakonek_start_connecting')
                : l.t('kakonek_try_different_search'),
            );
          }

          return ListView.builder(
            itemCount: friends.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _buildUserTile(
                context,
                user: friend,
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  onPressed: () => _showFriendOptions(context, friend),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- TAB 2: REQUESTS ---
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Center(child: Text(AppLocalizations.instance.t('not_logged_in')));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          final l = AppLocalizations.instance;
          return _buildEmptyState(context,
            icon: Icons.notifications_none,
            message: l.t('kakonek_no_requests'),
            subtitle: l.t('kakonek_invitations_appear'),
          );
        }

        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (tsA == null || tsB == null) return 0;
          return tsB.compareTo(tsA);
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final requestData = sortedDocs[index].data() as Map<String, dynamic>;
            return _buildRequestCard(
              context,
              requestId: sortedDocs[index].id,
              fromUserId: requestData['fromUserId'] ?? '',
              fromUsername: requestData['fromUsername'] ?? 'User',
              fromDisplayName: requestData['fromDisplayName'] ?? 'User',
              timestamp: (requestData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          },
        );
      },
    );
  }
}

// --- TAB 3: SUGGESTIONS ---
class SuggestionsTab extends StatefulWidget {
  final String searchQuery;
  const SuggestionsTab({super.key, required this.searchQuery});

  @override
  State<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<SuggestionsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final friendsService = FriendsService.instance;

    return FutureBuilder<List<UserModel>>(
      future: widget.searchQuery.isEmpty
          ? SearchService.instance.getRecommendations()
          : SearchService.instance.searchUsers(widget.searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          final l = AppLocalizations.instance;
          return _buildEmptyState(context,
            icon: Icons.search_off,
            message: widget.searchQuery.isEmpty ? l.t('kakonek_no_suggestions') : l.t('kakonek_no_results'),
            subtitle: l.t('kakonek_try_different_search'),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final user = users[index];
            return FutureBuilder<FriendshipStatus>(
              future: friendsService.getFriendshipStatus(currentUserId, user.uid),
              builder: (context, statusSnapshot) {
                final status = statusSnapshot.data ?? FriendshipStatus.notFriends;
                return _buildUserTile(
                  context,
                  user: user,
                  trailing: _buildActionButton(context, user, status),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, UserModel user, FriendshipStatus status) {
    final friendsService = FriendsService.instance;
    switch (status) {
      case FriendshipStatus.friends:
        return Text(AppLocalizations.instance.t('kakonek_is_kakonek'), style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 12, fontWeight: FontWeight.bold));
      case FriendshipStatus.requestSent:
        return Text(AppLocalizations.instance.t('kakonek_pending'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12));
      case FriendshipStatus.requestReceived:
        return ElevatedButton(
          onPressed: () => setState(() {}),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(AppLocalizations.instance.t('notifications_accept'), style: const TextStyle(fontSize: 11, color: Colors.white)),
        );
      case FriendshipStatus.notFriends:
        return ElevatedButton(
          onPressed: () async {
            try {
              await friendsService.sendFriendRequest(user.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent to ${user.username}')));
              }
              setState(() {});
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surfaceDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(AppLocalizations.instance.t('kakonek_add'), style: const TextStyle(fontSize: 12)),
        );
    }
  }
}

// --- SHARED HELPERS ---
Widget _buildUserTile(BuildContext context, {required UserModel user, required Widget trailing}) {
  return ListTile(
    onTap: () {
      SearchService.instance.trackSearch(user.uid);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid)));
    },
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: UserPhotoWidget(
      userId: user.uid,
      radius: 24,
      showBorder: true,
      borderGradient: AppTheme.primaryGradient,
      borderWidth: 1.5,
    ),
    title: Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    subtitle: Text('@${user.username}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    trailing: trailing,
  );
}

Widget _buildRequestCard(
  BuildContext context, {
  required String requestId,
  required String fromUserId,
  required String fromUsername,
  required String fromDisplayName,
  required DateTime timestamp,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceDark,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Row(
      children: [
        UserPhotoWidget(userId: fromUserId, radius: 28, showBorder: true, borderGradient: AppTheme.primaryGradient, borderWidth: 2),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fromDisplayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('@$fromUsername', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withOpacity(0.7))),
              const SizedBox(height: 4),
              Text(_getTimeAgo(timestamp), style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.4))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            SizedBox(
              width: 85,
              height: 32,
              child: ElevatedButton(
                onPressed: () => _acceptRequest(context, requestId, fromUserId),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.zero),
                child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 85,
              height: 32,
              child: OutlinedButton(
                onPressed: () => _rejectRequest(context, requestId, fromUserId),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: BorderSide(color: Colors.redAccent.withOpacity(0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.zero),
                child: const Text('Reject', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

String _getTimeAgo(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);
  final l = AppLocalizations.instance;
  if (difference.inMinutes < 1) return l.t('time_just_now');
  if (difference.inHours < 1) return '${difference.inMinutes}${l.t('time_minutes_ago')}';
  if (difference.inDays < 1) return '${difference.inHours}${l.t('time_hours_ago')}';
  if (difference.inDays < 7) return '${difference.inDays}${l.t('time_days_ago')}';
  return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
}

Future<void> _acceptRequest(BuildContext context, String requestId, String fromUserId) async {
  try {
    await FriendsService.instance.acceptFriendRequest(requestId, fromUserId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.instance.t('kakonek_request_accepted')), backgroundColor: Colors.green));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
  }
}

Future<void> _rejectRequest(BuildContext context, String requestId, String fromUserId) async {
  try {
    await FriendsService.instance.rejectFriendRequest(requestId, fromUserId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.instance.t('kakonek_request_declined'))));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
  }
}

Widget _buildEmptyState(BuildContext context, {required IconData icon, required String message, required String subtitle}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.adaptiveTextSecondary(context).withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: AppTheme.adaptiveText(context), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: AppTheme.adaptiveTextSecondary(context)), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

void _showFriendOptions(BuildContext context, UserModel friend) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.person_outline, color: Colors.white),
          title: Text(AppLocalizations.instance.t('kakonek_view_profile'), style: const TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: friend.uid)));
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
          title: Text(AppLocalizations.instance.t('kakonek_unfriend'), style: const TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            _confirmUnfriend(context, friend);
          },
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

void _confirmUnfriend(BuildContext context, UserModel friend) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: Text('${AppLocalizations.instance.t('kakonek_unfriend')} ${friend.displayName}?'),
      content: Text(AppLocalizations.instance.t('kakonek_unfriend_confirm')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.instance.t('cancel'))),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await FriendsService.instance.removeFriend(friend.uid);
          },
          child: Text(AppLocalizations.instance.t('kakonek_unfriend'), style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
