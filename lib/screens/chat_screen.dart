import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoURL;
  
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoURL,
  });
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isTyping = false;
  late Stream<List<Message>> _messageStream;
  late Stream<Chat> _chatStream;
  List<Message> _cachedMessages = [];
  bool _hasMarkedRead = false; // Only mark-as-read once, lazily after first data
  
  @override
  void initState() {
    super.initState();
    // Do NOT call markAsRead here — it triggers batch Firestore writes that
    // cause the message stream to re-query and briefly emit empty data.
    _messageController.addListener(_onTypingChanged);
    _messageStream = ChatService.instance.getMessagesStream(widget.chatId);
    _chatStream = FirebaseFirestore.instance
      .collection('chats')
      .doc(widget.chatId)
      .snapshots(includeMetadataChanges: false)
      .map((doc) => Chat.fromFirestore(doc));
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _markAsRead() async {
    // Deferred: only run after we know messages exist, to avoid
    // triggering a batch write that disrupts the message stream on open.
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await ChatService.instance.markAsRead(widget.chatId);
    }
  }
  
  void _onTypingChanged() {
    final isTyping = _messageController.text.isNotEmpty;
    if (isTyping != _isTyping) {
      setState(() {
        _isTyping = isTyping;
      });
      ChatService.instance.setTyping(widget.chatId, isTyping);
    }
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    ChatService.instance.setTyping(widget.chatId, false);
    
    try {
      await ChatService.instance.sendMessage(
        chatId: widget.chatId,
        content: text,
      );
      
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _sendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1080,
      );
      
      if (image == null) return;
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Convert to Base64
      final bytes = await image.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      // Send image message
      await ChatService.instance.sendImageMessage(
        chatId: widget.chatId,
        base64Image: base64Image,
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
        backgroundColor: AppTheme.surfaceDark,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage: _getProfileImage(widget.otherUserPhotoURL),
              child: _getProfileImage(widget.otherUserPhotoURL) == null
                ? const Icon(Icons.person, size: 18, color: Colors.grey)
                : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                    // Typing indicator
                    StreamBuilder<Chat>(
                      stream: _chatStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        
                        final chat = snapshot.data;
                        if (chat == null) return const SizedBox.shrink();
                        
                        final isTyping = chat.isOtherUserTyping(currentUserId ?? '');
                      
                      if (!isTyping) return const SizedBox.shrink();
                      
                      return const Text(
                        'typing...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryPurple,
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show chat options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: currentUserId == null 
              ? const Center(child: Text('Please log in'))
              : StreamBuilder<List<Message>>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    // Only update cache with non-empty server-confirmed data
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      _cachedMessages = snapshot.data!;
                      // Lazily mark as read once after first real data arrives
                      if (!_hasMarkedRead) {
                        _hasMarkedRead = true;
                        _markAsRead();
                      }
                    }

                    // Show spinner only on very first load (cache still empty)
                    if (_cachedMessages.isEmpty) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryPurple,
                          ),
                        );
                      }
                      // Confirmed empty conversation
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Send a message to start chatting',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // Use cached list — always visible, never flickers
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      itemCount: _cachedMessages.length,
                      itemBuilder: (context, index) {
                        final message = _cachedMessages[index];
                        final isSentByMe = message.senderId == currentUserId;
                        final showAvatar = !isSentByMe && 
                          (index == _cachedMessages.length - 1 ||
                           _cachedMessages[index + 1].senderId != message.senderId);
                        
                        return _buildMessageBubble(
                          message,
                          isSentByMe,
                          showAvatar,
                        );
                      },
                    );
                  },
                ),
          ),
          
          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(
    Message message,
    bool isSentByMe,
    bool showAvatar,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isSentByMe 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe && showAvatar)
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[800],
              backgroundImage: _getProfileImage(message.senderPhotoURL),
              child: _getProfileImage(message.senderPhotoURL) == null
                ? const Icon(Icons.person, size: 14, color: Colors.grey)
                : null,
            )
          else if (!isSentByMe)
            const SizedBox(width: 28),
          
          const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              padding: message.type == MessageType.text
                ? const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  )
                : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isSentByMe 
                  ? AppTheme.primaryPurple 
                  : AppTheme.surfaceDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isSentByMe ? 16 : 4),
                  bottomRight: Radius.circular(isSentByMe ? 4 : 16),
                ),
              ),
              child: message.type == MessageType.text
                ? Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _getProfileImage(message.content) != null
                      ? Image(
                          image: _getProfileImage(message.content)!,
                          fit: BoxFit.cover,
                          width: 200,
                        )
                      : Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.image,
                            size: 64,
                            color: Colors.grey,
                          ),
                        ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Image button
            IconButton(
              icon: const Icon(
                Icons.image,
                color: AppTheme.primaryPurple,
              ),
              onPressed: _sendImage,
            ),
            
            // Text field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
