import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/friends_service.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});
  
  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
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
    final currentUserId = AuthService().currentUser?.uid;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('New Message'),
        backgroundColor: AppTheme.backgroundDark,
      ),
      body: currentUserId == null
        ? const Center(child: Text('Please log in'))
        : Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              
              // Friends list
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: FriendsService.instance.getFriendsStream(currentUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryPurple,
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No friends yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      );
                    }
                    
                    var friends = snapshot.data!;
                    
                    // Filter by search query
                    if (_searchQuery.isNotEmpty) {
                      friends = friends.where((friend) {
                        final name = friend.displayName.toLowerCase();
                        final username = friend.username.toLowerCase();
                        return name.contains(_searchQuery) ||
                               username.contains(_searchQuery);
                      }).toList();
                    }
                    
                    if (friends.isEmpty && _searchQuery.isNotEmpty) {
                      return Center(
                        child: Text(
                          'No friends matching "$_searchQuery"',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: _getProfileImage(friend.photoURL),
                              child: _getProfileImage(friend.photoURL) == null
                                ? const Icon(Icons.person, size: 24, color: Colors.grey)
                                : null,
                            ),
                          ),
                          title: Text(
                            friend.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '@${friend.username}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () async {
                            // Show loading while creating/getting chat
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            try {
                              // Create or get chat
                              final chatId = await ChatService.instance
                                .getOrCreateChat(friend.uid);
                              
                              if (mounted) {
                                Navigator.pop(context); // Close loading
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      chatId: chatId,
                                      otherUserId: friend.uid,
                                      otherUserName: friend.displayName,
                                      otherUserPhotoURL: friend.photoURL,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.pop(context); // Close loading
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}
