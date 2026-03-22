import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String mediaUrl;     // Image or video URL
  final String mediaType;    // 'image' or 'video'
  final DateTime timestamp;
  final DateTime expiresAt;  // 24 hours from creation
  final List<String> viewedBy;
  
  Story({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.mediaUrl,
    required this.mediaType,
    required this.timestamp,
    required this.expiresAt,
    required this.viewedBy,
  });
  
  factory Story.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'User',
      avatarUrl: data['avatarUrl'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'timestamp': Timestamp.fromDate(timestamp),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewedBy': viewedBy,
    };
  }
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool hasBeenViewedBy(String userId) => viewedBy.contains(userId);
}
