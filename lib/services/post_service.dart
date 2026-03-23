import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/post_model.dart';

/// A singleton service class to handle all post-related operations in Firestore.
class PostService {
  PostService._privateConstructor();
  static final PostService instance = PostService._privateConstructor();
  factory PostService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String get _collection => Post.getCollectionName();

  /// Returns a real-time stream of posts from mutual friends (Kakonek) and self.
  /// Uses in-memory sorting to avoid Firestore index-related hangs.
  Stream<List<Post>> getPostsStream() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    // 1. Listen to the user's document for friend list updates
    yield* _firestore.collection('users').doc(currentUser.uid).snapshots().asyncExpand((userDoc) {
      final userData = userDoc.data() ?? {};
      final friendIds = List<String>.from(userData['friends'] ?? []);
      final visibleUserIds = [...friendIds, currentUser.uid];

      developer.log('=== POSTS STREAM DEBUG ===');
      developer.log('User: ${currentUser.uid}, Friends Count: ${friendIds.length}');

      // 2. Query Firestore based on visibleUserIds count
      if (visibleUserIds.length <= 10) {
        return _firestore.collection(_collection)
            .where('userId', whereIn: visibleUserIds)
            .limit(100)
            .snapshots()
            .map((snapshot) {
              final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
              // Filter by isPublic and ignore expired moods
              final filtered = posts.where((p) {
                if (p.isExpired) return false;
                if (p.userId == currentUser.uid) return true; // always show own posts
                if (p.privacy == 'private') return false; // never show others' private posts
                return true; // show public and friends posts
              }).toList();
              
              developer.log('Fetched ${snapshot.docs.length} docs, ${filtered.length} visible');
              for (var p in filtered.take(5)) {
                developer.log('  - Post: ${p.id}, Type: ${p.type.name}, Repost: ${p.isRepost}');
              }

              filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return filtered.take(50).toList();
            });
      } else {
        // For >10 friends, fetch 100 recent posts and filter client-side
        return _firestore.collection(_collection)
            .limit(100)
            .snapshots()
            .map((snapshot) {
              final allPosts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
              final filtered = allPosts.where((post) {
                if (!visibleUserIds.contains(post.userId)) return false;
                if (post.isExpired) return false;
                if (post.userId == currentUser.uid) return true; // always show own posts
                if (post.privacy == 'private') return false; // never show others' private posts
                return true; // show public and friends posts
              }).toList();

              developer.log('Large list fetch: ${allPosts.length} docs, ${filtered.length} filtered');

              filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return filtered.take(50).toList();
            });
      }
    });
  }

  /// Returns a real-time stream of all public posts for the "Discover" feed.
  /// Excludes posts from the current user and their Kakonek (mutual friends).
  Stream<List<Post>> getDiscoverPostsStream() async* {
    final currentUser = _auth.currentUser;
    if (currentUser == null) { yield []; return; }

    yield* _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .asyncExpand((userDoc) {
      final userData = userDoc.data() ?? {};
      final friendIds = List<String>.from(userData['friends'] ?? []);
      final excludeIds = {...friendIds, currentUser.uid};

      return _firestore.collection(_collection).limit(100).snapshots().map((snapshot) {
        final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
        final filtered = posts.where((p) =>
          !excludeIds.contains(p.userId) && p.privacy != 'private' && p.privacy != 'friends' && !p.isExpired && !p.isRepost
        ).toList();
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return filtered.take(50).toList();
      });
    });
  }

  /// Get user's original posts ONLY (no reposts)
  Stream<List<Post>> getUserPostsStream(String userId) {
    developer.log('=== getUserPostsStream for $userId ===');
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          developer.log('GET_USER_POSTS: Received ${snapshot.docs.length} docs from Firestore');
          final posts = snapshot.docs
            .map((doc) => Post.fromFirestore(doc))
            .where((post) {
              // ✅ Filter original content and non-expired moods locally
              final keep = !post.isRepost && !post.isExpired && post.privacy != 'private';
              if (!keep) developer.log('Filtering out: ${post.id} (isRepost: ${post.isRepost}, isExpired: ${post.isExpired})');
              return keep;
            })
            .toList();
          
          // ✅ Sort locally to avoid index requirement
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          developer.log('Returning ${posts.length} original posts after local filter/sort');
          return posts;
        });
  }

  /// Returns a live stream of private posts (isPublic == false) for a user.
  Stream<List<Post>> getPrivatePostsStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => Post.fromFirestore(doc))
              .where((post) => (post.privacy == 'private' || (!post.isPublic && post.privacy != 'friends')) && !post.isRepost && !post.isExpired)
              .toList();
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return posts;
        });
  }

  /// Get user's reposts ONLY
  Stream<List<Post>> getUserRepostsStream(String userId) {
    developer.log('=== getUserRepostsStream for $userId ===');
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          developer.log('GET_USER_REPOSTS: Received ${snapshot.docs.length} docs from Firestore');
          final posts = snapshot.docs
            .map((doc) => Post.fromFirestore(doc))
            .where((post) {
              // ✅ Filter reposts locally
              final keep = post.isRepost && !post.isExpired;
              return keep;
            })
            .toList();
          
          // ✅ Sort locally
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          developer.log('Returning ${posts.length} reposts after local filter/sort');
          return posts;
        });
  }

  /// Returns a real-time stream of all posts for a specific user (legacy wrapper)
  Stream<List<Post>> getPostsByUserStream(String userId, {bool excludeReposts = false}) {
    if (excludeReposts) return getUserPostsStream(userId);
    
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((QuerySnapshot snapshot) {
      return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  /// Clean up expired mood posts (Call on app start or periodically)
  Future<void> cleanupExpiredPosts() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('expiresAt', isLessThan: Timestamp.now())
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      developer.log('Deleted ${snapshot.docs.length} expired mood posts');
    } catch (e) {
      developer.log('Error cleaning up expired posts', error: e);
    }
  }

  /// Adds a new post to Firestore and returns the created post's ID.
  Future<String> createPost({required Post post}) async {
    try {
      DocumentReference docRef = post.id.isEmpty 
          ? _firestore.collection(_collection).doc() 
          : _firestore.collection(_collection).doc(post.id);

      final postMap = post.toFirestore();
      postMap['timestamp'] = FieldValue.serverTimestamp();

      await docRef.set(postMap);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  /// Deletes a post from Firestore by its ID.
  Future<void> deletePost(String postId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('Not logged in');

      final docRef = _firestore.collection(_collection).doc(postId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Post not found');

      final post = Post.fromFirestore(snapshot);
      if (post.userId != currentUserId) throw Exception('Unauthorized');

      if (post.type == PostType.image && post.content.contains('firebasestorage')) {
        try { await FirebaseStorage.instance.refFromURL(post.content).delete(); } catch (_) {}
      }

      await docRef.delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  /// Atomic like/unlike operations using Firestore transactions.
  Future<void> likePost(String postId, String userId) async {
    final docRef = _firestore.collection(_collection).doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      List<String> likedBy = List<String>.from(snapshot.data()?['likedBy'] ?? []);
      if (!likedBy.contains(userId)) {
        likedBy.add(userId);
        transaction.update(docRef, {'likedBy': likedBy, 'likes': FieldValue.increment(1)});
      }
    });
  }

  Future<void> unlikePost(String postId, String userId) async {
    final docRef = _firestore.collection(_collection).doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      List<String> likedBy = List<String>.from(snapshot.data()?['likedBy'] ?? []);
      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        transaction.update(docRef, {'likedBy': likedBy, 'likes': FieldValue.increment(-1)});
      }
    });
  }

  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    await _firestore.collection(_collection).doc(postId).update(updates);
  }

  Future<Post?> getPostById(String postId) async {
    final snapshot = await _firestore.collection(_collection).doc(postId).get();
    if (snapshot.exists) return Post.fromFirestore(snapshot);
    return null;
  }

  // ─── Repost Logic ───────────────────────────────────────────────────────

  /// Creates a repost of an original post.
  Future<void> repostPost(Post originalPost) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    // Get current reposter's info
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data() ?? {};

    // 1. Prevent duplicate reposts by this user
    final existing = await _firestore
        .collection(_collection)
        .where('isRepost', isEqualTo: true)
        .where('originalPostId', isEqualTo: originalPost.id)
        .where('userId', isEqualTo: currentUser.uid)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('You already reposted this!');
    }

    // 2. Create the Repost Post object
    final repost = Post(
      id: '',
      userId: currentUser.uid,
      username: userData['username'] ?? 'user',
      avatarUrl: userData['photoURL'] ?? '',
      content: originalPost.content,
      caption: originalPost.caption,
      type: originalPost.type,
      timestamp: DateTime.now(), // Current interaction time
      likes: 0,
      comments: 0,
      repostCount: 0,
      likedBy: [],
      isPublic: originalPost.isPublic,

      // Mood Inherit Expiry (moods stay for 24h from original post)
      expiresAt: originalPost.expiresAt,
      moodEmoji: originalPost.moodEmoji,
      moodLabel: originalPost.moodLabel,

      // Repost Meta
      isRepost: true,
      originalPostId: originalPost.id,
      originalUserId: originalPost.userId,
      originalUsername: originalPost.username,
      repostedBy: userData['username'] ?? 'user',
      repostedAt: DateTime.now(),
    );

    // 3. Save Repost
    await createPost(post: repost);

    // 4. Update Repost Count on Original
    await _firestore.collection(_collection).doc(originalPost.id).update({
      'repostCount': FieldValue.increment(1),
    });
  }

  /// Deletes a user's repost of a specific original post.
  Future<void> undoRepost(Post originalPost) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final existing = await _firestore
        .collection(_collection)
        .where('isRepost', isEqualTo: true)
        .where('originalPostId', isEqualTo: originalPost.id)
        .where('userId', isEqualTo: currentUser.uid)
        .get();

    if (existing.docs.isEmpty) return;

    for (var doc in existing.docs) {
      await doc.reference.delete();
    }

    // Decrement repost count
    await _firestore.collection(_collection).doc(originalPost.id).update({
      'repostCount': FieldValue.increment(-1),
    });
  }

  /// Checks if the current user has already reposted a post.
  Future<bool> hasReposted(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final snapshot = await _firestore
        .collection(_collection)
        .where('isRepost', isEqualTo: true)
        .where('originalPostId', isEqualTo: postId)
        .where('userId', isEqualTo: currentUser.uid)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
