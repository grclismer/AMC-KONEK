import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> send({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String type,
    required String message,
    String? postId,
    String? requestId,
  }) async {
    if (recipientId == senderId) return;
    await _db.collection('notifications').add({
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type,
      'message': message,
      'postId': postId,
      'requestId': requestId,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
