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
}
