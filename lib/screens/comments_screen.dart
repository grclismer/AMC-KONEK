import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';
import '../widgets/user_photo_widget.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../utils/error_handler.dart';
import '../utils/app_localizations.dart';

class CommentsScreen extends StatefulWidget {
  final Post post;

  CommentsScreen({super.key, required this.post});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isPosting = false;
  AppLocalizations get _l => AppLocalizations.instance;
  
  // Threading state
  Comment? _replyingTo;
  late Stream<List<Comment>> _commentsStream;
  final Set<String> _expandedCommentIds = {};

  @override
  void initState() {
    super.initState();
    _commentsStream = CommentService.instance.getCommentsStream(widget.post.id);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _startReply(Comment comment) {
    setState(() {
      _replyingTo = comment;
    });
    _focusNode.requestFocus();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    
    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to comment.')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      String username = currentUser.displayName ?? '';
      if (username.isEmpty || username == 'User') {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        username = userDoc.data()?['username'] ?? 'User';
      }

      final newComment = Comment(
        id: '',
        postId: widget.post.id,
        userId: currentUser.uid,
        username: username,
        avatarUrl: currentUser.photoURL ?? '',
        text: text,
        timestamp: DateTime.now(),
        // Flatten deep threads: if replying to a reply, parent is the original top-level comment
        replyToId: _replyingTo?.replyToId ?? _replyingTo?.id,
        replyToUsername: _replyingTo?.username,
      );

      await CommentService.instance.addComment(newComment);
      
      if (currentUser.uid != widget.post.userId) {
        NotificationService.send(
          recipientId: widget.post.userId, 
          senderId: currentUser.uid, 
          senderName: username, 
          type: 'comment', 
          message: 'commented on your post', 
          postId: widget.post.id
        );
      }
      
      // Auto-expand the parent if it was a reply
      if (newComment.replyToId != null) {
        setState(() {
          _expandedCommentIds.add(newComment.replyToId!);
        });
      }

      _commentController.clear();
      _cancelReply();
      
      if (_replyingTo == null) {
        Future.delayed(Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorHandler.commentError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Thread", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("${_l.t('post_on')} ${widget.post.username}'s post", style: TextStyle(fontSize: 12, color: AppTheme.adaptiveTextSecondary(context))),
          ],
        ),
        elevation: 0,
        backgroundColor: AppTheme.surface(context).withOpacity(0.8),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _commentsStream,
              initialData: [],
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && snapshot.data?.isEmpty == true) {
                  return Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                  );
                }
                
                final comments = snapshot.data ?? [];
                
                if (comments.isEmpty) {
                  return Center(child: Text(_l.t('comment_no_comments'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context))));
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: comments.length,
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return CommentTile(
                      key: ValueKey('comment_${comment.id}'),
                      comment: comment,
                      postId: widget.post.id,
                      currentUserId: currentUserId,
                      onReply: _startReply,
                      isExpanded: _expandedCommentIds.contains(comment.id),
                      onExpandedChanged: (isExpanded) {
                        setState(() {
                          if (isExpanded) {
                            _expandedCommentIds.add(comment.id);
                          } else {
                            _expandedCommentIds.remove(comment.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          
          // Reply Bar (Visible when replying)
          if (_replyingTo != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.surfaceColor(context).withOpacity(0.3),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: AppTheme.adaptiveTextSecondary(context)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${_l.t('comment_reply_label')} @${_replyingTo!.username}",
                      style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(Icons.close, size: 18, color: AppTheme.adaptiveTextSecondary(context)),
                  ),
                ],
              ),
            ),
            
          // Comment Input
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    UserPhotoWidget(
                      userId: currentUserId ?? '',
                      radius: 18,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.background(context),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          maxLines: 5,
                          minLines: 1,
                          style: TextStyle(color: AppTheme.adaptiveText(context)),
                          decoration: InputDecoration(
                            hintText: _replyingTo != null ? _l.t('comment_reply') : _l.t('comment_add'),
                            hintStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      onPressed: _isPosting ? null : _postComment,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryPurple,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isPosting 
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_l.t('comment_post'), style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommentTile extends StatefulWidget {
  final Comment comment;
  final String postId;
  final String? currentUserId;
  final Function(Comment) onReply;
  final bool isReply;
  final bool isExpanded;
  final ValueChanged<bool> onExpandedChanged;

  CommentTile({
    super.key,
    required this.comment,
    required this.postId,
    this.currentUserId,
    required this.onReply,
    this.isReply = false,
    this.isExpanded = false,
    required this.onExpandedChanged,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  AppLocalizations get _l => AppLocalizations.instance;

  late Stream<List<Comment>> _repliesStream;

  @override
  void initState() {
    super.initState();
    _repliesStream = CommentService.instance.getRepliesStream(widget.postId, widget.comment.id);
  }

  void _toggleReplies() {
    widget.onExpandedChanged(!widget.isExpanded);
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  void _handleDeleteComment() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface(context),
          title: Text(_l.t('comment_delete'), style: TextStyle(color: AppTheme.adaptiveText(context))),
          content: Text(_l.t('comment_delete_message'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_l.t('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                try {
                  CommentService.instance.deleteComment(widget.postId, widget.comment.id);
                } catch(e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppErrorHandler.commentError(e))),
                  );
                }
              },
              child: Text(_l.t('delete'), style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _handleLikeComment() {
    if (widget.currentUserId == null) return;
    final isLiked = widget.comment.likedBy.contains(widget.currentUserId);
    
    if (isLiked) {
      CommentService.instance.unlikeComment(widget.postId, widget.comment.id, widget.currentUserId!);
    } else {
      CommentService.instance.likeComment(widget.postId, widget.comment.id, widget.currentUserId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = widget.currentUserId != null && widget.comment.likedBy.contains(widget.currentUserId);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: widget.isReply ? 52 : 16,
            right: 16,
            top: 12,
            bottom: widget.comment.replyCount > 0 && !widget.isExpanded ? 12 : 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserPhotoWidget(
                userId: widget.comment.userId,
                radius: widget.isReply ? 14 : 18,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.comment.username, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: widget.isReply ? 12 : 14, 
                            color: AppTheme.adaptiveText(context)
                          )
                        ),
                        SizedBox(width: 6),
                        Text(
                          "· ${_formatTimestamp(widget.comment.timestamp)}", 
                          style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 12)
                        ),
                      ],
                    ),
                    if (widget.comment.replyToUsername != null && !widget.isReply)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          "${_l.t('comment_reply_label')} @${widget.comment.replyToUsername}",
                          style: TextStyle(color: AppTheme.primaryPurple, fontSize: 12),
                        ),
                      ),
                    SizedBox(height: 4),
                    Text(
                      widget.comment.text, 
                      style: TextStyle(
                        fontSize: widget.isReply ? 13 : 15, 
                        color: AppTheme.adaptiveText(context), 
                        height: 1.4
                      )
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        // Like
                        GestureDetector(
                          onTap: _handleLikeComment,
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                size: 16,
                                color: isLiked ? Colors.redAccent : AppTheme.textSecondaryColor(context),
                              ),
                              if (widget.comment.likes > 0) ...[
                                SizedBox(width: 4),
                                Text(
                                  widget.comment.likes.toString(),
                                  style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: 20),
                        // Reply
                        GestureDetector(
                          onTap: () => widget.onReply(widget.comment),
                          child: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppTheme.adaptiveTextSecondary(context)),
                        ),
                        if (widget.currentUserId == widget.comment.userId) ...[
                          SizedBox(width: 20),
                          GestureDetector(
                            onTap: _handleDeleteComment,
                            child: Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.adaptiveTextSecondary(context)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Replies Toggle
        if (widget.comment.replyCount > 0 && !widget.isReply)
          Padding(
            padding: EdgeInsets.only(left: 62, bottom: 8),
            child: GestureDetector(
              onTap: _toggleReplies,
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 1,
                    color: AppTheme.primaryPurple.withOpacity(0.5),
                  ),
                  SizedBox(width: 8),
                  Text(
                    widget.isExpanded ? _l.t('comment_hide_replies') : "${_l.t('comment_view_replies')} ${widget.comment.replyCount} ${_l.t('comment_replies')}",
                    style: TextStyle(color: AppTheme.primaryPurple, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
        if (widget.isExpanded && !widget.isReply)
          StreamBuilder<List<Comment>>(
            stream: _repliesStream,
            initialData: [],
            builder: (context, snapshot) {
              final replies = snapshot.data ?? [];
              
              if (replies.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.only(left: 32, top: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
                  ),
                );
              }

              if (replies.isEmpty) return SizedBox.shrink();

              return Column(
                children: replies.map((reply) => CommentTile(
                  key: ValueKey('reply_${reply.id}'),
                  comment: reply,
                  postId: widget.postId,
                  currentUserId: widget.currentUserId,
                  onReply: widget.onReply,
                  isReply: true,
                  isExpanded: false,
                  onExpandedChanged: (_) {}, // Replies don't have further nesting
                )).toList(),
              );
            },
          ),
          
        if (!widget.isReply)
          Divider(height: 1, color: AppTheme.borderColor(context)),
      ],
    );
  }
}