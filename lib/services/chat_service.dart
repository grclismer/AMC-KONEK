import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  static final ChatService instance = ChatService._internal();
  factory ChatService() => instance;
  ChatService._internal();
  
  final _firestore = FirebaseFirestore.instance;
  
  // Get or create chat between two users
  Future<String> getOrCreateChat(String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    
    // Check if chat already exists
    // We query for chats where the current user is a participant
    final existingChat = await _firestore
      .collection('chats')
      .where('participants', arrayContains: currentUser.uid)
      .get();
    
    for (var doc in existingChat.docs) {
      final chat = Chat.fromFirestore(doc);
      if (chat.participants.contains(otherUserId)) {
        return doc.id;
      }
    }
    
    // Create new chat if not found
    final newChat = Chat(
      id: '',
      participants: [currentUser.uid, otherUserId],
      lastMessage: '',
      lastMessageType: 'text',
      lastMessageSenderId: '',
      lastMessageTime: DateTime.now(),
      unreadCount: {
        currentUser.uid: 0,
        otherUserId: 0,
      },
      typing: {
        currentUser.uid: false,
        otherUserId: false,
      },
      createdAt: DateTime.now(),
    );
    
    final docRef = await _firestore
      .collection('chats')
      .add(newChat.toFirestore());
    
    return docRef.id;
  }
  
  // Send message (text or image)
  Future<void> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    
    // Get sender info from users collection
    final userDoc = await _firestore
      .collection('users')
      .doc(currentUser.uid)
      .get();
    final userData = userDoc.data() ?? {};
    
    // 1. Add message to the messages subcollection
    // Use serverTimestamp so Firestore index is stable from the start
    await _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .add({
        'chatId': chatId,
        'senderId': currentUser.uid,
        'senderName': userData['displayName'] ?? 'User',
        'senderPhotoURL': userData['photoURL'] ?? '',
        'type': type.toString().split('.').last,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(), // Server-side timestamp — no flicker
        'isRead': false,
        'readAt': null,
      });
    
    // 2. Update the parent chat document with preview info
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;
    
    final chat = Chat.fromFirestore(chatDoc);
    final otherId = chat.getOtherParticipant(currentUser.uid);
    
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': type == MessageType.text ? content : '📷 Image',
      'lastMessageType': type.toString().split('.').last,
      'lastMessageSenderId': currentUser.uid,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.$otherId': FieldValue.increment(1),
    });
  }
  
  // Stream of messages for a specific chat
  Stream<List<Message>> getMessagesStream(String chatId) {
    return _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots(includeMetadataChanges: false) // Only emit after server confirms — prevents flicker
      .map((snapshot) => snapshot.docs
        .map((doc) => Message.fromFirestore(doc))
        .toList());
  }
  
  // Stream of all chats for the current user
  Stream<List<Chat>> getChatsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value([]);
    
    return _firestore
      .collection('chats')
      .where('participants', arrayContains: currentUser.uid)
      .orderBy('lastMessageTime', descending: true)
      .snapshots(includeMetadataChanges: false)
      .map((snapshot) => snapshot.docs
        .map((doc) => Chat.fromFirestore(doc))
        .toList())
      .handleError((error) {
        // Likely missing composite index. Log it but don't crash the stream.
        // Fix: go to the URL printed in the debug console to create the index.
        print('Chat stream error (check Firestore index): $error');
      });
  }
  
  // Mark all incoming messages in a chat as read
  Future<void> markAsRead(String chatId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Reset unread count for current user
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.${currentUser.uid}': 0,
    });
    
    // Batch update unread messages from the other user
    final unreadMessages = await _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .where('senderId', isNotEqualTo: currentUser.uid)
      .where('isRead', isEqualTo: false)
      .get();
    
    if (unreadMessages.docs.isEmpty) return;
    
    final batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }
  
  // Update real-time typing status
  Future<void> setTyping(String chatId, bool isTyping) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await _firestore.collection('chats').doc(chatId).update({
      'typing.${currentUser.uid}': isTyping,
    });
  }
  
  // Helper for image messages (usually content is a URL or base64)
  Future<void> sendImageMessage({
    required String chatId,
    required String base64Image,
  }) async {
    await sendMessage(
      chatId: chatId,
      content: base64Image,
      type: MessageType.image,
    );
  }
  
  // Remove a specific message
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId)
      .delete();
  }
}
