import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';

class CommentService {
  CommentService._privateConstructor();
  static final CommentService instance = CommentService._privateConstructor();
  
  factory CommentService() {
    return instance;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, String> _usernameCache = {};

  Future<String> _getUsernameFromFirestore(String userId) async {
    if (_usernameCache.containsKey(userId)) {
      return _usernameCache[userId]!;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final username = userDoc.data()?['username'] ?? 
                       userDoc.data()?['displayName'] ?? 
                       'Anonymous';
      _usernameCache[userId] = username;
      return username;
    } catch (e) {
      return 'Anonymous';
    }
  }

  String _getCommentsPath(String postId) => '${Post.getCollectionName()}/$postId/comments';

  Stream<List<Comment>> getCommentsStream(String postId) {
    try {
      return _firestore
          .collection(_getCommentsPath(postId))
          .snapshots()
          .map((QuerySnapshot snapshot) {
        final allComments = snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
        // Robust filter handles null, empty string, or missing fields for top-level comments
        final topLevel = allComments.where((c) => c.replyToId == null || c.replyToId!.isEmpty).toList();
        topLevel.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return topLevel;
      });
    } catch (e, stackTrace) {
      developer.log('Error streaming comments', error: e, stackTrace: stackTrace);
      return Stream.value([]);
    }
  }

  /// Fetches replies for a specific comment
  Stream<List<Comment>> getRepliesStream(String postId, String parentCommentId) {
    try {
      return _firestore
          .collection(_getCommentsPath(postId))
          .where('replyToId', isEqualTo: parentCommentId)
          .snapshots()
          .map((QuerySnapshot snapshot) {
        final replies = snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
        replies.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return replies;
      });
    } catch (e, stackTrace) {
      developer.log('Error streaming replies', error: e, stackTrace: stackTrace);
      return Stream.value([]);
    }
  }

  Stream<List<Comment>> getLatestCommentsStream(String postId, {int limit = 2}) {
    try {
      return _firestore
          .collection(_getCommentsPath(postId))
          .snapshots()
          .map((QuerySnapshot snapshot) {
        final allComments = snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
        // Robust filter handles null, empty string, or missing fields for top-level comments
        final topLevel = allComments.where((c) => c.replyToId == null || c.replyToId!.isEmpty).toList();
        topLevel.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return topLevel.take(limit).toList();
      });
    } catch (e, stackTrace) {
      developer.log('Error streaming top comments', error: e, stackTrace: stackTrace);
      return Stream.value([]);
    }
  }

  Future<void> addComment(Comment comment) async {
    try {
      String verifiedUsername = comment.username;
      if (verifiedUsername.isEmpty || verifiedUsername == 'User') {
        verifiedUsername = await _getUsernameFromFirestore(comment.userId);
      }

      final docRef = _firestore.collection(_getCommentsPath(comment.postId)).doc();
      final commentMap = comment.toFirestore();
      commentMap['username'] = verifiedUsername;
      commentMap['timestamp'] = FieldValue.serverTimestamp();

      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection(Post.getCollectionName()).doc(comment.postId);
        
        // 1. ALL READS FIRST
        final postSnapshot = await transaction.get(postRef);
        DocumentSnapshot? parentSnapshot;
        if (comment.replyToId != null) {
          final parentRef = _firestore.collection(_getCommentsPath(comment.postId)).doc(comment.replyToId);
          parentSnapshot = await transaction.get(parentRef);
        }
        
        // Validation
        if (!postSnapshot.exists) throw Exception('Post not found');
        
        // 2. ALL WRITES SECOND
        transaction.set(docRef, commentMap);
        
        // Update post comment count
        final postData = postSnapshot.data();
        int currentComments = postData?['comments'] ?? 0;
        transaction.update(postRef, {'comments': currentComments + 1});

        // If it's a reply, increment parent's replyCount
        if (parentSnapshot != null && parentSnapshot.exists) {
          final parentData = parentSnapshot.data() as Map<String, dynamic>?;
          int currentReplies = parentData?['replyCount'] ?? 0;
          transaction.update(parentSnapshot.reference, {'replyCount': currentReplies + 1});
        }
      });
      
      developer.log('Comment created successfully with ID: ${docRef.id}');
    } catch (e, stackTrace) {
      developer.log('Error creating comment', error: e, stackTrace: stackTrace);
      throw Exception('Failed to create comment: $e');
    }
  }

  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User must be logged in');

      final docRef = _firestore.collection(_getCommentsPath(postId)).doc(commentId);
      final postRef = _firestore.collection(Post.getCollectionName()).doc(postId);

      await _firestore.runTransaction((transaction) async {
        // 1. ALL READS FIRST
        final commentSnapshot = await transaction.get(docRef);
        final postSnapshot = await transaction.get(postRef);
        
        if (!commentSnapshot.exists) throw Exception('Comment not found');
        final comment = Comment.fromFirestore(commentSnapshot);
        
        DocumentSnapshot? parentSnapshot;
        if (comment.replyToId != null) {
          final parentRef = _firestore.collection(_getCommentsPath(postId)).doc(comment.replyToId);
          parentSnapshot = await transaction.get(parentRef);
        }

        // Validation
        if (comment.userId != currentUserId) {
          throw Exception('Unauthorized to delete this comment');
        }

        // 2. ALL WRITES SECOND
        if (postSnapshot.exists) {
            final postData = postSnapshot.data();
            int currentComments = postData?['comments'] ?? 0;
            transaction.update(postRef, {'comments': (currentComments - 1) < 0 ? 0 : currentComments - 1});
        }

        // If it was a reply, decrement parent's replyCount
        if (parentSnapshot != null && parentSnapshot.exists) {
          final parentData = parentSnapshot.data() as Map<String, dynamic>?;
          int currentReplies = parentData?['replyCount'] ?? 0;
          transaction.update(parentSnapshot.reference, {'replyCount': (currentReplies - 1) < 0 ? 0 : currentReplies - 1});
        }
        
        transaction.delete(docRef);
      });
      
      developer.log('Comment $commentId deleted successfully.');
    } catch (e, stackTrace) {
      developer.log('Error deleting comment $commentId', error: e, stackTrace: stackTrace);
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<void> likeComment(String postId, String commentId, String userId) async {
    try {
      final docRef = _firestore.collection(_getCommentsPath(postId)).doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Comment not found');

        List<String> likedBy = List<String>.from(snapshot.data()?['likedBy'] ?? []);
        int currentLikes = snapshot.data()?['likes'] ?? 0;

        if (!likedBy.contains(userId)) {
          likedBy.add(userId);
          transaction.update(docRef, {
            'likedBy': likedBy,
            'likes': currentLikes + 1,
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to like comment: $e');
    }
  }

  Future<void> unlikeComment(String postId, String commentId, String userId) async {
    try {
      final docRef = _firestore.collection(_getCommentsPath(postId)).doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Comment not found');

        List<String> likedBy = List<String>.from(snapshot.data()?['likedBy'] ?? []);
        int currentLikes = snapshot.data()?['likes'] ?? 0;

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          transaction.update(docRef, {
            'likedBy': likedBy,
            'likes': (currentLikes - 1) < 0 ? 0 : currentLikes - 1,
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to unlike comment: $e');
    }
  }

  Future<int> getCommentCount(String postId) async {
    final snapshot = await _firestore.collection(_getCommentsPath(postId)).count().get();
    return snapshot.count ?? 0;
  }
}
