import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme/app_theme.dart';
import '../widgets/user_photo_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _markAllRead() async {
    if (_currentUserId == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get();
        
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: Text("Please log in", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all as read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: _currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications yet', style: TextStyle(color: AppTheme.textSecondary)));
          }

          final docs = snapshot.data!.docs.toList();
          
          // Sort in memory globally bypassing composite index constraints
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final aDate = aTime?.toDate() ?? DateTime.now();
            final bDate = bTime?.toDate() ?? DateTime.now();
            return bDate.compareTo(aDate);
          });

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final n = doc.data() as Map<String, dynamic>;
              
              final bool isRead = n['isRead'] ?? false;
              final timestamp = (n['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final senderId = n['senderId'] ?? '';
              final senderName = n['senderName'] ?? 'User';
              final message = n['message'] ?? '';

              return ListTile(
                leading: UserPhotoWidget(userId: senderId, radius: 20),
                title: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    children: [
                      TextSpan(text: senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' '),
                      TextSpan(text: message),
                    ],
                  ),
                ),
                subtitle: Text(
                  timeago.format(timestamp), 
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)
                ),
                trailing: !isRead
                    ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))
                    : null,
                onTap: () {
                  if (!isRead) doc.reference.update({'isRead': true});
                },
                tileColor: !isRead ? Colors.orange.withOpacity(0.05) : null,
              );
            },
          );
        },
      ),
    );
  }
}
