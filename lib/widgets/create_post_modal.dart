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
import '../utils/error_handler.dart';
import 'package:social_media_app/utils/app_localizations.dart';

// ─── Post Type Selector ───────────────────────────────────────────────────────

enum _CreateType { text, photo, video, mood }

// ─── Main Modal Widget ────────────────────────────────────────────────────────

class CreatePostModal extends StatefulWidget {
  final String? initialType;
  const CreatePostModal({super.key, this.initialType});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _textController = TextEditingController();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  bool _isPosting = false;
  String _privacy = 'public';
  String _reelPrivacy = 'public';

  _CreateType _createType = _CreateType.text;
  XFile? _selectedImageFile;
  XFile? _selectedVideoFile;
  String? _selectedVideoName;
  String? _selectedMood;
  AppLocalizations get _l => AppLocalizations.instance;

  @override
  void initState() {
    super.initState();
    if (widget.initialType == 'reel') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickVideo());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _currentPrivacy() => _createType == _CreateType.video ? _reelPrivacy : _privacy;

  IconData _privacyIcon() {
    switch (_currentPrivacy()) {
      case 'public': return Icons.public;
      case 'friends': return Icons.group_outlined;
      case 'private': return Icons.lock_outline;
      default: return Icons.public;
    }
  }

  String _privacyLabel() {
    switch (_currentPrivacy()) {
      case 'public': return _l.t('post_public');
      case 'friends': return _l.t('post_kakonek');
      case 'private': return _l.t('post_private');
      default: return _l.t('post_public');
    }
  }

  void _showPrivacyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppTheme.adaptiveSubtle(context), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(_l.t('post_who_can_see'), style: TextStyle(color: AppTheme.adaptiveText(context), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          _privacyOption(ctx, Icons.public, _l.t('post_public'), _l.t('post_public_desc'), 'public'),
          _privacyOption(ctx, Icons.group_outlined, _l.t('post_kakonek'), _l.t('post_kakonek_desc'), 'friends'),
          if (_createType != _CreateType.video)
            _privacyOption(ctx, Icons.lock_outline, _l.t('post_private'), _l.t('post_private_desc'), 'private'),
          SizedBox(height: 8),
        ])),
      ),
    );
  }

  Widget _privacyOption(BuildContext ctx, IconData icon, String label, String subtitle, String value) {
    final isSelected = _currentPrivacy() == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryPurple : Colors.white70),
      title: Text(label, style: TextStyle(color: isSelected ? AppTheme.primaryPurple : Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white70, fontSize: 12)),
      trailing: isSelected ? Icon(Icons.check_circle, color: AppTheme.primaryPurple) : null,
      onTap: () {
        setState(() {
          if (_createType == _CreateType.video) {
            _reelPrivacy = value;
          } else {
            _privacy = value;
          }
        });
        Navigator.pop(ctx);
      },
    );
  }

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
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _l.t('mood_question'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.adaptiveText(context),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.adaptiveText(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Divider(color: AppTheme.adaptiveSubtle(context)),

            // Emoji Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                padding: EdgeInsets.all(16),
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
            style: TextStyle(fontSize: 36),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.adaptiveTextSecondary(context),
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
          privacy: _privacy,
          isPublic: _privacy == 'public',
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
            SnackBar(
              content: Text('${_l.t('mood_success')} ✨ ${_l.t('mood_expired_desc')}'),
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
          isPublic: _reelPrivacy == 'public',
        );

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(_l.t('reel_uploaded_success')),
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
        privacy: _privacy,
        isPublic: _privacy == 'public',
        likes: 0,
        comments: 0,
        likedBy: [],
      );

      await PostService.instance.createPost(post: post);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(_l.t('post_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();

        if (errorStr.contains('IMAGE_TOO_LARGE')) {
          // Parse size: e.g. "Exception: IMAGE_TOO_LARGE:1234KB"
          final parts = errorStr.split(':');
          final size = parts.length >= 3 ? '${parts[2]}' : 'Unknown';

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surface(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Text(_l.t('post_too_large_title'), style: TextStyle(color: AppTheme.adaptiveText(context))),
                ],
              ),
              content: Text(
                '${_l.t('post_too_large_desc')} ($size)\n\n'
                'Because Konek stores images directly in the database, files must be small. '
                'Please choose a smaller image or reduce the quality before uploading.',
                style: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_l.t('ok'), style: TextStyle(color: AppTheme.primaryPurple)),
                ),
              ],
            ),
          );
        } else if (errorStr.contains('FILE_TOO_LARGE')) {
          // Parse size: e.g. "Exception: FILE_TOO_LARGE:1234KB"
          final parts = errorStr.split(':');
          final size = parts.isNotEmpty ? parts.last : 'Unknown';

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surface(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryPurple),
                  SizedBox(width: 10),
                  Text(_l.t('reel_too_large_title'), style: TextStyle(color: AppTheme.adaptiveText(context))),
                ],
              ),
              content: Text(
                '${_l.t('reel_too_large_desc')} ($size)\n\n'
                'This limit exists because Konek stores videos directly in the database without a paid storage service. Please trim your video to under 30 seconds and try again.',
                style: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_l.t('ok'), style: TextStyle(color: AppTheme.primaryPurple)),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppErrorHandler.postError(e))),
          );
        }
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
          color: AppTheme.surface(context),
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
                  margin: EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 8, 0),
                child: Row(
                  children: [
                    Text(
                      _createType == _CreateType.video
                          ? _l.t('reel_upload_title')
                          : _l.t('post_create_title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.adaptiveText(context),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppTheme.adaptiveText(context),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: AppTheme.adaptiveSubtle(context)),

              // ── Author Row ────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
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
                    SizedBox(width: 12),
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
                              style: TextStyle(
                                color: AppTheme.adaptiveText(context),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _showPrivacyPicker(),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.adaptiveSubtle(context), borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_privacyIcon(), size: 12, color: AppTheme.adaptiveTextSecondary(context)),
                              SizedBox(width: 4),
                              Text(_privacyLabel(), style: TextStyle(fontSize: 11, color: AppTheme.adaptiveTextSecondary(context))),
                              Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.adaptiveTextSecondary(context)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Text Input ────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _textController,
                  maxLines: _createType == _CreateType.text ? 5 : 3,
                  minLines: 2,
                  style: TextStyle(color: AppTheme.adaptiveText(context)),
                  decoration: InputDecoration(
                    hintText: _createType == _CreateType.video
                        ? _l.t('reel_hint_text')
                        : _createType == _CreateType.mood
                            ? _l.t('mood_hint_text')
                            : _l.t('post_hint_text'),
                    hintStyle: TextStyle(color: AppTheme.adaptiveTextSecondary(context)),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // ── Mood Preview Indicator ────────────────────────────────────
              if (_selectedMood != null) ...[
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: EdgeInsets.all(16),
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
                          style: TextStyle(fontSize: 32),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedMood!,
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _l.t('mood_expired_desc'),
                                style: TextStyle(
                                  color: AppTheme.adaptiveTextSecondary(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: AppTheme.adaptiveTextSecondary(context)),
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
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
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
                              child: Center(child: CircularProgressIndicator()),
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
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: AppTheme.adaptiveText(context),
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
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
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
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 36,
                            ),
                            SizedBox(height: 8),
                            Text(
                              _selectedVideoName!,
                              style: TextStyle(
                                color: AppTheme.adaptiveTextSecondary(context),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              _l.t('reel_video_ready'),
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
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: AppTheme.adaptiveText(context),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 16),

              // ── Media Type Buttons ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _MediaTypeBtn(
                      icon: Icons.image_outlined,
                      label: 'Photo',
                      color: Colors.green,
                      isSelected: _createType == _CreateType.photo,
                      onTap: _pickImage,
                    ),
                    SizedBox(width: 16),
                    _MediaTypeBtn(
                      icon: Icons.videocam_outlined,
                      label: 'Reel',
                      color: Colors.redAccent,
                      isSelected: _createType == _CreateType.video,
                      onTap: _pickVideo,
                    ),
                    SizedBox(width: 16),
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

              SizedBox(height: 20),

              // ── Post Button ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondaryColor(context),
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
