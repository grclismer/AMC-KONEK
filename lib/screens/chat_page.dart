import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// CHAT LIST PAGE
// ---------------------------------------------------------------------------
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, dynamic>> _chats = [
    {'name': 'Kap Onin', 'avatar': 'https://assets.epuzzle.info/puzzle/158/484/original.jpg', 'lastMessage': 'Solid pare! 🔥', 'time': '2m', 'unread': 3, 'online': true},
    {'name': 'Doc. Ron', 'avatar': 'https://i.audiomack.com/markerenzreyes8/ba5a0a2d03.webp?width=1000&height=1000', 'lastMessage': 'Nakita mo na yung video?', 'time': '15m', 'unread': 0, 'online': true},
    {'name': 'Arman Salon', 'avatar': 'https://m.media-amazon.com/images/M/MV5BMTRkMzcyNDYtYWQzMC00MTU5LTkyYmMtMzA2ODg0YjMzY2Q5XkEyXkFqcGc@._V1_QL75_UY281_CR155,0,190,281_.jpg', 'lastMessage': 'Hahaha grabe!', 'time': '1h', 'unread': 1, 'online': false},
    {'name': 'Maria Santos', 'avatar': 'https://randomuser.me/api/portraits/women/44.jpg', 'lastMessage': 'Sana all 😂', 'time': '2h', 'unread': 0, 'online': true},
    {'name': 'Juan dela Cruz', 'avatar': 'https://randomuser.me/api/portraits/men/32.jpg', 'lastMessage': 'Tara kain tayo!', 'time': '5h', 'unread': 0, 'online': false},
    {'name': 'Ana Reyes', 'avatar': 'https://randomuser.me/api/portraits/women/68.jpg', 'lastMessage': 'Iconic!! 😭', 'time': '1d', 'unread': 0, 'online': false},
  ];

  @override
  Widget build(BuildContext context) {
    // Fallback colors if AppTheme is missing
    final surfaceColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.video_call_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Thoughts Bar
          Container(
            height: 110,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _chats.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 15),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundImage: NetworkImage('https://randomuser.me/api/portraits/lego/1.jpg'),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: surfaceColor, shape: BoxShape.circle),
                                child: const Icon(Icons.add, size: 14, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Your thought', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                final chat = _chats[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(radius: 30, backgroundImage: NetworkImage(chat['avatar'])),
                          Positioned(
                            top: -10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                ),
                                child: const Text('Hello! 👋', style: TextStyle(fontSize: 10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(chat['name'].split(' ')[0], style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Chat list
          Expanded(
            child: ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final hasUnread = (chat['unread'] as int) > 0;
                return ListTile(
                  onTap: () => _openChat(context, chat),
                  leading: Stack(
                    children: [
                      CircleAvatar(radius: 28, backgroundImage: NetworkImage(chat['avatar'])),
                      if (chat['online'] == true)
                        Positioned(
                          bottom: 1,
                          right: 1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: surfaceColor, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(chat['name'], style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500, fontSize: 16)),
                  subtitle: Text(
                    chat['lastMessage'],
                    style: TextStyle(color: hasUnread ? Colors.black87 : Colors.grey[500], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(chat['time'], style: TextStyle(color: hasUnread ? Colors.blue : Colors.grey[400], fontSize: 11)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, Map<String, dynamic> chat) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(chat: chat)));
  }
}

class ChatRoomScreen extends StatefulWidget {
  final Map<String, dynamic> chat;
  const ChatRoomScreen({super.key, required this.chat});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {'text': 'Kumusta na pare?', 'isMe': false, 'time': '10:00 AM'},
    {'text': 'Mabuti naman! Ikaw?', 'isMe': true, 'time': '10:01 AM'},
  ];

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'text': _msgCtrl.text.trim(),
        'isMe': true,
        'time': 'Now',
      });
      _msgCtrl.clear();
    });
    _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent + 50, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chat['name']), backgroundColor: Colors.amber),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return Align(
                  alignment: m['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m['isMe'] ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(m['text'], style: TextStyle(color: m['isMe'] ? Colors.white : Colors.black)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgCtrl, decoration: const InputDecoration(hintText: "Type a message..."))),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}