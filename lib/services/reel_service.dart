import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/reel_model.dart';
import 'dart:io';

/// Service for all Reel-related Firestore operations.
class ReelService {
  static final ReelService instance = ReelService._internal();
  factory ReelService() => instance;
  ReelService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ─── Create ───────────────────────────────────────────────────────────────

  /// High-level upload method that handles Storage + Firestore
  Future<void> uploadReel({
    required String videoPath,
    required String caption,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final file = File(videoPath);
    if (!await file.exists()) throw Exception('Source file not found');

    // 1. Upload to Storage
    final String fileName = 'reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = _storage.ref().child('reels').child(fileName);
    
    final uploadTask = await ref.putFile(
      file, 
      SettableMetadata(contentType: 'video/mp4'),
    );
    
    final String downloadUrl = await uploadTask.ref.getDownloadURL();

    // 2. Create Firestore Doc
    await createReel(
      videoUrl: downloadUrl,
      caption: caption,
    );
  }

  /// Uploads a new reel doc to Firestore. 
  /// [videoUrl] can be a Storage URL or Base64 (legacy support).
  Future<void> createReel({
    required String videoUrl,
    required String caption,
    List<String> hashtags = const [],
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    // Fetch the author's profile
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final userData = userDoc.data() ?? {};

    final username = userData['username'] ?? 'user';
    final displayName = userData['displayName'] ?? 'User';

    // Parse hashtags from caption if not supplied separately
    final parsedHashtags = hashtags.isNotEmpty
        ? hashtags
        : _extractHashtags(caption);

    await _firestore.collection('reels').add({
      'userId': currentUser.uid,
      'username': username,
      'displayName': displayName,
      'avatarUrl': userData['photoURL'] ?? '',
      'videoUrl': videoUrl,
      'caption': caption,
      'hashtags': parsedHashtags,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'comments': 0,
      'views': 0,
      'likedBy': [],
      'audioName': 'Original Audio - $username',
      'isPublic': true,
    });

    // Increment the user's reel counter
    await _firestore.collection('users').doc(currentUser.uid).update({
      'reelCount': FieldValue.increment(1),
    });
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  /// Stream of all public reels for the Reels feed page, newest first.
  /// Modified to use in-memory sorting to avoid Firestore index requirements.
  Stream<List<Reel>> getReelsStream() {
    return _firestore
        .collection('reels')
        .where('isPublic', isEqualTo: true)
        .limit(50)
        .snapshots(includeMetadataChanges: false)
        .map((snap) {
          final reels = snap.docs.map((doc) => Reel.fromFirestore(doc)).toList();
          // Sort in-memory to avoid index error
          reels.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return reels;
        })
        .handleError((error) {
      print('ReelService.getReelsStream error: $error');
    });
  }

  /// Stream of reels posted by a specific user (for profile grid).
  Stream<List<Reel>> getUserReelsStream(String userId) {
    return _firestore
        .collection('reels')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: false)
        .map((snap) => snap.docs.map((doc) => Reel.fromFirestore(doc)).toList())
        .handleError((error) {
      print('ReelService.getUserReelsStream error: $error');
    });
  }

  // ─── Like / Unlike ────────────────────────────────────────────────────────

  Future<void> toggleLike(String reelId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final reelRef = _firestore.collection('reels').doc(reelId);
    final reelDoc = await reelRef.get();
    if (!reelDoc.exists) return;

    final reel = Reel.fromFirestore(reelDoc);

    if (reel.isLikedBy(currentUser.uid)) {
      await reelRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([currentUser.uid]),
      });
    } else {
      await reelRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([currentUser.uid]),
      });
    }
  }

  // ─── Views ────────────────────────────────────────────────────────────────

  Future<void> incrementViews(String reelId) async {
    await _firestore.collection('reels').doc(reelId).update({
      'views': FieldValue.increment(1),
    });
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> deleteReel(String reelId, String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != userId) {
      throw Exception('Unauthorized');
    }

    await _firestore.collection('reels').doc(reelId).delete();

    await _firestore.collection('users').doc(userId).update({
      'reelCount': FieldValue.increment(-1),
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Extracts hashtags from a caption string (e.g. "#konek #trending" → ['konek','trending'])
  List<String> _extractHashtags(String caption) {
    final regex = RegExp(r'#(\w+)');
    return regex
        .allMatches(caption)
        .map((m) => m.group(1)!.toLowerCase())
        .toList();
  }
}
