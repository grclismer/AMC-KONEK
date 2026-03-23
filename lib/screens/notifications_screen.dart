import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/user_photo_widget.dart';
import '../services/friends_service.dart';
import '../services/notification_service.dart';
import '../screens/profile_screen.dart';
import '../models/post_model.dart';
import '../widgets/post_widget.dart';
import '../utils/app_localizations.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  String _formatTime(Timestamp? ts) {
    final l = AppLocalizations.instance;
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return l.t('time_just_now');
    if (diff.inHours < 1) return '${diff.inMinutes}${l.t('time_minutes_ago')}';
    if (diff.inDays < 1) return '${diff.inHours}${l.t('time_hours_ago')}';
    if (diff.inDays < 7) return '${diff.inDays}${l.t('time_days_ago')}';
    return '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}';
  }

  AppLocalizations get _l => AppLocalizations.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: AppTheme.background(context),
        body: Center(child: Text(_l.t('not_logged_in'), style: TextStyle(color: AppTheme.adaptiveText(context)))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Text(_l.t('notifications_title'), style: TextStyle(color: AppTheme.adaptiveText(context), fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppTheme.adaptiveText(context)),
        actions: [
          TextButton(
            onPressed: () async {
              final batch = FirebaseFirestore.instance.batch();
              final docs = await FirebaseFirestore.instance.collection('notifications')
                .where('recipientId', isEqualTo: currentUserId)
                .where('isRead', isEqualTo: false)
                .get();
              for (final doc in docs.docs) {
                batch.update(doc.reference, {'isRead': true});
              }
              await batch.commit();
            },
            child: Text(_l.t('notifications_mark_all_read'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notifications')
          .where('recipientId', isEqualTo: currentUserId)
          .limit(50)
          .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple));

          final docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            final at = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
            final bt = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
            return bt.compareTo(at);
          });

          if (docs.isEmpty) {
            return Center(child: Text(_l.t('notifications_none'), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 15)));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(height: 0.5, color: Colors.white.withOpacity(0.07)),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final notificationId = docs[index].id;
              final isRead = data['isRead'] as bool? ?? true;
              final senderId = data['senderId'] as String? ?? '';
              final senderName = data['senderName'] as String? ?? 'Someone';
              final message = data['message'] as String? ?? '';
              final type = data['type'] as String? ?? '';
              final requestId = data['requestId'] as String?;
              final postId = data['postId'] as String?;

              Widget? trailing;

              if (type == 'follow') {
                trailing = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () async {
                        if (requestId == null) return;
                        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
                        final myName = userDoc.data()?['username'] ?? 'Someone';
                        
                        await FriendsService.instance.acceptFriendRequest(requestId, senderId);
                        
                        await NotificationService.send(
                          recipientId: senderId,
                          senderId: currentUserId,
                          senderName: myName,
                          type: 'follow_accepted',
                          message: 'accepted your Kakonek request',
                        );
                        
                        await FirebaseFirestore.instance.collection('notifications').doc(notificationId).delete();
                      },
                      child: Text(_l.t('notifications_accept'), style: TextStyle(fontSize: 12)),
                    ),
                    SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      onPressed: () async {
                        if (requestId == null) return;
                        await FriendsService.instance.rejectFriendRequest(requestId, senderId);
                        await FirebaseFirestore.instance.collection('notifications').doc(notificationId).delete();
                      },
                      child: Text(_l.t('notifications_decline'), style: TextStyle(fontSize: 12, color: AppTheme.adaptiveTextSecondary(context))),
                    ),
                  ],
                );
              } else if (!isRead) {
                trailing = Container(
                  width: 8, height: 8, 
                  decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle)
                );
              }

              return ListTile(
                tileColor: isRead ? null : AppTheme.primaryPurple.withOpacity(0.05),
                leading: UserPhotoWidget(userId: senderId, radius: 22),
                title: RichText(
                  text: TextSpan(
                    style: TextStyle(color: AppTheme.adaptiveText(context), fontSize: 14),
                    children: [
                      TextSpan(text: senderName, style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: ' '),
                      TextSpan(text: message),
                    ],
                  ),
                ),
                subtitle: Text(_formatTime(data['timestamp'] as Timestamp?), style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 12)),
                trailing: trailing,
                onTap: () async {
                  if (type == 'follow') return;

                  await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({'isRead': true});

                  if (!context.mounted) return;

                  if (type == 'follow_accepted') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: senderId)));
                  } else if (postId != null && postId.isNotEmpty) {
                    final postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
                    if (!postDoc.exists || !context.mounted) return;
                    
                    final post = Post.fromFirestore(postDoc);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.75,
                        maxChildSize: 0.95,
                        minChildSize: 0.4,
                        builder: (_, controller) => Container(
                          decoration: BoxDecoration(
                            color: AppTheme.background(context),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Column(children: [
                            Center(child: Container(
                              width: 40, height: 4,
                              margin: EdgeInsets.only(top: 12, bottom: 8),
                              decoration: BoxDecoration(color: AppTheme.adaptiveSubtle(context), borderRadius: BorderRadius.circular(2)),
                            )),
                            Expanded(child: SingleChildScrollView(
                              controller: controller,
                              child: PostWidget(post: post),
                            )),
                          ]),
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
