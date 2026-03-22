import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String displayName;
  final String email;
  final String photoURL;
  final String bio;
  final DateTime createdAt;
  final List<String> friends;           // Mutual friends (Kakonek)
  final List<String> pendingRequests;   // Incoming requests
  final List<String> sentRequests;      // Outgoing requests
  final int friendCount;
  final int postCount;
  final int searchCount;
  
  UserModel({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    required this.photoURL,
    this.bio = '',
    required this.createdAt,
    this.friends = const [],
    this.pendingRequests = const [],
    this.sentRequests = const [],
    this.friendCount = 0,
    this.postCount = 0,
    this.searchCount = 0,
  });
  
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'] ?? '',
      bio: data['bio'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      friends: List<String>.from(data['friends'] ?? []),
      pendingRequests: List<String>.from(data['pendingRequests'] ?? []),
      sentRequests: List<String>.from(data['sentRequests'] ?? []),
      friendCount: data['friendCount'] ?? 0,
      postCount: data['postCount'] ?? 0,
      searchCount: data['searchCount'] ?? 0,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'displayName': displayName,
      'usernameLower': username.toLowerCase(),
      'displayNameLower': displayName.toLowerCase(),
      'email': email,
      'photoURL': photoURL,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'friends': friends,
      'pendingRequests': pendingRequests,
      'sentRequests': sentRequests,
      'friendCount': friendCount,
      'postCount': postCount,
      'searchCount': searchCount,
    };
  }

  String get usernameLower => username.toLowerCase();
  String get displayNameLower => displayName.toLowerCase();

  
  bool isFriendsWith(String userId) {
    return friends.contains(userId);
  }
  
  bool hasPendingRequestFrom(String userId) {
    return pendingRequests.contains(userId);
  }
  
  bool hasSentRequestTo(String userId) {
    return sentRequests.contains(userId);
  }
}
