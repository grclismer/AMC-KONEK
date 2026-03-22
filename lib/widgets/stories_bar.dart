import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../services/story_service.dart';
import '../models/story_model.dart';
import '../theme/app_theme.dart';
import '../screens/story_viewer_screen.dart';

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});
  
  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  final ImagePicker _picker = ImagePicker();
  
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
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final photoURL = userData['photoURL'];
        
        return StreamBuilder<List<Story>>(
          stream: StoryService.instance.getUserStoriesStream(user.uid),
          builder: (context, storiesSnapshot) {
            final stories = storiesSnapshot.data ?? [];
            final hasStories = stories.isNotEmpty;
            
            return Container(
              height: 120,
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 16,
                left: 12,
                right: 12,
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildYourStory(user, hasStories, stories, photoURL),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildYourStory(User user, bool hasStories, List<Story> stories, String? photoURL) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // Avatar with border
              GestureDetector(
                onTap: () {
                  if (hasStories) {
                    _viewStories(stories);
                  } else {
                    _showAddStoryOptions();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStories ? AppTheme.primaryGradient : null,
                    border: !hasStories ? Border.all(color: Colors.grey[700]!, width: 2) : null,
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _getProfileImage(photoURL),
                    child: _getProfileImage(photoURL) == null
                      ? const Icon(Icons.person, size: 30, color: Colors.grey)
                      : null,
                  ),
                ),
              ),
              
              // "+" button - ALWAYS SHOW
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showAddStoryOptions,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.surfaceDark,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasStories ? '${stories.length} Stories' : 'Your Story',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  void _viewStories(List<Story> stories) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          stories: stories,
          initialIndex: 0,
        ),
      ),
    );
  }
  
  void _showAddStoryOptions() {
    _showUploadDialog();
  }
  
  void _showUploadDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Add to Story',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image,
                    color: Colors.blue,
                  ),
                ),
                title: const Text(
                  'Upload Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadStoryImage();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  'Upload Video (max 15s)',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadStoryVideo();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _uploadStoryImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1920,
      );
      
      if (image == null) return;
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      final bytes = await image.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
      
      final userData = userDoc.data() ?? {};
      
      await StoryService.instance.createStory(
        userId: user.uid,
        username: userData['username'] ?? 
                  user.displayName ?? 
                  'User',
        avatarUrl: userData['photoURL'] ?? 
                   user.photoURL ?? 
                   '',
        mediaUrl: base64Image,
        mediaType: 'image',
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story uploaded!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading story: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _uploadStoryVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      
      if (video == null) return;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video support coming soon! For now, use images.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
