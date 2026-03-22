import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String fromDisplayName;
  final String fromPhotoURL;
  final String toUserId;
  final DateTime timestamp;
  final FriendRequestStatus status;
  
  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromDisplayName,
    required this.fromPhotoURL,
    required this.toUserId,
    required this.timestamp,
    required this.status,
  });
  
  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      fromDisplayName: data['fromDisplayName'] ?? '',
      fromPhotoURL: data['fromPhotoURL'] ?? '',
      toUserId: data['toUserId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.toString() == 'FriendRequestStatus.${data['status']}',
        orElse: () => FriendRequestStatus.pending,
      ),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromDisplayName': fromDisplayName,
      'fromPhotoURL': fromPhotoURL,
      'toUserId': toUserId,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.toString().split('.').last,
    };
  }
}
