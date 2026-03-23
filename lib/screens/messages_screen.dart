import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_media_app/utils/app_localizations.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Stream<List<Chat>> _chatsStream;
  final Map<String, Map<String, dynamic>> _userDataCache = {};
  List<Chat> _cachedChats = []; // Never goes blank during re-queries
  AppLocalizations get _l => AppLocalizations.instance;

  @override
  void initState() {
    super.initState();
    _chatsStream = ChatService.instance.getChatsStream();
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
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return _l.t('time_just_now');
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}${_l.t('time_m_ago').substring(0, 1)}';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}${_l.t('time_h_ago').substring(0, 1)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}${_l.t('time_d_ago').substring(0, 1)}';
    } else {
      return '${time.day}/${time.month}';
    }
  }
  
  Future<DocumentSnapshot?> _fetchUserData(String userId) async {
    if (_userDataCache.containsKey(userId)) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      _userDataCache[userId] = doc.data() as Map<String, dynamic>? ?? {};
    }
    return doc;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService().currentUser?.uid;
    
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(_l.t('msg_title')),
        backgroundColor: AppTheme.background(context),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_square),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NewMessageScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: currentUserId == null 
        ? Center(child: Text(_l.t('msg_please_login')))
        : StreamBuilder<List<Chat>>(
            stream: _chatsStream,
            builder: (context, snapshot) {
              // Only update cache with non-empty real data — never go blank
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                _cachedChats = snapshot.data!;
              }

              // Show spinner only on very first load before any data arrives
              if (_cachedChats.isEmpty) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryPurple,
                    ),
                  );
                }
                // Truly no chats yet
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey[700],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _l.t('msg_no_messages'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.adaptiveText(context),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _l.t('msg_start_chatting'),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.adaptiveTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: _cachedChats.length,
                itemBuilder: (context, index) {
                  final chat = _cachedChats[index];
                  final otherId = chat.getOtherParticipant(currentUserId);
                  
                  return FutureBuilder<DocumentSnapshot?>(
                    future: _fetchUserData(otherId),
                    builder: (context, userSnapshot) {
                      // If we have cached data, use it immediately
                      if (_userDataCache.containsKey(otherId)) {
                        final userData = _userDataCache[otherId]!;
                        return _buildChatTile(
                          context,
                          chat,
                          otherId,
                          userData['displayName'] ?? 'User',
                          userData['photoURL'],
                          currentUserId,
                        );
                      }

                      // If loading new data
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          height: 80,
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surface(context).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }
                      
                      // After fetching, if it exists but wasn't in cache yet
                      if (userSnapshot.hasData && userSnapshot.data != null) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        return _buildChatTile(
                          context,
                          chat,
                          otherId,
                          userData['displayName'] ?? 'User',
                          userData['photoURL'],
                          currentUserId,
                        );
                      }
                      
                      return SizedBox.shrink();
                    },
                  );
                },
              );
            },
          ),
    );
  }
  
  Widget _buildChatTile(
    BuildContext context,
    Chat chat,
    String otherId,
    String displayName,
    String? photoURL,
    String currentUserId,
  ) {
    final unreadCount = chat.getUnreadCount(currentUserId);
    final isTyping = chat.isOtherUserTyping(currentUserId);
    final isSentByMe = chat.lastMessageSenderId == currentUserId;
    
    return ListTile(
      key: ValueKey('chat_${chat.id}'),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      leading: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unreadCount > 0 
                ? AppTheme.primaryGradient 
                : null,
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage: _getProfileImage(photoURL),
              child: _getProfileImage(photoURL) == null
                ? Icon(Icons.person, size: 28, color: Colors.grey)
                : null,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.background(context),
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontSize: 16,
          fontWeight: unreadCount > 0 
            ? FontWeight.bold 
            : FontWeight.w600,
          color: AppTheme.adaptiveText(context),
        ),
      ),
      subtitle: isTyping
        ? Text(
            _l.t('msg_typing'),
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryPurple,
              fontStyle: FontStyle.italic,
            ),
          )
        : Row(
            children: [
              if (isSentByMe)
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: AppTheme.adaptiveTextSecondary(context),
                  ),
                ),
              Expanded(
                child: Text(
                  chat.lastMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: unreadCount > 0 
                      ? Colors.white 
                      : AppTheme.textSecondaryColor(context),
                    fontWeight: unreadCount > 0 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: unreadCount > 0 
                ? AppTheme.primaryPurple 
                : AppTheme.textSecondaryColor(context),
              fontWeight: unreadCount > 0 
                ? FontWeight.bold 
                : FontWeight.normal,
            ),
          ),
          if (unreadCount > 0) ...[
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.adaptiveText(context),
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chat.id,
              otherUserId: otherId,
              otherUserName: displayName,
              otherUserPhotoURL: photoURL ?? '',
            ),
          ),
        );
      },
    );
  }
}
