import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import '../models/story_model.dart';
import '../services/story_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });
  
  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> 
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  Timer? _autoAdvanceTimer;
  final AuthService _authService = AuthService();
  
  ImageProvider? _currentMediaImage;
  ImageProvider? _currentAvatarImage;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 5),
    );
    
    _progressController.addListener(() {
      setState(() {});
    });
    
    _updateCachedImages();
    _startStory();
  }
  
  @override
  void dispose() {
    _progressController.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }
  
  void _updateCachedImages() {
    if (widget.stories.isEmpty || _currentIndex >= widget.stories.length) return;
    final story = widget.stories[_currentIndex];
    _currentMediaImage = _getImage(story.mediaUrl);
    _currentAvatarImage = _getImage(story.avatarUrl);
  }
  
  void _startStory() {
    _progressController.reset();
    _progressController.forward();
    _autoAdvanceTimer?.cancel();
    
    _autoAdvanceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _nextStory();
      }
    });
    
    if (widget.stories.isEmpty || _currentIndex >= widget.stories.length) return;
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId != null && 
        currentUserId != widget.stories[_currentIndex].userId) {
      StoryService.instance.markAsViewed(
        widget.stories[_currentIndex].id,
        currentUserId,
      );
    }
  }
  
  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _updateCachedImages();
        _startStory();
      });
    } else {
      Navigator.pop(context);
    }
  }
  
  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _updateCachedImages();
        _startStory();
      });
    } else {
      Navigator.pop(context);
    }
  }
  
  void _pauseStory() {
    _progressController.stop();
    _autoAdvanceTimer?.cancel();
  }
  
  void _resumeStory() {
    _progressController.forward();
    final currentProgress = _progressController.value;
    final remainingMillis = ((1 - currentProgress) * 5000).round();
    
    _autoAdvanceTimer?.cancel();
    if (remainingMillis > 0) {
      _autoAdvanceTimer = Timer(Duration(milliseconds: remainingMillis), () {
        if (mounted) _nextStory();
      });
    }
  }
  
  ImageProvider? _getImage(String? url) {
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
  
  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
  
  void _showDeleteConfirmation() {
    _pauseStory();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Delete Story?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this story?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _resumeStory();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteCurrentStory();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteCurrentStory() async {
    try {
      final storyId = widget.stories[_currentIndex].id;
      await StoryService.instance.deleteStory(storyId);
      
      setState(() {
        widget.stories.removeAt(_currentIndex);
        
        if (widget.stories.isEmpty) {
          Navigator.pop(context);
        } else {
          if (_currentIndex >= widget.stories.length) {
            _currentIndex = widget.stories.length - 1;
          }
          _updateCachedImages();
          _startStory();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting story: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _resumeStory();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty || _currentIndex >= widget.stories.length) {
       return const Scaffold(backgroundColor: Colors.black);
    }
    
    final currentStory = widget.stories[_currentIndex];
    final isOwner = _authService.currentUser?.uid == currentStory.userId;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final tapPosition = details.globalPosition.dx;
          
          if (tapPosition < screenWidth / 3) {
            _previousStory();
          } else if (tapPosition > 2 * screenWidth / 3) {
            _nextStory();
          }
        },
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 10) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            // Content
            // Content
            Positioned.fill(
              child: (currentStory.mediaType == 'text' || currentStory.mediaType == 'mood')
                ? Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryPurple,
                          AppTheme.primaryPink.withOpacity(0.8),
                          AppTheme.surfaceDark,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentStory.mediaUrl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: currentStory.mediaType == 'mood' ? 42 : 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (currentStory.caption != null && currentStory.caption!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                currentStory.caption!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: _currentMediaImage != null
                      ? Image(
                          image: _currentMediaImage!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          gaplessPlayback: true,
                        )
                      : const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 64,
                        ),
                  ),
            ),
            
            // Progress
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: List.generate(
                      widget.stories.length,
                      (index) => Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: index < _currentIndex
                              ? 1.0
                              : index == _currentIndex
                                ? _progressController.value
                                : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 26, 8, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: _currentAvatarImage,
                        child: _currentAvatarImage == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentStory.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _getTimeAgo(currentStory.timestamp),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          onPressed: _showDeleteConfirmation,
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
