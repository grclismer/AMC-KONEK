import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image }

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderPhotoURL;
  final MessageType type;
  final String content;        // Text content or image URL
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readAt;
  
  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoURL,
    required this.type,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.readAt,
  });
  
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Convert string type back to enum
    MessageType typeEnum = MessageType.text;
    String typeString = data['type'] ?? 'text';
    if (typeString == 'image') {
      typeEnum = MessageType.image;
    }

    return Message(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoURL: data['senderPhotoURL'] ?? '',
      type: typeEnum,
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoURL': senderPhotoURL,
      'type': type.toString().split('.').last, // 'text' or 'image'
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }
  
  bool isSentBy(String userId) => senderId == userId;
}
