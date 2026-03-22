import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum representing the different types of posts supported in the app.
enum PostType { text, image, video, tiktok, mood }

/// Helper extension for PostType
extension PostTypeExtension on PostType {
  String get name => toString().split('.').last;
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
  final int repostCount; // ── New field ─────────────────────────────────────
  final List<String> likedBy;
  final bool isPublic;

  // ─── Mood & Expiration ────────────────────────────────────────────────────
  final DateTime? expiresAt;
  final String? moodEmoji;
  final String? moodLabel;

  // ─── Repost Fields ────────────────────────────────────────────────────────
  final bool isRepost;
  final String? originalPostId;
  final String? originalUserId;
  final String? originalUsername;
  final String? repostedBy; // Person who is reposting (their username)
  final DateTime? repostedAt;

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
    this.repostCount = 0,
    this.likedBy = const [],
    this.isPublic = true,
    this.expiresAt,
    this.moodEmoji,
    this.moodLabel,
    this.isRepost = false,
    this.originalPostId,
    this.originalUserId,
    this.originalUsername,
    this.repostedBy,
    this.repostedAt,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      type: PostType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => PostType.text,
      ),
      content: data['content'] ?? '',
      caption: data['caption'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      repostCount: data['repostCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      isPublic: data['isPublic'] ?? true,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      moodEmoji: data['moodEmoji'],
      moodLabel: data['moodLabel'],
      isRepost: data['isRepost'] ?? false,
      originalPostId: data['originalPostId'],
      originalUserId: data['originalUserId'],
      originalUsername: data['originalUsername'],
      repostedBy: data['repostedBy'],
      repostedAt: (data['repostedAt'] as Timestamp?)?.toDate(),
    );
  }

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
      'repostCount': repostCount,
      'likedBy': likedBy,
      'isPublic': isPublic,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'moodEmoji': moodEmoji,
      'moodLabel': moodLabel,
      'isRepost': isRepost,
      'originalPostId': originalPostId,
      'originalUserId': originalUserId,
      'originalUsername': originalUsername,
      'repostedBy': repostedBy,
      'repostedAt': repostedAt != null ? Timestamp.fromDate(repostedAt!) : null,
    };
  }

  // Check if post has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Get time remaining for mood posts
  String get timeRemaining {
    if (expiresAt == null) return '';
    final remaining = expiresAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';

    if (remaining.inHours > 0) {
      return '${remaining.inHours}h remaining';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m remaining';
    } else {
      return '${remaining.inSeconds}s remaining';
    }
  }

  static String getCollectionName() => 'posts';
}
