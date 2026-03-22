import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a short video reel in the KONEK app.
class Reel {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String videoUrl;          // Base64 data URI or storage URL
  final String caption;
  final List<String> hashtags;
  final DateTime timestamp;
  final int likes;
  final int comments;
  final int views;
  final List<String> likedBy;
  final String audioName;         // e.g. "Original Audio - username"
  final bool isPublic;

  Reel({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.videoUrl,
    required this.caption,
    required this.hashtags,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.likedBy = const [],
    required this.audioName,
    this.isPublic = true,
  });

  factory Reel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Reel(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      caption: data['caption'] ?? '',
      hashtags: List<String>.from(data['hashtags'] ?? []),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      views: data['views'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      audioName: data['audioName'] ?? '',
      isPublic: data['isPublic'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'videoUrl': videoUrl,
      'caption': caption,
      'hashtags': hashtags,
      'timestamp': FieldValue.serverTimestamp(), // Always use server time
      'likes': likes,
      'comments': comments,
      'views': views,
      'likedBy': likedBy,
      'audioName': audioName,
      'isPublic': isPublic,
    };
  }

  bool isLikedBy(String userId) => likedBy.contains(userId);
}
