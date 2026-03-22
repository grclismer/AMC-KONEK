import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../models/reel_model.dart';
import '../services/reel_service.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../theme/app_theme.dart';

// ─── Reels Page ───────────────────────────────────────────────────────────────

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _showKakonekFeed = true;
  List<Reel> _cachedReels = []; // Persistent cache — never goes blank

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UploadReelSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final currentUserId = AuthService().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TopTab(
              label: 'Kakonek',
              isSelected: _showKakonekFeed,
              onTap: () => setState(() => _showKakonekFeed = true),
            ),
            const SizedBox(width: 24),
            _TopTab(
              label: 'Para sa Iyo',
              isSelected: !_showKakonekFeed,
              onTap: () => setState(() => _showKakonekFeed = false),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call_rounded, color: Colors.white),
            tooltip: 'Upload Reel',
            onPressed: _showUploadSheet,
          ),
        ],
      ),
      body: StreamBuilder<List<Reel>>(
        stream: ReelService.instance.getReelsStream(),
        builder: (context, snapshot) {
          // Persistent cache: never blank on transient empty emit
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            _cachedReels = snapshot.data!;
          }

          if (_cachedReels.isEmpty) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryPurple),
              );
            }
            return _EmptyReelsState(onUpload: _showUploadSheet);
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _cachedReels.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              ReelService.instance.incrementViews(_cachedReels[index].id);
            },
            itemBuilder: (context, index) => _ReelPlayer(
              key: ValueKey(_cachedReels[index].id),
              reel: _cachedReels[index],
              currentUserId: currentUserId,
              isActive: index == _currentIndex,
            ),
          );
        },
      ),
    );
  }
}

// ─── Top Tab ──────────────────────────────────────────────────────────────────

class _TopTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TopTab(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              color: Colors.white,
            ),
            child: Text(label),
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 24 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Individual Reel Player ───────────────────────────────────────────────────

class _ReelPlayer extends StatefulWidget {
  final Reel reel;
  final String currentUserId;
  final bool isActive;

  const _ReelPlayer({
    super.key,
    required this.reel,
    required this.currentUserId,
    required this.isActive,
  });

  @override
  State<_ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<_ReelPlayer>
    with SingleTickerProviderStateMixin {
  // ─── Video Player ───────────────────────────────────────────────────────────
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _showPauseIcon = false;

  // ─── Like ───────────────────────────────────────────────────────────────────
  late bool _isLiked;
  late int _likesCount;

  // ─── Follow ─────────────────────────────────────────────────────────────────
  bool _isSaved = false;
  bool _isFollowing = false;

  // ─── Double-tap heart animation ─────────────────────────────────────────────
  late AnimationController _heartCtrl;
  late Animation<double> _heartAnim;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reel.isLikedBy(widget.currentUserId);
    _likesCount = widget.reel.likes;

    _heartCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _heartAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut),
    );
    _heartCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _showHeart = false);
          _heartCtrl.reset();
        });
      }
    });

    if (widget.isActive) _initVideo();
  }

  @override
  void didUpdateWidget(_ReelPlayer old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      // This reel just became the active one — init and play
      _initVideo();
    } else if (!widget.isActive && old.isActive) {
      // Swiped away — pause and release
      _videoController?.pause();
      _disposeController();
    }
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _videoController?.dispose();
    _videoController = null;
    if (mounted) setState(() => _isInitialized = false);
  }

  // ─── Video Initialisation ───────────────────────────────────────────────────

  Future<void> _initVideo() async {
    final url = widget.reel.videoUrl;
    if (url.isEmpty) return;

    VideoPlayerController controller;

    try {
      if (url.startsWith('http')) {
        // Network URL (Firebase Storage or CDN)
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else if (url.startsWith('data:video')) {
        // Base64 data URI
        if (kIsWeb) {
          // On Web: HTML5 <video> handles data URIs natively
          controller = VideoPlayerController.networkUrl(Uri.parse(url));
        } else {
          // On Mobile: decode bytes → write to temp file → play from file
          final bytes = base64Decode(url.split(',').last);
          final tempDir = await getTemporaryDirectory();
          final tempFile =
              File('${tempDir.path}/reel_${widget.reel.id}.mp4');
          await tempFile.writeAsBytes(bytes);
          controller = VideoPlayerController.file(tempFile);
        }
      } else {
        return; // Unknown URL format — skip
      }

      controller.addListener(() {
        if (!mounted) return;
        final isBuffering = controller.value.isBuffering;
        if (isBuffering != _isBuffering) {
          setState(() => _isBuffering = isBuffering);
        }
      });

      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(1.0);

      if (mounted) {
        setState(() {
          _videoController = controller;
          _isInitialized = true;
        });
        controller.play(); // Auto-play
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Video init error for ${widget.reel.id}: $e');
    }
  }

  // ─── Toggle play/pause on tap ───────────────────────────────────────────────
  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
    // Show brief pause/play icon
    setState(() => _showPauseIcon = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showPauseIcon = false);
    });
  }

  // ─── Like ───────────────────────────────────────────────────────────────────
  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    ReelService.instance.toggleLike(widget.reel.id);
  }

  void _doubleTapLike() {
    if (!_isLiked) _toggleLike();
    setState(() => _showHeart = true);
    _heartCtrl.forward();
  }

  // ─── Follow ─────────────────────────────────────────────────────────────────
  void _toggleFollow() {
    setState(() => _isFollowing = !_isFollowing);
    if (_isFollowing) {
      FriendsService.instance
          .sendFriendRequest(widget.reel.userId)
          .catchError((_) {
        if (mounted) setState(() => _isFollowing = false);
      });
    }
  }

  void _showComments() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CommentsSheet(reel: widget.reel),
      );

  void _showOptions() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _MoreOptionsSheet(
          reel: widget.reel,
          currentUserId: widget.currentUserId,
        ),
      );

  String _fmt(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return '$c';
  }

  ImageProvider? _getAvatarImage(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final avatarImage = _getAvatarImage(widget.reel.avatarUrl);
    final isOwn = widget.reel.userId == widget.currentUserId;
    final isPlaying =
        _videoController?.value.isPlaying ?? false;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _doubleTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video / Placeholder ────────────────────────────────────────────
          _isInitialized && _videoController != null
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: AppTheme.primaryPurple),
                        const SizedBox(height: 12),
                        Text(
                          'Loading video...',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

          // ── Buffering spinner overlay ────────────────────────────────────
          if (_isBuffering && _isInitialized)
            const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),

          // ── Play/Pause flash icon ────────────────────────────────────────
          if (_showPauseIcon)
            Center(
              child: AnimatedOpacity(
                opacity: _showPauseIcon ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),

          // ── Double-tap heart ─────────────────────────────────────────────
          if (_showHeart)
            Center(
              child: IgnorePointer(
                child: ScaleTransition(
                  scale: _heartAnim,
                  child: const Icon(Icons.favorite,
                      color: Colors.white, size: 100),
                ),
              ),
            ),

          // ── Bottom gradient scrim ────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // ── Right action bar ─────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                // Profile avatar with + follow button
                _ActionBtn(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.black,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 22)
                              : null,
                        ),
                      ),
                      if (!isOwn)
                        Positioned(
                          bottom: -6,
                          child: GestureDetector(
                            onTap: _toggleFollow,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: _isFollowing
                                    ? Colors.grey
                                    : AppTheme.primaryPurple,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.black, width: 1.5),
                              ),
                              child: Icon(
                                _isFollowing
                                    ? Icons.check
                                    : Icons.add,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {},
                ),
                const SizedBox(height: 24),

                // Like — optimistic state
                _ActionBtn(
                  icon: _isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  iconColor: _isLiked ? Colors.red : Colors.white,
                  label: _fmt(_likesCount),
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 20),

                // Comment
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: _fmt(widget.reel.comments),
                  onTap: _showComments,
                ),
                const SizedBox(height: 20),

                // Views
                _ActionBtn(
                  icon: Icons.remove_red_eye_outlined,
                  label: _fmt(widget.reel.views),
                  onTap: () {},
                ),
                const SizedBox(height: 20),

                // Save
                _ActionBtn(
                  icon: _isSaved
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  iconColor:
                      _isSaved ? Colors.yellow : Colors.white,
                  label: 'Save',
                  onTap: () => setState(() => _isSaved = !_isSaved),
                ),
                const SizedBox(height: 20),

                // More
                _ActionBtn(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onTap: _showOptions,
                ),
              ],
            ),
          ),

          // ── Bottom info overlay ──────────────────────────────────────────
          Positioned(
            left: 16,
            right: 80,
            bottom: 20,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Username + follow
                  Row(children: [
                    Text(
                      '@${widget.reel.username}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              color: Colors.black45, blurRadius: 4)
                        ],
                      ),
                    ),
                    if (!isOwn) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isFollowing
                                ? Colors.white24
                                : Colors.transparent,
                            border:
                                Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isFollowing ? 'Requested' : 'Follow',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),

                  // Caption
                  Text(
                    widget.reel.caption,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                            color: Colors.black45, blurRadius: 4)
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Audio
                  Row(children: [
                    const Icon(Icons.music_note,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.reel.audioName,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),

                  // Video progress bar
                  if (_isInitialized && _videoController != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppTheme.primaryPurple,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final Widget? child;
  final IconData? icon;
  final Color iconColor;
  final String? label;
  final VoidCallback onTap;

  const _ActionBtn({
    this.child,
    this.icon,
    this.iconColor = Colors.white,
    this.label,
    required this.onTap,
  }) : assert(child != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          child ?? Icon(icon!, color: iconColor, size: 32),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyReelsState extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyReelsState({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_outlined, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          const Text('No Reels Yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Be the first to share a reel!',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.add),
            label: const Text('Upload Reel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Upload Sheet ─────────────────────────────────────────────────────────────

class _UploadReelSheet extends StatefulWidget {
  const _UploadReelSheet();

  @override
  State<_UploadReelSheet> createState() => _UploadReelSheetState();
}

class _UploadReelSheetState extends State<_UploadReelSheet> {
  final _captionCtrl = TextEditingController();
  bool _isUploading = false;
  String? _selectedVideoBase64;
  String? _selectedFileName;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 1),
    );
    if (video == null) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await video.readAsBytes();
      setState(() {
        _selectedVideoBase64 =
            'data:video/mp4;base64,${base64Encode(bytes)}';
        _selectedFileName = video.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _upload() async {
    if (_selectedVideoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a video first')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      await ReelService.instance.createReel(
        videoUrl: _selectedVideoBase64!,
        caption: _captionCtrl.text.trim().isEmpty
            ? '📹 New Reel'
            : _captionCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Reel uploaded! 🎉'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Upload Reel 🎬',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isUploading ? null : _pickVideo,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primaryPurple.withOpacity(0.4)),
                  ),
                  child: _isUploading && _selectedFileName == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryPurple))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedVideoBase64 != null
                                  ? Icons.check_circle
                                  : Icons.video_library_rounded,
                              color: _selectedVideoBase64 != null
                                  ? Colors.green
                                  : AppTheme.primaryPurple,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFileName ?? 'Tap to select video',
                              style: TextStyle(
                                color: _selectedVideoBase64 != null
                                    ? Colors.green
                                    : Colors.white60,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _captionCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write a caption... #hashtags',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    disabledBackgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Upload Reel',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Comments Sheet ───────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final Reel reel;
  const _CommentsSheet({required this.reel});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  final List<Map<String, String>> _localComments = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${widget.reel.comments + _localComments.length} Comments',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.1)),
        Expanded(
          child: _localComments.isEmpty
              ? Center(
                  child: Text('No comments yet',
                      style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _localComments.length,
                  itemBuilder: (context, i) {
                    final c = _localComments[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryPurple,
                        child: Text(c['user']![0].toUpperCase(),
                            style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(c['user']!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      subtitle: Text(c['text']!,
                          style: const TextStyle(color: Colors.white70)),
                    );
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_ctrl.text.isNotEmpty) {
                  setState(() {
                    _localComments
                        .insert(0, {'user': 'You', 'text': _ctrl.text});
                    _ctrl.clear();
                  });
                }
              },
              child: const Icon(Icons.send_rounded,
                  color: AppTheme.primaryPurple),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── More Options Sheet ───────────────────────────────────────────────────────

class _MoreOptionsSheet extends StatelessWidget {
  final Reel reel;
  final String currentUserId;
  const _MoreOptionsSheet(
      {required this.reel, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final isOwner = reel.userId == currentUserId;
    final opts = [
      {'icon': Icons.bookmark_border, 'label': 'Save Video', 'color': Colors.white},
      {'icon': Icons.link, 'label': 'Copy Link', 'color': Colors.white},
      {'icon': Icons.reply_rounded, 'label': 'Share', 'color': Colors.white},
      {'icon': Icons.volume_off_outlined, 'label': 'Mute', 'color': Colors.white},
      if (!isOwner) ...[ 
        {'icon': Icons.not_interested, 'label': 'Not Interested', 'color': Colors.orange},
        {'icon': Icons.flag_outlined, 'label': 'Report', 'color': Colors.red},
        {'icon': Icons.block, 'label': 'Block User', 'color': Colors.red},
      ],
      if (isOwner)
        {'icon': Icons.delete_outline, 'label': 'Delete', 'color': Colors.red},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          padding: const EdgeInsets.all(16),
          children: opts.map((opt) {
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                if (opt['label'] == 'Delete') {
                  await ReelService.instance
                      .deleteReel(reel.id, currentUserId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reel deleted')));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${opt['label']} tapped')));
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle),
                    child: Icon(opt['icon'] as IconData,
                        color: opt['color'] as Color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(opt['label'] as String,
                      style: TextStyle(
                          fontSize: 11, color: opt['color'] as Color),
                      textAlign: TextAlign.center,
                      maxLines: 2),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
