import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../models/reel_model.dart';
import '../services/reel_service.dart';
import '../services/friends_service.dart';
import '../theme/app_theme.dart';
import '../utils/video_compressor.dart';
import 'video_trimmer_screen.dart';

// ─── Reels Page ───────────────────────────────────────────────────────────────

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _kakonekPageController;
  late PageController _paraSaImoPageController;
  int _kakonekIndex = 0;
  int _paraSaImoIndex = 0;
  final Set<String> _viewedReels = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _kakonekPageController = PageController();
    _paraSaImoPageController = PageController();
    
    // Listen for tab changes
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _kakonekPageController.dispose();
    _paraSaImoPageController.dispose();
    super.dispose();
  }

  Future<void> _navigateToUploadReel() async {
    print('🎥 Upload button clicked');
    
    try {
      // Check if user is logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in first'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      print('Opening file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) {
        print('No file selected');
        return;
      }
      
      final file = result.files.first;
      print('Video selected: ${file.name}');
      print('Original size: ${VideoCompressor.formatFileSize(file.size)}');
      
      // Show compression dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Compressing video...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      
      // Get bytes (on Web, file.bytes is available; on Mobile, we read from path)
      Uint8List? rawBytes;
      if (kIsWeb) {
        rawBytes = file.bytes;
      } else if (file.path != null) {
        rawBytes = await XFile(file.path!).readAsBytes();
      }
      
      if (rawBytes == null) throw Exception('Could not read file data');

      // 🎬 Compress video
      final compressedBytes = await VideoCompressor.compressVideoToSize(
        videoBytes: rawBytes,
        fileName: file.name,
        targetSizeKB: 1024, // 1MB target
      );
      
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Close compression dialog
      }
      
      if (compressedBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not compress video or it\'s too large for web.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      print('Compressed size: ${VideoCompressor.formatFileSize(compressedBytes.length)}');
      
      // Now upload the compressed bytes
      await _executeUpload(compressedBytes, file.name);
      
    } catch (e, stackTrace) {
      print('❌ ERROR picking video: $e');
      print('Stack: $stackTrace');
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _executeUpload(Uint8List bytes, String fileName) async {
    // Show uploading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Uploading reel...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      
      print('📤 Uploading ${VideoCompressor.formatFileSize(bytes.length)}...');
      
      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance
        .ref('reels/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.mp4');
      
      await ref.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
      final url = await ref.getDownloadURL();
      
      print('✅ Upload complete: $url');
      
      // Fetch user data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      
      // Create Reel document
      await FirebaseFirestore.instance.collection('reels').add({
        'userId': user.uid,
        'username': userData['username'] ?? 'user',
        'displayName': userData['displayName'] ?? 'User',
        'avatarUrl': userData['photoURL'] ?? '',
        'videoUrl': url,
        'caption': '',
        'hashtags': [],
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'views': 0,
        'comments': 0,
        'likedBy': [],
        'audioName': 'Original Audio - ${userData['username'] ?? 'user'}',
        'isPublic': true,
      });
      
      // Update user's reel count
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'reelCount': FieldValue.increment(1),
      });
      
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Close uploading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel uploaded successfully! 🎉'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ Upload failed: $e');
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _trackReelView(Reel reel) async {
    // Only track once per session
    if (_viewedReels.contains(reel.id)) return;
    _viewedReels.add(reel.id);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Check if already viewed in DB (more robust than session-only)
      final viewDoc = await FirebaseFirestore.instance
        .collection('reels')
        .doc(reel.id)
        .collection('views')
        .doc(currentUser.uid)
        .get();
      
      if (viewDoc.exists) return;  // Already viewed
      
      // Mark as viewed
      await FirebaseFirestore.instance
        .collection('reels')
        .doc(reel.id)
        .collection('views')
        .doc(currentUser.uid)
        .set({
          'userId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      
      // Increment view count
      await FirebaseFirestore.instance
        .collection('reels')
        .doc(reel.id)
        .update({
          'views': FieldValue.increment(1),
        });
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
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Kakonek'),
            Tab(text: 'Para sa Imo'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            onPressed: () {
              print('Camera icon pressed');
              _navigateToUploadReel();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKakonekFeed(currentUserId),
          _buildParaSaImoFeed(currentUserId),
        ],
      ),
    );
  }

  // ─── Feed Builders ────────────────────────────────────────────────────────
  Widget _buildKakonekFeed(String currentUserId) {
    return StreamBuilder<List<Reel>>(
      stream: _getKakonekReelsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
        }

        final reels = snapshot.data ?? [];
        if (reels.isEmpty) {
          return _EmptyReelsState(
            onUpload: _navigateToUploadReel,
            message: 'No reels from your Kakonek yet',
          );
        }

        return PageView.builder(
          controller: _kakonekPageController,
          scrollDirection: Axis.vertical,
          itemCount: reels.length,
          onPageChanged: (index) {
            setState(() => _kakonekIndex = index);
            _trackReelView(reels[index]);
          },
          itemBuilder: (context, index) {
            return _ReelPlayer(
              key: ValueKey(reels[index].id),
              reel: reels[index],
              currentUserId: currentUserId,
              isActive: index == _kakonekIndex,
            );
          },
        );
      },
    );
  }

  Widget _buildParaSaImoFeed(String currentUserId) {
    return StreamBuilder<List<Reel>>(
      stream: _getParaSaImoReelsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
        }

        final reels = snapshot.data ?? [];
        if (reels.isEmpty) {
          return _EmptyReelsState(
            onUpload: _navigateToUploadReel,
            message: 'No reels available',
          );
        }

        return PageView.builder(
          controller: _paraSaImoPageController,
          scrollDirection: Axis.vertical,
          itemCount: reels.length,
          onPageChanged: (index) {
            setState(() => _paraSaImoIndex = index);
            _trackReelView(reels[index]);
          },
          itemBuilder: (context, index) {
            return _ReelPlayer(
              key: ValueKey(reels[index].id),
              reel: reels[index],
              currentUserId: currentUserId,
              isActive: index == _paraSaImoIndex,
            );
          },
        );
      },
    );
  }

  // ─── Stream for Kakonek (friends) ──────────────────────────────────────────
  Stream<List<Reel>> _getKakonekReelsStream(String currentUserId) async* {
    final userStream = FirebaseFirestore.instance
      .collection('users')
      .doc(currentUserId)
      .snapshots();
    
    await for (final userDoc in userStream) {
      final userData = userDoc.data() ?? {};
      final friendIds = List<String>.from(userData['friends'] ?? []);
      
      if (friendIds.isEmpty) {
        yield <Reel>[];
        continue;
      }
      
      final snapshot = await FirebaseFirestore.instance
        .collection('reels')
        .where('userId', whereIn: friendIds.take(10).toList())
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
      
      final reels = snapshot.docs
        .map((doc) => Reel.fromFirestore(doc))
        .toList();
      
      final hiddenDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('hidden_reels')
        .get();
      
      final hiddenIds = hiddenDocs.docs.map((d) => d.id).toSet();
      yield reels.where((r) => !hiddenIds.contains(r.id)).toList();
    }
  }

  // ─── Stream for Para sa Imo (discover) ──────────────────────────────────────
  Stream<List<Reel>> _getParaSaImoReelsStream(String currentUserId) async* {
    final reelsStream = FirebaseFirestore.instance
      .collection('reels')
      .where('isPublic', isEqualTo: true)
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots();
    
    await for (final snapshot in reelsStream) {
      final reels = snapshot.docs
        .map((doc) => Reel.fromFirestore(doc))
        .toList();
      
      final hiddenDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('hidden_reels')
        .get();
      
      final hiddenIds = hiddenDocs.docs.map((d) => d.id).toSet();
      yield reels.where((r) => !hiddenIds.contains(r.id)).toList();
    }
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
  bool _isSaved = false;
  late Stream<bool> _friendStatusStream;

  // ─── Double-tap heart animation ─────────────────────────────────────────────
  late AnimationController _heartCtrl;
  late Animation<double> _heartAnim;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reel.isLikedBy(widget.currentUserId);
    _likesCount = widget.reel.likes;
    _friendStatusStream = FriendsService.instance.isFriendStream(widget.reel.userId);

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
          final tempFile = io.File('${tempDir.path}/reel_${widget.reel.id}.mp4');
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
  Future<void> _toggleFriend(String userId) async {
    try {
      final isFriend = await FriendsService.instance
        .isFriendStream(userId)
        .first;
      
      if (isFriend) {
        await FriendsService.instance.removeFriend(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from Kakonek'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await FriendsService.instance.sendFriendRequest(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request sent!'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling friend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                        .collection('reels')
                        .doc(widget.reel.id)
                        .collection('comments')
                        .snapshots(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.docs.length ?? 0;
                        return Text(
                          '$count',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white10),
              
              // Comments list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                    .collection('reels')
                    .doc(widget.reel.id)
                    .collection('comments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryPurple,
                        ),
                      );
                    }
                    
                    final comments = snapshot.data!.docs;
                    
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet\nBe the first to comment!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index].data() as Map<String, dynamic>;
                        return _CommentItem(comment: comment);
                      },
                    );
                  },
                ),
              ),
              
              // Comment input
              _CommentInput(reelId: widget.reel.id),
            ],
          ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Save option
            _MenuOption(
              icon: Icons.bookmark_outline,
              title: 'Save',
              onTap: () {
                Navigator.pop(context);
                _saveReel(widget.reel);
              },
            ),
            
            if (!isOwnReel) ...[
              const Divider(color: Colors.white10),
              
              // Not Interested
              _MenuOption(
                icon: Icons.not_interested,
                title: 'Not interested',
                subtitle: 'Hide this reel',
                onTap: () {
                  Navigator.pop(context);
                  _hideReel(widget.reel);
                },
              ),
              
              const Divider(color: Colors.white10),
              
              // Mute reposts
              _MenuOption(
                icon: Icons.volume_off_outlined,
                title: 'Mute reposts from @${widget.reel.username}',
                onTap: () {
                  Navigator.pop(context);
                  _muteRepostsFrom(widget.reel.userId);
                },
              ),
            ],
            
            if (isOwnReel) ...[
              const Divider(color: Colors.white10),
              
              // Delete (own reel)
              _MenuOption(
                icon: Icons.delete_outline,
                title: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _deleteReel(widget.reel);
                },
              ),
            ],
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Save reel
  Future<void> _saveReel(Reel reel) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('saved')
        .doc(reel.id)
        .set({
          'type': 'reel',
          'reelId': reel.id,
          'savedAt': FieldValue.serverTimestamp(),
        });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel saved!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving reel: $e');
    }
  }

  // Hide reel (Not Interested)
  Future<void> _hideReel(Reel reel) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('hidden_reels')
        .doc(reel.id)
        .set({
          'reelId': reel.id,
          'hiddenAt': FieldValue.serverTimestamp(),
        });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel hidden. We\'ll show you less like this.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error hiding reel: $e');
    }
  }

  // Mute reposts from user
  Future<void> _muteRepostsFrom(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('muted_reposts')
        .doc(userId)
        .set({
          'userId': userId,
          'mutedAt': FieldValue.serverTimestamp(),
        });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reposts from this user are now muted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error muting reposts: $e');
    }
  }

  // Delete own reel
  Future<void> _deleteReel(Reel reel) async {
    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Delete Reel?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This reel will be permanently deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    try {
      await ReelService.instance.deleteReel(reel.id, currentUser.uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting reel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
                          child: StreamBuilder<bool>(
                            stream: _friendStatusStream,
                            builder: (context, snapshot) {
                              final isFriend = snapshot.data ?? false;
                              return GestureDetector(
                                onTap: () => _toggleFriend(widget.reel.userId),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: isFriend
                                        ? Colors.grey
                                        : AppTheme.primaryPurple,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black, width: 1.5),
                                  ),
                                  child: Icon(
                                    isFriend
                                        ? Icons.check
                                        : Icons.add,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
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
                  onTap: _showReelOptions,
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
                    // Follow/Kakonek button
                    StreamBuilder<bool>(
                      stream: _friendStatusStream,
                      builder: (context, snapshot) {
                        final isFriend = snapshot.data ?? false;
                        final isOwnReel = widget.reel.userId == widget.currentUserId;
                        
                        if (isOwnReel) return const SizedBox.shrink();
                        
                        return GestureDetector(
                          onTap: () => _toggleFriend(widget.reel.userId),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isFriend 
                                ? Colors.transparent 
                                : AppTheme.primaryPurple,
                              borderRadius: BorderRadius.circular(6),
                              border: isFriend
                                ? Border.all(color: Colors.white, width: 1.5)
                                : null,
                            ),
                            child: Text(
                              isFriend ? 'Kakonek' : 'Follow',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
  final String message;

  const _EmptyReelsState({
    required this.onUpload,
    this.message = 'No reels yet',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_collection_outlined, color: Colors.white30, size: 80),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.add),
            label: const Text('Create First Reel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

// Comment Item Widget
class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentItem({required this.comment});
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is! Timestamp) return '';
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.person, size: 16, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment['username'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment['text'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(comment['timestamp']),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Comment Input Widget
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _postComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    setState(() => _isPosting = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Get user info
      final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
      final userData = userDoc.data() ?? {};
      
      // Add comment
      await FirebaseFirestore.instance
        .collection('reels')
        .doc(widget.reelId)
        .collection('comments')
        .add({
          'userId': currentUser.uid,
          'username': userData['username'] ?? 'User',
          'photoURL': userData['photoURL'] ?? '',
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
        });
      
      // Increment comment count
      await FirebaseFirestore.instance
        .collection('reels')
        .doc(widget.reelId)
        .update({
          'comments': FieldValue.increment(1),
        });
      
      _controller.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      debugPrint('Error posting comment: $e');
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            _isPosting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryPurple,
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: AppTheme.primaryPurple,
                  ),
                  onPressed: _postComment,
                ),
          ],
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  
  const _MenuOption({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
        ? Text(
            subtitle!,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          )
        : null,
      onTap: onTap,
    );
  }
}
