import 'package:flutter/material.dart';
import 'youtube_player_widget.dart';
import 'tiktok_player_placeholder.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../screens/comments_screen.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../screens/profile_screen.dart';
import 'dart:developer' as developer;
import '../widgets/user_photo_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostWidget extends StatefulWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late bool _isLiked;
  late int _likeCount;
  late bool _isReposted = false;
  late int _repostCount;
  bool _isHidden = false;
  bool _isSaved = false;
  final String? _currentUserId = AuthService().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes;
    _repostCount = widget.post.repostCount;
    _isLiked = _currentUserId != null && widget.post.likedBy.contains(_currentUserId);
    _checkRepostStatus();
    if (_currentUserId != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('saved')
          .doc(widget.post.id)
          .get()
          .then((doc) {
        if (mounted) setState(() => _isSaved = doc.exists);
      });
    }
  }

  Future<void> _checkRepostStatus() async {
    if (_currentUserId == null) return;
    final isReposted = await PostService.instance.hasReposted(widget.post.id);
    if (mounted) {
      setState(() {
        _isReposted = isReposted;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_currentUserId == null) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('saved')
        .doc(widget.post.id);
    setState(() => _isSaved = !_isSaved);
    if (_isSaved) {
      await ref.set({'type': 'post', 'postId': widget.post.id, 'savedAt': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post saved!')));
    } else {
      await ref.delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post unsaved')));
    }
  }

  @override
  void didUpdateWidget(covariant PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.likes != oldWidget.post.likes || 
        widget.post.likedBy != oldWidget.post.likedBy ||
        widget.post.repostCount != oldWidget.post.repostCount) {
      _likeCount = widget.post.likes;
      _repostCount = widget.post.repostCount;
      _isLiked = _currentUserId != null && widget.post.likedBy.contains(_currentUserId);
    }
  }

  Future<void> _handleLike() async {
    if (_currentUserId == null) return;
    
    // Save previous state for rollback
    final bool previousIsLiked = _isLiked;
    final int previousLikeCount = _likeCount;

    // Optimistic UI update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await PostService.instance.likePost(widget.post.id, _currentUserId);
        
        // Notify post owner
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && _currentUserId != widget.post.userId) {
          await NotificationService.sendNotification(
            recipientId: widget.post.userId,
            senderId: currentUser.uid,
            senderName: currentUser.displayName ?? 'User',
            senderAvatar: currentUser.photoURL ?? '',
            type: 'like',
            message: 'liked your post',
            postId: widget.post.id,
          );
        }
      } else {
        await PostService.instance.unlikePost(widget.post.id, _currentUserId);
      }
    } catch (e) {
      // Rollback UI update if Firebase fails
      setState(() {
        _isLiked = previousIsLiked;
        _likeCount = previousLikeCount;
      });
      developer.log('Error toggling like', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like status. Please try again.')),
        );
      }
    }
  }

  Future<void> _handleRepost() async {
    if (_currentUserId == null) return;

    final bool previousIsReposted = _isReposted;
    final int previousCount = _repostCount;

    // Optimistic UI
    setState(() {
      _isReposted = !_isReposted;
      _repostCount += _isReposted ? 1 : -1;
    });

    try {
      if (_isReposted) {
        await PostService.instance.repostPost(widget.post);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reposted! 🎉 check your profile'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await PostService.instance.undoRepost(widget.post);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Repost removed')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isReposted = previousIsReposted;
        _repostCount = previousCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }



  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    String relative;
    if (difference.inSeconds < 60) {
      relative = 'Just now';
    } else if (difference.inMinutes < 60) {
      relative = '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      relative = '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      relative = '${difference.inDays}d ago';
    } else {
      relative = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
    
    return relative;
  }

  String _getExactTime(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$displayHour:$minute $period';
  }

  String _getFullTimestamp(DateTime timestamp) {
    return '${_formatTimestamp(timestamp)} • ${_getExactTime(timestamp)}';
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Post?"),
          content: const Text("Are you sure you want to delete this post? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close confirmation dialog
                _handleDeletePost();
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDeletePost() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await PostService.instance.deletePost(widget.post.id);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  void _navigateToComments() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsScreen(post: widget.post)));
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, 
                height: 4, 
                margin: const EdgeInsets.only(bottom: 8), 
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
              )),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About this account'),
              onTap: () {
                Navigator.pop(context);
                final uId = widget.post.isRepost ? widget.post.originalUserId! : widget.post.userId;
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: uId)));
              },
            ),
            if (_currentUserId == widget.post.userId)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmationDialog();
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.hide_source_outlined, color: Colors.orange),
                title: const Text('Hide Post', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _isHidden = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post hidden. You won\'t see this post again.')),
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isHidden) return const SizedBox.shrink();
    developer.log('=== BUILDING POST ===');
    developer.log('Post ID: ${widget.post.id}');
    developer.log('Type: ${widget.post.type}');
    developer.log('User: ${widget.post.username}');
    developer.log('Content exists: ${widget.post.content.isNotEmpty}');
    developer.log('====================');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Repost Indicator ──────────────────────────────────────────────
          if (widget.post.isRepost)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.repeat_rounded,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  UserPhotoWidget(userId: widget.post.userId, radius: 9),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: ProfileScreen(userId: widget.post.userId)),
                    ),
                    child: Text(
                      widget.post.userId == _currentUserId
                          ? 'You reposted'
                          : '@${widget.post.username} reposted',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final targetId = widget.post.isRepost 
                        ? widget.post.originalUserId! 
                        : widget.post.userId;
                    Navigator.push(context, SlidePageRoute(page: ProfileScreen(userId: targetId)));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: UserPhotoWidget(
                      userId: widget.post.isRepost 
                          ? widget.post.originalUserId! 
                          : widget.post.userId,
                      radius: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final targetId = widget.post.isRepost 
                          ? widget.post.originalUserId! 
                          : widget.post.userId;
                      Navigator.push(context, SlidePageRoute(page: ProfileScreen(userId: targetId)));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.isRepost 
                              ? (widget.post.originalUsername ?? "Original User")
                              : (widget.post.username.isNotEmpty ? widget.post.username : "Unknown User"),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          _getFullTimestamp(widget.post.timestamp),
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 20, color: Colors.white),
                  onPressed: _showPostOptions,
                ),
              ],
            ),
          ),

          // Caption
          if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.post.caption!, 
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
              ),
            ),

          // Mood Indicator Section
          if (widget.post.type == PostType.mood)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.withOpacity(0.15),
                    Colors.orange.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    widget.post.moodEmoji ?? '😊',
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feeling ${widget.post.moodLabel ?? 'Happy'}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.post.timeRemaining,
                              style: TextStyle(
                                color: Colors.amber.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Content
          if (widget.post.type == PostType.text || widget.post.type == PostType.mood)
            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  widget.post.content, 
                  style: const TextStyle(
                    fontSize: 15, 
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: AppTheme.surfaceLighter,
                  constraints: const BoxConstraints(minHeight: 200, maxHeight: 500),
                  width: double.infinity,
                  child: _buildContent(),
                ),
              ),
            ),

          // Interaction Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                _buildAnimatedLikeButton(),
                _actionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: widget.post.comments.toString(),
                  onTap: _navigateToComments,
                ),
                _actionButton(
                  icon: Icons.repeat_rounded,
                  label: _repostCount.toString(),
                  color: _isReposted ? Colors.green : null,
                  onTap: _handleRepost,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isSaved ? AppTheme.primaryPurple : AppTheme.textSecondary,
                    size: 24,
                  ),
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),

          // Top Replies Preview
          StreamBuilder<List<Comment>>(
            stream: CommentService.instance.getLatestCommentsStream(widget.post.id, limit: 2),
            builder: (context, snapshot) {
              final topComments = snapshot.data ?? [];
              if (topComments.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: GestureDetector(
                  onTap: _navigateToComments,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLighter.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.post.comments > 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  "View all ${widget.post.comments} comments",
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textSecondary),
                              ],
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              "Top Comments",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                            ),
                          ),
                        ...topComments.reversed.map<Widget>(
                          (comment) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.3),
                                children: [
                                  TextSpan(text: "${comment.username}  ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: comment.text),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.post.type == PostType.video) return YoutubePlayerWidget(videoUrl: widget.post.content);
    if (widget.post.type == PostType.tiktok) return TikTokPlayerPlaceholder(url: widget.post.content);
    if (widget.post.type == PostType.image) return AnimatedBlurImage(imageUrl: widget.post.content, fit: BoxFit.cover);
    return const SizedBox();
  }

  Widget _buildAnimatedLikeButton() {
    return BounceClick(
      onTap: _handleLike,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: _isLiked
                  ? ShaderMask(
                      key: const ValueKey('liked'),
                      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                      child: const Icon(Icons.favorite_rounded, size: 24, color: Colors.white),
                    )
                  : const Icon(Icons.favorite_border_rounded, size: 24, key: ValueKey('unliked'), color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              _likeCount.toString(), 
              style: TextStyle(
                fontSize: 13, 
                color: _isLiked ? AppTheme.primaryPink : AppTheme.textSecondary, 
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, Color? color, required VoidCallback onTap}) {
    return BounceClick(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color ?? AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: color ?? AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
