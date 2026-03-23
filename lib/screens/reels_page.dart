import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'dart:typed_data';
import '../models/reel_model.dart';
import '../services/reel_service.dart';
import '../services/friends_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../utils/video_compressor.dart';
import '../widgets/create_post_modal.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => ReelsPageState();
}

class ReelsPageState extends State<ReelsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _kakonekIndex = 0;
  int _paraSaImoIndex = 0;
  final Set<String> _viewedReels = {};
  bool _isTabActive = false;
  bool _isMuted = false;
  final Set<String> _hiddenReelIds = {};

  final Map<String, GlobalKey<ReelPlayerState>> _kakonekKeys = {};
  final Map<String, GlobalKey<ReelPlayerState>> _paraSaImoKeys = {};

  // Cached reel lists — safe reference for onPageChanged prev-index lookup
  List<Reel> _kakonekReels = [];
  List<Reel> _paraSaImoReels = [];
  AppLocalizations get _l => AppLocalizations.instance;

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    for (final key in _kakonekKeys.values) {
      key.currentState?._videoController?.setVolume(_isMuted ? 0.0 : 1.0);
    }
    for (final key in _paraSaImoKeys.values) {
      key.currentState?._videoController?.setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  void pauseCurrentVideo() {
    for (final key in _kakonekKeys.values) key.currentState?.pauseVideo();
    for (final key in _paraSaImoKeys.values) key.currentState?.pauseVideo();
  }

  void setTabActive(bool active) {
    if (_isTabActive == active) return;
    if (!active) pauseCurrentVideo();
    if (mounted) setState(() => _isTabActive = active);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted || !_tabController.indexIsChanging) return;
      pauseCurrentVideo();
      if (_tabController.index == 0) {
        _paraSaImoKeys.clear();
        _paraSaImoReels = [];
        if (mounted) setState(() => _paraSaImoIndex = 0);
      } else {
        _kakonekKeys.clear();
        _kakonekReels = [];
        if (mounted) setState(() => _kakonekIndex = 0);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _navigateToUploadReel() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreatePostModal(initialType: 'reel'),
    );
  }

  Future<void> _executeUpload(Uint8List bytes, String fileName) async {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(_l.t('reels_uploading'), style: TextStyle(color: Colors.white)),
          ]),
        ),
      );
    }
    try {
      await ReelService.instance.createReel(
        videoUrl: 'data:video/mp4;base64,${base64Encode(bytes)}',
        caption: '',
        isPublic: true,
      );
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l.t('reels_uploaded')), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_l.t('reels_upload_failed')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _trackReelView(Reel reel) async {
    if (_viewedReels.contains(reel.id)) return;
    _viewedReels.add(reel.id);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final viewDoc = await FirebaseFirestore.instance
          .collection('reels').doc(reel.id)
          .collection('views').doc(currentUser.uid).get();
      if (viewDoc.exists) return;
      await FirebaseFirestore.instance
          .collection('reels').doc(reel.id)
          .collection('views').doc(currentUser.uid)
          .set({'userId': currentUser.uid, 'timestamp': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance
          .collection('reels').doc(reel.id)
          .update({'views': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error tracking view: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
          onPressed: _toggleMute,
        ),
        title: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          tabs: [Tab(text: _l.t('reels_kakonek')), Tab(text: _l.t('reels_para_sa_imo'))],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            onPressed: _navigateToUploadReel),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeed(
            currentUserId: currentUserId,
            stream: ReelService.instance.getKakonekReelsStream(currentUserId),
            currentIndex: _kakonekIndex,
            cachedReels: _kakonekReels,
            keys: _kakonekKeys,
            emptyMessage: _l.t('reels_empty_kakonek'),
            isMuted: _isMuted,
            onPageChanged: (reels, index) {
              // Pause previous safely
              if (_kakonekIndex < _kakonekReels.length) {
                _kakonekKeys[_kakonekReels[_kakonekIndex].id]?.currentState?.pauseVideo();
              }
              if (mounted) setState(() => _kakonekIndex = index);
              _trackReelView(reels[index]);
            },
            onReelsUpdated: (reels) => _kakonekReels = reels,
          ),
          _buildFeed(
            currentUserId: currentUserId,
            stream: ReelService.instance.getParaSaImoReelsStream(currentUserId),
            currentIndex: _paraSaImoIndex,
            cachedReels: _paraSaImoReels,
            keys: _paraSaImoKeys,
            emptyMessage: _l.t('reels_empty_public'),
            isMuted: _isMuted,
            onPageChanged: (reels, index) {
              // Pause previous safely
              if (_paraSaImoIndex < _paraSaImoReels.length) {
                _paraSaImoKeys[_paraSaImoReels[_paraSaImoIndex].id]?.currentState?.pauseVideo();
              }
              if (mounted) setState(() => _paraSaImoIndex = index);
              _trackReelView(reels[index]);
            },
            onReelsUpdated: (reels) => _paraSaImoReels = reels,
          ),
        ],
      ),
    );
  }

  Widget _buildFeed({
    required String currentUserId,
    required Stream<List<Reel>> stream,
    required int currentIndex,
    required List<Reel> cachedReels,
    required Map<String, GlobalKey<ReelPlayerState>> keys,
    required String emptyMessage,
    required bool isMuted,
    required void Function(List<Reel> reels, int index) onPageChanged,
    required void Function(List<Reel> reels) onReelsUpdated,
  }) {
    return StreamBuilder<List<Reel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && cachedReels.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
        }

        final reels = snapshot.data ?? cachedReels;

        final visibleReels = reels.where((r) => !_hiddenReelIds.contains(r.id)).toList();

        // Update cache after frame so it doesn't interfere with current build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onReelsUpdated(visibleReels);
        });

        if (visibleReels.isEmpty) {
          return _EmptyReelsState(onUpload: _navigateToUploadReel, message: emptyMessage);
        }

        // Always clamp index to valid range
        final safeIndex = currentIndex.clamp(0, visibleReels.length - 1);

        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: visibleReels.length,
          onPageChanged: (index) => onPageChanged(visibleReels, index),
          itemBuilder: (context, index) {
            final reelKey = keys.putIfAbsent(
              visibleReels[index].id, () => GlobalKey<ReelPlayerState>());
            return ReelPlayer(
              key: reelKey,
              reel: visibleReels[index],
              currentUserId: currentUserId,
              isActive: index == safeIndex,
              isTabActive: _isTabActive,
              isMuted: isMuted,
              onHidden: () => setState(() => _hiddenReelIds.add(visibleReels[index].id)),
            );
          },
        );
      },
    );
  }
}

// ─── Individual Reel Player ───────────────────────────────────────────────────

class ReelPlayer extends StatefulWidget {
  final Reel reel;
  final String currentUserId;
  final bool isActive;
  final bool isTabActive;
  final bool isMuted;
  final VoidCallback? onHidden;

  const ReelPlayer({
    super.key,
    required this.reel,
    required this.currentUserId,
    required this.isActive,
    required this.isTabActive,
    required this.isMuted,
    this.onHidden,
  });

  @override
  State<ReelPlayer> createState() => ReelPlayerState();
}

class ReelPlayerState extends State<ReelPlayer>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _showPauseIcon = false;

  void pauseVideo() {
    _videoController?.pause();
  }

  late bool _isLiked;
  late int _likesCount;
  bool _isSaved = false;
  late Stream<bool> _friendStatusStream;
  AppLocalizations get _l => AppLocalizations.instance;

  late AnimationController _heartCtrl;
  late Animation<double> _heartAnim;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reel.isLikedBy(widget.currentUserId);
    _likesCount = widget.reel.likes;
    _friendStatusStream = FriendsService.instance.isFriendStream(widget.reel.userId);

    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _heartAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut));
    _heartCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _showHeart = false);
          _heartCtrl.reset();
        });
      }
    });

    if (widget.isActive && widget.isTabActive) _initVideo();
  }

  @override
  void didUpdateWidget(ReelPlayer old) {
    super.didUpdateWidget(old);

    // Tab became active
    if (widget.isTabActive && !old.isTabActive && widget.isActive) {
      if (_isInitialized) {
        _videoController?.play();
      } else {
        _initVideo();
      }
    }

    // Tab became inactive — pause immediately
    if (!widget.isTabActive && old.isTabActive) {
      _videoController?.pause();
    }

    // This reel became active in scroll
    if (widget.isActive && !old.isActive && widget.isTabActive) {
      _initVideo();
    }

    // This reel was scrolled away — pause then dispose
    if (!widget.isActive && old.isActive) {
      _videoController?.pause();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !widget.isActive) _disposeController();
      });
    }

    if (widget.isMuted != old.isMuted) {
      _videoController?.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    super.dispose();
  }

  void _disposeController() {
    if (!mounted) return;
    _videoController?.dispose();
    _videoController = null;
    setState(() => _isInitialized = false);
  }

  Future<void> _initVideo() async {
    // Already initialized — just play
    if (_isInitialized && _videoController != null) {
      _videoController!.play();
      return;
    }

    final url = widget.reel.videoUrl;
    if (url.isEmpty) return;

    VideoPlayerController controller;

    try {
      if (url.startsWith('http')) {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else if (url.startsWith('data:video')) {
        if (kIsWeb) {
          controller = VideoPlayerController.networkUrl(Uri.parse(url));
        } else {
          final bytes = base64Decode(url.split(',').last);
          final tempDir = await getTemporaryDirectory();
          final tempFile = io.File('${tempDir.path}/reel_${widget.reel.id}.mp4');
          await tempFile.writeAsBytes(bytes);
          controller = VideoPlayerController.file(tempFile);
        }
      } else {
        return;
      }

      controller.addListener(() {
        if (!mounted) return;
        final buffering = controller.value.isBuffering;
        if (buffering != _isBuffering) setState(() => _isBuffering = buffering);
      });

      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(widget.isMuted ? 0.0 : 1.0);

      // Only apply if still active and tab still visible
      if (mounted && widget.isActive && widget.isTabActive) {
        setState(() {
          _videoController = controller;
          _isInitialized = true;
        });
        controller.play();
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Video init error for ${widget.reel.id}: $e');
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
    setState(() => _showPauseIcon = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showPauseIcon = false);
    });
  }

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

  Future<void> _toggleFriend(String userId) async {
    try {
      final isFriend = await FriendsService.instance.isFriendStream(userId).first;
      if (isFriend) {
        await FriendsService.instance.removeFriend(userId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Kakonek'), duration: Duration(seconds: 1)));
      } else {
        await FriendsService.instance.sendFriendRequest(userId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l.t('reels_request_sent')), duration: const Duration(seconds: 1)));
      }
    } catch (e) {
      debugPrint('Error toggling friend: $e');
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(_l.t('comments_title'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reels')
                        .doc(widget.reel.id).collection('comments').snapshots(),
                    builder: (context, snapshot) => Text(
                      '${snapshot.data?.docs.length ?? 0}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('reels')
                    .doc(widget.reel.id).collection('comments')
                    .orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryPurple));
                  final comments = snapshot.data!.docs;
                  if (comments.isEmpty) return Center(
                    child: Text(_l.t('comments_no_comments'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary)));
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) =>
                        _CommentItem(comment: comments[index].data() as Map<String, dynamic>));
                },
              ),
            ),
            _CommentInput(reelId: widget.reel.id),
          ]),
        ),
      ),
    );
  }

  void _showReelOptions() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnReel = widget.reel.userId == currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          _MenuOption(icon: Icons.bookmark_outline, title: _l.t('reels_save'),
            onTap: () { Navigator.pop(context); _saveReel(widget.reel); setState(() => _isSaved = true); }),
          if (!isOwnReel) ...[
            const Divider(color: Colors.white10),
            _MenuOption(icon: Icons.not_interested, title: _l.t('reels_not_interested'),
              subtitle: _l.t('reels_hide_reel'),
              onTap: () { Navigator.pop(context); _hideReel(widget.reel); }),
          ],
          if (isOwnReel) ...[
            const Divider(color: Colors.white10),
            _MenuOption(icon: Icons.delete_outline, title: _l.t('delete'), isDestructive: true,
              onTap: () { Navigator.pop(context); _deleteReel(widget.reel); }),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _saveReel(Reel reel) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid)
          .collection('saved').doc(reel.id)
          .set({'type': 'reel', 'reelId': reel.id, 'savedAt': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel saved!'), duration: Duration(seconds: 2)));
    } catch (e) { debugPrint('Error saving reel: $e'); }
  }

  Future<void> _hideReel(Reel reel) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid)
          .collection('hidden_reels').doc(reel.id)
          .set({'reelId': reel.id, 'hiddenAt': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel hidden.'), duration: Duration(seconds: 2)));
      widget.onHidden?.call();
    } catch (e) { debugPrint('Error hiding reel: $e'); }
  }

  Future<void> _deleteReel(Reel reel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(_l.t('reels_delete_confirm'), style: const TextStyle(color: Colors.white)),
        content: Text(_l.t('reels_delete_message'),
          style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_l.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_l.t('delete'))),
        ],
      ),
    );
    if (confirm != true) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await ReelService.instance.deleteReel(reel.id, currentUser.uid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel deleted'), duration: Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  String _fmt(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return '$c';
  }

  ImageProvider? _getAvatarImage(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try { return MemoryImage(base64Decode(url.split(',').last)); }
      catch (_) { return null; }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = _getAvatarImage(widget.reel.avatarUrl);
    final isOwn = widget.reel.userId == widget.currentUserId;
    final isPlaying = _videoController?.value.isPlaying ?? false;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _doubleTapLike,
      child: Stack(fit: StackFit.expand, children: [
        // Video or loading
        _isInitialized && _videoController != null
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!))))
            : Container(
                color: Colors.black,
                child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primaryPurple),
                    const SizedBox(height: 12),
                    Text(_l.t('reels_loading'), style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 13)),
                  ]))),

        if (_isBuffering && _isInitialized)
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),

        if (_showPauseIcon)
          Center(child: AnimatedOpacity(
            opacity: _showPauseIcon ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
              child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 48)))),

        if (_showHeart)
          Center(child: IgnorePointer(
            child: ScaleTransition(scale: _heartAnim,
              child: const Icon(Icons.favorite, color: Colors.white, size: 100)))),

        // Bottom gradient
        Positioned(left: 0, right: 0, bottom: 0, height: 320,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter))))),

        // Right action bar
        Positioned(right: 12, bottom: 100,
          child: Column(children: [
            _ActionBtn(
              onTap: () {},
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
                  child: CircleAvatar(
                    radius: 22, backgroundColor: Colors.black,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(Icons.person, color: Colors.white, size: 22) : null)),
                if (!isOwn)
                  Positioned(bottom: -6,
                    child: StreamBuilder<bool>(
                      stream: _friendStatusStream,
                      builder: (context, snapshot) {
                        final isFriend = snapshot.data ?? false;
                        return GestureDetector(
                          onTap: () => _toggleFriend(widget.reel.userId),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isFriend ? Colors.grey : AppTheme.primaryPurple,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 1.5)),
                            child: Icon(isFriend ? Icons.check : Icons.add, size: 12, color: Colors.white)));
                      })),
              ])),
            const SizedBox(height: 24),
            _ActionBtn(
              icon: _isLiked ? Icons.favorite : Icons.favorite_border,
              iconColor: _isLiked ? Colors.red : Colors.white,
              label: _fmt(_likesCount), onTap: _toggleLike),
            const SizedBox(height: 20),
            _ActionBtn(icon: Icons.chat_bubble_outline,
              label: _fmt(widget.reel.comments), onTap: _showComments),
            const SizedBox(height: 20),
            _ActionBtn(icon: Icons.remove_red_eye_outlined,
              label: _fmt(widget.reel.views), onTap: () {}),
            const SizedBox(height: 20),
            _ActionBtn(
              icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
              iconColor: _isSaved ? Colors.yellow : Colors.white,
              label: _l.t('reels_save'), onTap: () => setState(() => _isSaved = !_isSaved)),
            const SizedBox(height: 20),
            _ActionBtn(icon: Icons.more_horiz, label: _l.t('reels_more'), onTap: _showReelOptions),
          ])),

        // Bottom info
        Positioned(left: 16, right: 80, bottom: 20,
          child: SafeArea(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text('@${widget.reel.username}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                StreamBuilder<bool>(
                  stream: _friendStatusStream,
                  builder: (context, snapshot) {
                    final isFriend = snapshot.data ?? false;
                    if (widget.reel.userId == widget.currentUserId) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () => _toggleFriend(widget.reel.userId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFriend ? Colors.transparent : AppTheme.primaryPurple,
                          borderRadius: BorderRadius.circular(6),
                          border: isFriend ? Border.all(color: Colors.white, width: 1.5) : null),
                        child: Text(isFriend ? 'Kakonek' : 'Follow',
                          style: const TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.bold))));
                  }),
              ]),
              const SizedBox(height: 8),
              Text(widget.reel.caption,
                style: const TextStyle(fontSize: 14, color: Colors.white,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.music_note, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.reel.audioName,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              if (_isInitialized && _videoController != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: VideoProgressIndicator(_videoController!, allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: AppTheme.primaryPurple,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white12))),
            ]))),
      ]),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final Widget? child;
  final IconData? icon;
  final Color iconColor;
  final String? label;
  final VoidCallback onTap;

  const _ActionBtn({this.child, this.icon, this.iconColor = Colors.white,
    this.label, required this.onTap}) : assert(child != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        child ?? Icon(icon!, color: iconColor, size: 32),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(label!, style: const TextStyle(color: Colors.white, fontSize: 12,
            fontWeight: FontWeight.w600)),
        ],
      ]));
  }
}

class _EmptyReelsState extends StatelessWidget {
  final VoidCallback onUpload;
  final String message;
  const _EmptyReelsState({required this.onUpload, this.message = 'No reels yet'});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.video_collection_outlined, color: Colors.white30, size: 80),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onUpload,
        icon: const Icon(Icons.add),
        label: const Text('Create First Reel'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))),
    ]));
  }
}

class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentItem({required this.comment});

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) return '';
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 16, backgroundColor: Colors.grey[800],
          child: const Icon(Icons.person, size: 16, color: Colors.grey)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(comment['username'] ?? 'User',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(comment['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 4),
          Text(_formatTimestamp(comment['timestamp']),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ])),
      ]));
  }
}

class _CommentInput extends StatefulWidget {
  final String reelId;
  const _CommentInput({required this.reelId});

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _postComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _isPosting = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      await FirebaseFirestore.instance.collection('reels')
          .doc(widget.reelId).collection('comments').add({
        'userId': currentUser.uid,
        'username': userData['username'] ?? 'User',
        'photoURL': userData['photoURL'] ?? '',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('reels')
          .doc(widget.reelId).update({'comments': FieldValue.increment(1)});
      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) { debugPrint('Error posting comment: $e'); }
    finally { if (mounted) setState(() => _isPosting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: BoxDecoration(color: AppTheme.backgroundDark,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
      child: SafeArea(child: Row(children: [
        Expanded(child: TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Add a comment...',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none),
            filled: true, fillColor: AppTheme.surfaceDark,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          maxLines: null, textCapitalization: TextCapitalization.sentences)),
        const SizedBox(width: 8),
        _isPosting
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple))
            : IconButton(icon: const Icon(Icons.send, color: AppTheme.primaryPurple),
                onPressed: _postComment),
      ])));
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuOption({required this.icon, required this.title, this.subtitle,
    required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white),
      title: Text(title, style: TextStyle(
        color: isDestructive ? Colors.red : Colors.white, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          : null,
      onTap: onTap);
  }
}
