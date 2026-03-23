import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/search_service.dart';
import '../services/friends_service.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';

class SearchResultsView extends StatefulWidget {
  final String query;
  
  SearchResultsView({
    super.key,
    required this.query,
  });
  
  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  ImageProvider? _getProfileImage(String? url) {
    if (url == null || url.isEmpty) return null;
    
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
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
    return Container(
      color: AppTheme.background(context),
      child: widget.query.isEmpty
        ? _buildRecommendations()
        : _buildSearchResults(),
    );
  }
  
  Widget _buildRecommendations() {
    return FutureBuilder<List<UserModel>>(
      future: SearchService.instance.getRecommendations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingList();
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No recommendations yet',
              style: TextStyle(
                color: AppTheme.adaptiveTextSecondary(context),
                fontSize: 14,
              ),
            ),
          );
        }
        
        final users = snapshot.data!;
        
        return ListView(
          padding: EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'Suggested for you',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.adaptiveText(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...users.asMap().entries.map((entry) => FadeInStaggered(
              index: entry.key,
              child: _buildUserTile(entry.value),
            )),
          ],
        );
      },
    );
  }
  
  Widget _buildSearchResults() {
    return FutureBuilder<List<UserModel>>(
      future: SearchService.instance.searchUsers(widget.query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingList();
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: AppTheme.adaptiveTextSecondary(context).withOpacity(0.2),
                ),
                SizedBox(height: 16),
                Text(
                  'No results for "${widget.query}"',
                  style: TextStyle(
                    color: AppTheme.adaptiveTextSecondary(context),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }
        
        final users = snapshot.data!;
        
        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            return FadeInStaggered(
              index: index,
              child: _buildUserTile(users[index]),
            );
          },
        );
      },
    );
  }
  
  Widget _buildLoadingList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            ShimmerBox(width: 52, height: 52, borderRadius: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 16),
                  SizedBox(height: 8),
                  ShimmerBox(width: 100, height: 12),
                ],
              ),
            ),
            ShimmerBox(width: 80, height: 32, borderRadius: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserTile(UserModel user) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return SizedBox();

    return FutureBuilder<FriendshipStatus>(
      future: FriendsService.instance.getFriendshipStatus(currentUid, user.uid),
      builder: (context, statusSnapshot) {
        final status = statusSnapshot.data ?? FriendshipStatus.notFriends;
        
        return ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: GestureDetector(
            onTap: () {
              SearchService.instance.trackSearch(user.uid);
              // Navigate to user profile here
            },
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.surfaceColor(context),
                backgroundImage: _getProfileImage(user.photoURL),
                child: _getProfileImage(user.photoURL) == null
                  ? Icon(Icons.person_rounded, size: 28, color: AppTheme.adaptiveSubtle(context))
                  : null,
              ),
            ),
          ),
          title: Text(
            user.displayName,
            style: TextStyle(
              color: AppTheme.adaptiveText(context),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: FutureBuilder<int>(
            future: FriendsService.instance.getMutualFriendsCount(user.uid),
            builder: (context, mutualSnapshot) {
              final mutualCount = mutualSnapshot.data ?? 0;
              return Text(
                mutualCount > 0 
                  ? '$mutualCount mutual kakonek' 
                  : '@${user.username}',
                style: TextStyle(
                  color: AppTheme.adaptiveTextSecondary(context).withOpacity(0.7),
                  fontSize: 12,
                ),
              );
            },
          ),
          trailing: _buildActionButton(user, status),
          onTap: () {
            SearchService.instance.trackSearch(user.uid);
            // Navigate to user profile here
          },
        );
      },
    );
  }
  
  Widget _buildActionButton(UserModel user, FriendshipStatus status) {
    final buttonStyle = ElevatedButton.styleFrom(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16),
    );

    switch (status) {
      case FriendshipStatus.friends:
        return TextButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 16, color: AppTheme.primaryPurple),
              SizedBox(width: 4),
              Text(
                'Kakonek',
                style: TextStyle(
                  color: AppTheme.primaryPurple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      
      case FriendshipStatus.requestSent:
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            'Pending',
            style: TextStyle(
              color: AppTheme.adaptiveTextSecondary(context),
              fontSize: 12,
            ),
          ),
        );
      
      case FriendshipStatus.requestReceived:
        return ElevatedButton(
          onPressed: () {
            // Navigator or direct accept using FriendsService
          },
          style: buttonStyle.copyWith(
            backgroundColor: MaterialStateProperty.all(AppTheme.primaryPurple),
          ),
          child: Text(
            'Accept',
            style: TextStyle(
              color: AppTheme.adaptiveText(context),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      
      case FriendshipStatus.notFriends:
        return ElevatedButton(
          onPressed: () async {
            try {
              await FriendsService.instance.sendFriendRequest(user.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kakonek request sent!'),
                    backgroundColor: AppTheme.primaryPurple,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                setState(() {}); // Refresh to show "Pending"
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                );
              }
            }
          },
          style: buttonStyle.copyWith(
            backgroundColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
          ),
          child: Text(
            'Add',
            style: TextStyle(
              color: AppTheme.adaptiveText(context),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }
}
