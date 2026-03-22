import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static Future<void> sendNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String type,
    required String message,
    String? postId,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'type': type,
      'message': message,
      if (postId != null) 'postId': postId,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
