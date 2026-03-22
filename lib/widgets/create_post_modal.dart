import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/reel_service.dart';
import 'dart:typed_data';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import 'dart:developer' as developer;
import '../widgets/user_photo_widget.dart';

// ─── Post Type Selector ───────────────────────────────────────────────────────

enum _CreateType { text, photo, video, mood }

// ─── Main Modal Widget ────────────────────────────────────────────────────────

class CreatePostModal extends StatefulWidget {
  const CreatePostModal({super.key});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _textController = TextEditingController();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  bool _isPosting = false;
  bool _isPublic = false; // Default: Friends Only (Kakonek)

  _CreateType _createType = _CreateType.text;
  XFile? _selectedImageFile;
  XFile? _selectedVideoFile;
  String? _selectedVideoName;
  String? _selectedMood;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _togglePrivacy() => setState(() => _isPublic = !_isPublic);

  // ─── Media Pickers ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _selectedImageFile = image;
      _selectedVideoFile = null;
      _selectedVideoName = null;
      _createType = _CreateType.photo;
    });
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (video == null) return;

    setState(() {
      _selectedVideoFile = video;
      _selectedVideoName = video.name;
      _selectedImageFile = null;
      _createType = _CreateType.video;
    });
  }

  void _clearMedia() {
    setState(() {
      _selectedImageFile = null;
      _selectedVideoFile = null;
      _selectedVideoName = null;
      _selectedMood = null;
      _createType = _CreateType.text;
    });
  }

  void _showMoodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'How are you feeling?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10),

            // Emoji Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMoodOption('😊', 'Happy'),
                  _buildMoodOption('😂', 'Laughing'),
                  _buildMoodOption('🥰', 'Loved'),
                  _buildMoodOption('😎', 'Cool'),
                  _buildMoodOption('🤔', 'Thinking'),
                  _buildMoodOption('😴', 'Sleepy'),
                  _buildMoodOption('🥳', 'Celebrating'),
                  _buildMoodOption('😇', 'Blessed'),
                  _buildMoodOption('🤗', 'Grateful'),
                  _buildMoodOption('😌', 'Relaxed'),
                  _buildMoodOption('🙃', 'Silly'),
                  _buildMoodOption('😏', 'Confident'),
                  _buildMoodOption('🤩', 'Excited'),
                  _buildMoodOption('😅', 'Relieved'),
                  _buildMoodOption('🥺', 'Emotional'),
                  _buildMoodOption('😢', 'Sad'),
                  _buildMoodOption('😤', 'Frustrated'),
                  _buildMoodOption('😱', 'Shocked'),
                  _buildMoodOption('🤯', 'Mind Blown'),
                  _buildMoodOption('💪', 'Strong'),
                  _buildMoodOption('🔥', 'On Fire'),
                  _buildMoodOption('✨', 'Blessed'),
                  _buildMoodOption('💯', 'Perfect'),
                  _buildMoodOption('❤️', 'In Love'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodOption(String emoji, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMood = '$emoji $label';
          _createType = _CreateType.mood;
          _selectedImageFile = null;
          _selectedVideoFile = null;
          _textController.text = 'Feeling $label $emoji';
        });
        Navigator.pop(context); // Close mood picker
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Extract Hashtags ───────────────────────────────────────────────────────

  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'#(\w+)');
    return regex
        .allMatches(text)
        .map((m) => m.group(1)!.toLowerCase())
        .toList();
  }

  // ─── Post Handler ───────────────────────────────────────────────────────────

  Future<void> _handlePost() async {
    final text = _textController.text.trim();
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    setState(() => _isPosting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data() ?? {};

      // ── Handle MOOD posts (24hr expiring posts) ───────────────────────────
      if (_createType == _CreateType.mood && _selectedMood != null) {
        final parts = _selectedMood!.split(' ');
        final emoji = parts[0];
        final label = parts.sublist(1).join(' ');

        final moodPost = Post(
          id: '',
          userId: currentUser.uid,
          username: userData['username'] ?? 'user',
          avatarUrl: userData['photoURL'] ?? '',
          content: text.isEmpty ? 'Feeling $label' : text,
          type: PostType.mood,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          moodEmoji: emoji,
          moodLabel: label,
          isPublic: _isPublic,
          likes: 0,
          comments: 0,
          likedBy: [],
        );

        developer.log('=== CREATING MOOD POST ===');
        developer.log('Type: ${moodPost.type}');
        developer.log('Emoji: ${moodPost.moodEmoji}');
        developer.log('Label: ${moodPost.moodLabel}');
        developer.log('Content: ${moodPost.content}');
        developer.log('Expires: ${moodPost.expiresAt}');
        developer.log('========================');

        await PostService.instance.createPost(post: moodPost);

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Mood shared! ✨ Expires in 24 hours'),
              backgroundColor: Colors.amber,
            ),
          );
        }
        return;
      }

      // ── Handle VIDEO posts (Reels) ─────────────────────────────────────────
      if (_createType == _CreateType.video && _selectedVideoFile != null) {
        final videoUrl = await StorageService.instance.uploadVideo(
          _selectedVideoFile!.path,
        );

        await ReelService.instance.createReel(
          videoUrl: videoUrl,
          caption: text.isEmpty ? '📹 New Reel' : text,
          hashtags: _extractHashtags(text),
        );

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Reel uploaded! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // ── Handle IMAGE or TEXT posts ─────────────────────────────────────────
      String content = text;
      if (_createType == _CreateType.photo && _selectedImageFile != null) {
        content = await StorageService.instance.uploadImage(
          _selectedImageFile!.path,
          folder: 'posts',
        );
      }

      final post = Post(
        id: '',
        userId: currentUser.uid,
        username: userData['username'] ?? 'user',
        avatarUrl: userData['photoURL'] ?? '',
        content: content,
        caption: _createType == _CreateType.photo ? text : null,
        type: _createType == _CreateType.photo ? PostType.image : PostType.text,
        timestamp: DateTime.now(),
        isPublic: _isPublic,
        likes: 0,
        comments: 0,
        likedBy: [],
      );

      await PostService.instance.createPost(post: post);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Posted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }


  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, -4),
            ),
            BoxShadow(
              color: AppTheme.primaryPink.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -2,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle ───────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                child: Row(
                  children: [
                    Text(
                      _createType == _CreateType.video
                          ? 'Upload Reel 🎬'
                          : 'Create Post',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10),

              // ── Author Row ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    UserPhotoWidget(
                      userId: _authService.currentUser?.uid ?? '',
                      radius: 20,
                      showBorder: true,
                      borderGradient: AppTheme.primaryGradient,
                      borderWidth: 2,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StreamBuilder<DocumentSnapshot>(
                          stream: _authService.getUserDataStream(),
                          builder: (context, snapshot) {
                            final userData =
                                snapshot.data?.data()
                                    as Map<String, dynamic>? ??
                                {};
                            return Text(
                              userData['displayName'] ??
                                  _authService.currentUser?.displayName ??
                                  'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _createType == _CreateType.video
                              ? null // Reels are always public
                              : _togglePrivacy,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _createType == _CreateType.video
                                      ? Icons.public
                                      : (_isPublic
                                            ? Icons.public
                                            : Icons.group_outlined),
                                  size: 12,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _createType == _CreateType.video
                                      ? 'Public Reel'
                                      : (_isPublic
                                            ? 'Public'
                                            : 'Kakonek (Friends)'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                if (_createType != _CreateType.video)
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    size: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Text Input ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _textController,
                  maxLines: _createType == _CreateType.text ? 5 : 3,
                  minLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _createType == _CreateType.video
                        ? "Add a caption... #hashtags"
                        : _createType == _CreateType.mood
                            ? "Share more about how you're feeling..."
                            : "What's on your mind?",
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // ── Mood Preview Indicator ────────────────────────────────────
              if (_selectedMood != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedMood!.split(' ')[0], // Emoji
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedMood!,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Expires in 24 hours',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () {
                            setState(() {
                              _selectedMood = null;
                              _createType = _CreateType.text;
                              _textController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Media Preview ─────────────────────────────────────────────
              if (_selectedImageFile != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FutureBuilder<Uint8List>(
                          future: _selectedImageFile!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 180,
                              );
                            }
                            return Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.black26,
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: _clearMedia,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_selectedVideoName != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryPurple.withOpacity(0.4),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedVideoName!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Video ready to upload as Reel',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: _clearMedia,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Media Type Buttons ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _MediaTypeBtn(
                      icon: Icons.image_outlined,
                      label: 'Photo',
                      color: Colors.green,
                      isSelected: _createType == _CreateType.photo,
                      onTap: _pickImage,
                    ),
                    const SizedBox(width: 16),
                    _MediaTypeBtn(
                      icon: Icons.videocam_outlined,
                      label: 'Reel',
                      color: Colors.redAccent,
                      isSelected: _createType == _CreateType.video,
                      onTap: _pickVideo,
                    ),
                    const SizedBox(width: 16),
                    _MediaTypeBtn(
                      icon: Icons.mood_outlined,
                      label: 'Mood',
                      color: Colors.amber,
                      isSelected: _createType == _CreateType.mood,
                      onTap: _showMoodPicker,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Post Button ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GlassmorphicEffects.gradientButton(
                    text: _createType == _CreateType.video
                        ? 'Upload Reel 🎬'
                        : _createType == _CreateType.mood
                            ? 'Share Mood ✨'
                            : 'Post',
                    isLoading: _isPosting,
                    onPressed: _handlePost,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Media Type Selector Button ───────────────────────────────────────────────

class _MediaTypeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _MediaTypeBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
