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
    return Scaffold(
      backgroundColor: Colors.white,
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
          // Thoughts Bar (Above Search)
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
                              backgroundImage: AssetImage('assets/me.jpg'),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
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
                fillColor: Colors.grey[100],
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
                  onLongPress: () => _showChatMenu(chat),
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
                              border: Border.all(color: Colors.white, width: 2),
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
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(chat['time'], style: TextStyle(color: hasUnread ? Colors.blue : Colors.grey[400], fontSize: 11)),
                      const SizedBox(height: 4),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                          child: Text('${chat['unread']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      else
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                          onPressed: () => _showChatMenu(chat),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.orange,
        child: const Icon(Icons.message_outlined, color: Colors.white),
      ),
    );
  }

  /// Navigates to the individual chat room for the selected user.
  /// [context] refers to the current widget build context, and [chat] is the specific chat data.
  void _openChat(BuildContext context, Map<String, dynamic> chat) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(chat: chat)));
  }

  void _showChatMenu(Map<String, dynamic> chat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            ListTile(leading: const Icon(Icons.notifications_off_outlined), title: const Text('Mute notifications'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Delete conversation', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.block, color: Colors.red), title: const Text('Block', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.archive_outlined), title: const Text('Archive'), onTap: () => Navigator.pop(context)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CHAT ROOM SCREEN (Messenger-style)
// ---------------------------------------------------------------------------
class ChatRoomScreen extends StatefulWidget {
  final Map<String, dynamic> chat;
  const ChatRoomScreen({super.key, required this.chat});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;

  final List<Map<String, dynamic>> _messages = [
    {'text': 'Kumusta na pare?', 'isMe': false, 'time': '10:00 AM', 'type': 'text'},
    {'text': 'Mabuti naman! Ikaw?', 'isMe': true, 'time': '10:01 AM', 'type': 'text'},
    {'text': 'Ayos din! Nakita mo na yung latest post ko?', 'isMe': false, 'time': '10:02 AM', 'type': 'text'},
    {'text': 'Oo nakita ko! Grabe talaga 😂', 'isMe': true, 'time': '10:03 AM', 'type': 'text'},
    {'text': '🔥🔥🔥', 'isMe': false, 'time': '10:04 AM', 'type': 'text'},
    {'text': 'Tara kain tayo mamaya!', 'isMe': true, 'time': '10:05 AM', 'type': 'text'},
    {'text': 'Sige! Anong oras?', 'isMe': false, 'time': '10:06 AM', 'type': 'text'},
  ];

  /// Sends the current typed message in the message controller and adds it to the message list.
  /// It clears the text field and scrolls to the bottom after sending.
  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    final now = TimeOfDay.now();
    setState(() {
      _messages.add({
        'text': _msgCtrl.text.trim(),
        'isMe': true,
        'time': now.format(context),
        'type': 'text',
      });
      _msgCtrl.clear();
      _isTyping = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  /// Displays an emoji reaction dialog for a specific message.
  /// [index] represents the index of the message in the message list to react to.
  void _showReaction(int index) {
    final emojis = ['❤️', '😂', '😮', '😢', '😠', '👍'];
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: emojis.map((e) => GestureDetector(
            onTap: () {
              Navigator.pop(context);
              setState(() => _messages[index]['reaction'] = e);
            },
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(e, style: const TextStyle(fontSize: 26))),
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: const BackButton(color: Colors.black87),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {},
          child: Row(
            children: [
              Stack(children: [
                CircleAvatar(radius: 20, backgroundImage: NetworkImage(widget.chat['avatar'])),
                if (widget.chat['online'] == true)
                  Positioned(bottom: 0, right: 0, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
              ]),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.chat['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
                Text(widget.chat['online'] == true ? 'Active now' : 'Offline', style: TextStyle(fontSize: 12, color: widget.chat['online'] == true ? Colors.green : Colors.grey)),
              ]),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone_outlined, color: Colors.orange), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.orange), onPressed: () {}),
          IconButton(icon: const Icon(Icons.info_outline, color: Colors.orange), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['isMe'] as bool;
                return GestureDetector(
                  onLongPress: () => _showReaction(index),
                  child: _MessageBubble(msg: msg, isMe: isMe, chat: widget.chat),
                );
              },
            ),
          ),
          // Typing indicator placeholder
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: Row(children: [
                CircleAvatar(radius: 14, backgroundImage: NetworkImage(widget.chat['avatar'])),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    _dot(0), _dot(150), _dot(300),
                  ]),
                ),
              ]),
            ),
          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(8, 6, 8, MediaQuery.of(context).viewInsets.bottom + 8),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.orange), onPressed: () => _showAttachOptions()),
                IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.orange), onPressed: () {}),
                IconButton(icon: const Icon(Icons.image_outlined, color: Colors.orange), onPressed: () {}),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    onChanged: (v) => setState(() => _isTyping = v.isNotEmpty),
                    decoration: InputDecoration(
                      hintText: 'Aa',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: Icon(_msgCtrl.text.isEmpty ? Icons.thumb_up : Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Creates an animated dot widget used in the typing indicator.
  /// [delayMs] is the delay in milliseconds for the dot's animation.
  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (_, v, __) => Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 7, height: 7, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
    );
  }

  /// Shows a modal bottom sheet with options to attach various types of content (e.g., Image, Location).
  void _showAttachOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _attachItem(Icons.image, 'Gallery', Colors.purple),
                _attachItem(Icons.camera_alt, 'Camera', Colors.blue),
                _attachItem(Icons.insert_drive_file, 'File', Colors.orange),
                _attachItem(Icons.location_on, 'Location', Colors.red),
                _attachItem(Icons.person, 'Contact', Colors.green),
              ]),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Creates a specific attachment item widget with an icon and label.
  /// Used within the attachment options modal bottom sheet.
  Widget _attachItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final Map<String, dynamic> chat;
  const _MessageBubble({required this.msg, required this.isMe, required this.chat});

  /// Builds a message bubble widget for the chat room.
  /// Takes care of the styling for both 'me' and 'others' messages.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(radius: 14, backgroundImage: NetworkImage(chat['avatar'])),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? Colors.orange : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: Text(msg['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
              ),
              if (msg['reaction'] != null)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
                  child: Text(msg['reaction'], style: const TextStyle(fontSize: 14)),
                ),
              const SizedBox(height: 2),
              Text(msg['time'], style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ],
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            const CircleAvatar(radius: 14, backgroundImage: AssetImage('assets/me.jpg')),
          ],
        ],
      ),
    );
  }
}
