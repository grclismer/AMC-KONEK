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

      // 2. Query Firestore based on visibleUserIds count
      // Firestore 'whereIn' supports up to 30 items
      if (visibleUserIds.length <= 10) {
        return _firestore.collection(_collection)
            .where('userId', whereIn: visibleUserIds)
            .limit(100)
            .snapshots()
            .map((snapshot) {
              final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
              // In-memory filter for isPublic (safely handles missing fields)
              final filtered = posts.where((p) => p.isPublic).toList();
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
              final filtered = allPosts.where((post) => 
                visibleUserIds.contains(post.userId) && post.isPublic
              ).toList();
              filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return filtered.take(50).toList();
            });
      }
    });
  }

  /// Returns a real-time stream of all public posts for the "Discover" feed.
  Stream<List<Post>> getDiscoverPostsStream() {
    return _firestore.collection(_collection)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
          // Filter by isPublic client-side (handles missing fields as true)
          final publicPosts = posts.where((p) => p.isPublic).toList();
          publicPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return publicPosts.take(50).toList();
        });
  }

  /// Returns a real-time stream of posts for a specific user.
  Stream<List<Post>> getPostsByUserStream(String userId) {
    try {
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((QuerySnapshot snapshot) {
        return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      });
    } catch (e, stackTrace) {
      developer.log('Error streaming user posts', error: e, stackTrace: stackTrace);
      return Stream.value([]);
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
}
