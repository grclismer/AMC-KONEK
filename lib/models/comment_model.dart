import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String avatarUrl;
  final String text;
  final DateTime timestamp;
  final int likes;
  final List<String> likedBy;
  
  // New fields for Threads/Replies
  final String? replyToId; // ID of the parent comment
  final String? replyToUsername; // Username being replied to
  final int replyCount;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.text,
    required this.timestamp,
    this.likes = 0,
    this.likedBy = const [],
    this.replyToId,
    this.replyToUsername,
    this.replyCount = 0,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return Comment(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      replyToId: data['replyToId'],
      replyToUsername: data['replyToUsername'],
      replyCount: data['replyCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'likedBy': likedBy,
      'replyToId': replyToId,
      'replyToUsername': replyToUsername,
      'replyCount': replyCount,
    };
  }
}
