import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/reel_service.dart';
import '../theme/app_theme.dart';
import '../theme/effects.dart';
import '../widgets/user_photo_widget.dart';

// ─── Post Type Selector ───────────────────────────────────────────────────────

enum _CreateType { text, photo, video }

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
  String? _selectedImageBase64;
  String? _selectedVideoBase64;
  String? _selectedVideoName;

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
      imageQuality: 70,
      maxWidth: 1080,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _selectedImageBase64 =
          'data:image/jpeg;base64,${base64Encode(bytes)}';
      _selectedVideoBase64 = null;
      _selectedVideoName = null;
      _createType = _CreateType.photo;
    });
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 1),
    );
    if (video == null) return;

    // Show loading overlay while reading bytes
    setState(() => _isPosting = true);
    try {
      final bytes = await video.readAsBytes();
      setState(() {
        _selectedVideoBase64 =
            'data:video/mp4;base64,${base64Encode(bytes)}';
        _selectedVideoName = video.name;
        _selectedImageBase64 = null;
        _createType = _CreateType.video;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _clearMedia() {
    setState(() {
      _selectedImageBase64 = null;
      _selectedVideoBase64 = null;
      _selectedVideoName = null;
      _createType = _CreateType.text;
    });
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

    // Require either text or media
    if (text.isEmpty &&
        _selectedImageBase64 == null &&
        _selectedVideoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Write something or add a photo/video!")),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      if (_createType == _CreateType.video && _selectedVideoBase64 != null) {
        // ── Upload as REEL ──────────────────────────────────────────────────
        await ReelService.instance.createReel(
          videoUrl: _selectedVideoBase64!,
          caption: text.isEmpty ? '📹 New Reel' : text,
          hashtags: _extractHashtags(text),
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reel uploaded! 🎉 Check it in Reels'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ── Upload as POST (text or image) ─────────────────────────────────
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final userData = userDoc.data() ?? {};

        final post = Post(
          id: '',
          userId: currentUser.uid,
          username: userData['username'] ??
              currentUser.email?.split('@')[0] ??
              'User',
          avatarUrl:
              userData['photoURL'] ?? currentUser.photoURL ?? '',
          content: _createType == _CreateType.photo && _selectedImageBase64 != null
              ? _selectedImageBase64!
              : text,
          caption: _createType == _CreateType.photo ? text : null,
          type: _createType == _CreateType.photo
              ? PostType.image
              : PostType.text,
          likes: 0,
          comments: 0,
          likedBy: [],
          isPublic: _isPublic,
          timestamp: DateTime.now(),
        );

        await PostService.instance.createPost(post: post);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Posted successfully!')),
          );
        }
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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
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
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10),

              // ── Author Row ────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(children: [
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
                          final userData = snapshot.data?.data()
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
                              horizontal: 8, vertical: 2),
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
                                const Icon(Icons.arrow_drop_down,
                                    size: 14,
                                    color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
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
                        : "What's on your mind?",
                    hintStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // ── Media Preview ─────────────────────────────────────────────
              if (_selectedImageBase64 != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(_selectedImageBase64!.split(',').last),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 180,
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
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],

              if (_selectedVideoName != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Stack(children: [
                    Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppTheme.primaryPurple.withOpacity(0.4)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            _selectedVideoName!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Video ready to upload as Reel',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
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
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ]),
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
                      isSelected: false,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Mood feature coming soon!')),
                      ),
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
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
