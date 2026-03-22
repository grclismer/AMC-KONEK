import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'name': 'Kap Onin',
      'action': 'liked your post',
      'time': '2m ago',
      'isUnread': true,
      'avatar': 'https://assets.epuzzle.info/puzzle/158/484/original.jpg',
    },
    {
      'name': 'Doc. Ron',
      'action': 'commented: "Triple B!"',
      'time': '15m ago',
      'isUnread': true,
      'avatar': 'https://i.audiomack.com/markerenzreyes8/ba5a0a2d03.webp?width=1000&height=1000',
    },
    {
      'name': 'Arman Salon',
      'action': 'started following you',
      'time': '1h ago',
      'isUnread': false,
      'avatar': 'https://m.media-amazon.com/images/M/MV5BMTRkMzcyNDYtYWQzMC00MTU5LTkyYmMtMzA2ODg0YjMzY2Q5XkEyXkFqcGc@._V1_QL75_UY281_CR155,0,190,281_.jpg',
    },
    {
      'name': 'Maria Santos',
      'action': 'tagged you in a post',
      'time': '3h ago',
      'isUnread': false,
      'avatar': 'https://randomuser.me/api/portraits/women/44.jpg',
    },
  ];

  void _markAllRead() {
    setState(() {
      for (var n in _notifications) {
        n['isUnread'] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all as read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final n = _notifications[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(n['avatar']),
            ),
            title: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 14),
                children: [
                  TextSpan(text: n['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' '),
                  TextSpan(text: nAction(n)),
                ],
              ),
            ),
            subtitle: Text(n['time'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            trailing: n['isUnread']
                ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))
                : null,
            onTap: () {
              setState(() {
                n['isUnread'] = false;
              });
            },
            tileColor: n['isUnread'] ? Colors.orange.withValues(alpha: 0.05) : null,
          );
        },
      ),
    );
  }

  String nAction(Map<String, dynamic> n) => n['action'];
}
