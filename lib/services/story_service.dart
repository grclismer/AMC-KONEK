import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/story_model.dart';
import 'package:flutter/foundation.dart';

class StoryService {
  static final StoryService instance = StoryService._internal();
  factory StoryService() => instance;
  StoryService._internal();
  
  final _firestore = FirebaseFirestore.instance;
  
  // Create story
  Future<void> createStory({
    required String userId,
    required String username,
    required String avatarUrl,
    required String mediaUrl,
    required String mediaType,
    String? caption,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));
    
    final story = Story(
      id: '',
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      timestamp: now,
      expiresAt: expiresAt,
      viewedBy: [],
      caption: caption,
    );
    
    await _firestore.collection('stories').add(story.toFirestore());
  }
  
  // Get user's active story (Single - for backwards compatibility if needed)
  Future<Story?> getUserStory(String userId) async {
    final snapshot = await _firestore
      .collection('stories')
      .where('userId', isEqualTo: userId)
      .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    final stories = snapshot.docs
      .map((doc) => Story.fromFirestore(doc))
      .where((s) => !s.isExpired)
      .toList();
      
    if (stories.isEmpty) return null;
    stories.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return stories.first;
  }

  // Get real-time stream of user's active stories (Multiple)
  Stream<List<Story>> getUserStoriesStream(String userId) {
    return _firestore
      .collection('stories')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
        final stories = snapshot.docs
          .map((doc) => Story.fromFirestore(doc))
          .where((story) => !story.isExpired)
          .toList();
        
        // Sort oldest first for Instagram-style viewing
        stories.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return stories;
      });
  }

  // Get story count
  Future<int> getUserStoryCount(String userId) async {
    final snapshot = await _firestore
      .collection('stories')
      .where('userId', isEqualTo: userId)
      .get();
    
    return snapshot.docs
      .map((doc) => Story.fromFirestore(doc))
      .where((story) => !story.isExpired)
      .length;
  }

  // Delete specific story
  Future<void> deleteStory(String storyId) async {
    await _firestore.collection('stories').doc(storyId).delete();
  }
  
  // Delete expired stories (cleanup)
  Future<void> deleteExpiredStories() async {
    final snapshot = await _firestore
      .collection('stories')
      .where('expiresAt', isLessThan: Timestamp.now())
      .get();
    
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
  
  // Mark story as viewed
  Future<void> markAsViewed(String storyId, String viewerId) async {
    await _firestore.collection('stories').doc(storyId).update({
      'viewedBy': FieldValue.arrayUnion([viewerId]),
    });
  }

  /// Streams one FriendStoryGroup per friend who has active stories.
  /// Uses whereIn on up to 10 friend IDs (Firestore limit).
  Stream<List<FriendStoryGroup>> getFriendsStoriesStream(
      List<String> friendIds, String currentUserId) {
    if (friendIds.isEmpty) return Stream.value([]);

    // Firestore whereIn max is 30; take first 10 to stay safe
    final ids = friendIds.take(10).toList();

    return _firestore
        .collection('stories')
        .where('userId', whereIn: ids)
        .snapshots()
        .map((snapshot) {
      // Filter non-expired
      final active = snapshot.docs
          .map((doc) => Story.fromFirestore(doc))
          .where((s) => !s.isExpired)
          .toList();

      // Group by userId
      final Map<String, List<Story>> grouped = {};
      for (final s in active) {
        grouped.putIfAbsent(s.userId, () => []).add(s);
      }

      // Build groups — one bubble per friend
      final groups = grouped.entries.map((entry) {
        final userStories = entry.value
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final hasUnviewed =
            userStories.any((s) => !s.viewedBy.contains(currentUserId));
        final first = userStories.first;
        return FriendStoryGroup(
          userId: entry.key,
          username: first.username,
          avatarUrl: first.avatarUrl,
          hasUnviewed: hasUnviewed,
          stories: userStories,
        );
      }).toList();

      // Most-recently-updated friends first
      groups.sort((a, b) =>
          b.stories.last.timestamp.compareTo(a.stories.last.timestamp));

      return groups;
    });
  }
}
