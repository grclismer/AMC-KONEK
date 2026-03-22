import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;  // [userId1, userId2]
  final String lastMessage;
  final String lastMessageType;     // 'text' or 'image'
  final String lastMessageSenderId;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCount; // {userId: count}
  final Map<String, bool> typing;     // {userId: isTyping}
  final DateTime createdAt;
  
  Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageSenderId,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.typing,
    required this.createdAt,
  });
  
  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageType: data['lastMessageType'] ?? 'text',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      typing: Map<String, bool>.from(data['typing'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
      'typing': typing,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
  
  // Helper to get other participant
  String getOtherParticipant(String currentUserId) {
    if (participants.length < 2) return '';
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }
  
  // Helper to get unread count for user
  int getUnreadCount(String userId) {
    return unreadCount[userId] ?? 0;
  }
  
  // Helper to check if other user is typing
  bool isOtherUserTyping(String currentUserId) {
    final otherId = getOtherParticipant(currentUserId);
    if (otherId.isEmpty) return false;
    return typing[otherId] ?? false;
  }
}
