import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../models/reel_model.dart';

class ReelService {
  static final ReelService instance = ReelService._internal();
  factory ReelService() => instance;
  ReelService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> uploadReel({
    required String videoPath,
    required String caption,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    final xfile = XFile(videoPath);
    final bytes = await xfile.readAsBytes();
    final String fileName = 'reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = _storage.ref().child('reels').child(fileName);
    final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
    final String downloadUrl = await uploadTask.ref.getDownloadURL();
    await createReel(videoUrl: downloadUrl, caption: caption);
  }

  Future<void> createReel({
    required String videoUrl,
    required String caption,
    List<String> hashtags = const [],
    bool isPublic = true,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data() ?? {};
    final username = userData['username'] ?? 'user';
    final displayName = userData['displayName'] ?? 'User';
    final parsedHashtags = hashtags.isNotEmpty ? hashtags : _extractHashtags(caption);

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
      'isPublic': isPublic,
    });

    await _firestore.collection('users').doc(currentUser.uid).update({
      'reelCount': FieldValue.increment(1),
    });
  }

  // Para sa Imo — all public reels, sorted in memory (no Firestore index needed)
  Stream<List<Reel>> getReelsStream() {
    return _firestore
        .collection('reels')
        .where('isPublic', isEqualTo: true)
        .limit(50)
        .snapshots(includeMetadataChanges: false)
        .map((snap) {
          final reels = snap.docs.map((doc) => Reel.fromFirestore(doc)).toList();
          reels.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return reels;
        });
  }

  // User profile reels — sorted in memory (no Firestore index needed)
  Stream<List<Reel>> getUserReelsStream(String userId) {
    return _firestore
        .collection('reels')
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots(includeMetadataChanges: false)
        .map((snap) {
          final reels = snap.docs.map((doc) => Reel.fromFirestore(doc)).toList();
          reels.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return reels;
        });
  }

  // Kakonek — friends + self reels, NO orderBy, sort in memory
  Stream<List<Reel>> getKakonekReelsStream(String currentUserId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .asyncExpand((userDoc) {
      final userData = userDoc.data() ?? {};
      final friendIds = List<String>.from(userData['friends'] ?? []);
      final visibleIds = [...friendIds, currentUserId].toSet().toList();

      if (visibleIds.isEmpty) return Stream.value(<Reel>[]);

      // NO .orderBy() — sort in memory to avoid Firestore composite index
      return _firestore
          .collection('reels')
          .where('userId', whereIn: visibleIds.take(10).toList())
          .limit(50)
          .snapshots(includeMetadataChanges: false)
          .map((snapshot) {
        final reels = snapshot.docs
            .map((doc) => Reel.fromFirestore(doc))
            .toList();
        reels.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return reels;
      });
    });
  }

  // Para sa Imo — public reels, sort in memory
  Stream<List<Reel>> getParaSaImoReelsStream(String currentUserId) {
    return _firestore
        .collection('reels')
        .where('isPublic', isEqualTo: true)
        .limit(50)
        .snapshots(includeMetadataChanges: false)
        .map((snap) {
          final reels = snap.docs.map((doc) => Reel.fromFirestore(doc)).toList();
          reels.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return reels;
        });
  }

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

  Future<void> incrementViews(String reelId) async {
    await _firestore.collection('reels').doc(reelId).update({
      'views': FieldValue.increment(1),
    });
  }

  Future<void> deleteReel(String reelId, String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != userId) throw Exception('Unauthorized');
    await _firestore.collection('reels').doc(reelId).delete();
    await _firestore.collection('users').doc(userId).update({
      'reelCount': FieldValue.increment(-1),
    });
  }

  List<String> _extractHashtags(String caption) {
    final regex = RegExp(r'#(\w+)');
    return regex.allMatches(caption).map((m) => m.group(1)!.toLowerCase()).toList();
  }
}
