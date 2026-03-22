import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum representing the different types of posts supported in the app.
enum PostType { text, image, video, tiktok }

/// Helper extension to safely get string name from enum
extension PostTypeExtension on PostType {
  String get name => toString().split('.').last;
}

PostType _postTypeFromString(String type) {
  switch (type.toLowerCase()) {
    case 'image':
      return PostType.image;
    case 'video':
      return PostType.video;
    case 'tiktok':
      return PostType.tiktok;
    case 'text':
    default:
      return PostType.text;
  }
}

/// A model class representing a social media post in the Konek app.
class Post {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final PostType type;
  final String content;
  final String? caption;
  final DateTime timestamp;
  final int likes;
  final int comments;
  final List<String> likedBy;
  final bool isPublic;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.type,
    required this.content,
    this.caption,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
    this.likedBy = const [],
    this.isPublic = true,
  });

  /// Factory method to create a [Post] instance from a Firestore [DocumentSnapshot].
  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      type: _postTypeFromString(data['type'] ?? 'text'),
      content: data['content'] ?? '',
      caption: data['caption'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      isPublic: data['isPublic'] ?? true,
    );
  }

  /// Converts a [Post] instance into a map suitable for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'type': type.name,
      'content': content,
      'caption': caption,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'comments': comments,
      'likedBy': likedBy,
      'isPublic': isPublic,
    };
  }

  /// Returns the Firestore collection name where posts are stored.
  static String getCollectionName() {
    return 'posts';
  }
}
