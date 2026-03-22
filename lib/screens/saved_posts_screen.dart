import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/post_model.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});
  
  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        title: const Text(
          'Saved',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPurple,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Reels'),
            Tab(text: 'Reposts'),
            Tab(text: 'Tagged'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SavedPostsTab(),
          _SavedReelsTab(),
          _SavedRepostsTab(),
          _SavedTaggedTab(),
        ],
      ),
    );
  }
}

// Saved Posts Tab
class _SavedPostsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('saved')
        .where('type', isEqualTo: 'post')
        .orderBy('savedAt', descending: true)
        .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPurple),
          );
        }
        
        final savedDocs = snapshot.data!.docs;
        
        if (savedDocs.isEmpty) {
          return const Center(
            child: Text(
              'No saved posts',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: savedDocs.length,
          itemBuilder: (context, index) {
            final saved = savedDocs[index].data() as Map<String, dynamic>;
            final postId = saved['postId'];
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                .collection('posts')
                .doc(postId)
                .get(),
              builder: (context, postSnap) {
                if (!postSnap.hasData || !postSnap.data!.exists) {
                  return Container(color: AppTheme.surfaceDark);
                }
                
                final post = Post.fromFirestore(postSnap.data!);
                
                // Show thumbnail based on type
                if (post.type == PostType.image) {
                  return Image.network(
                    post.content,
                    fit: BoxFit.cover,
                  );
                }
                
                return Container(
                  color: AppTheme.surfaceDark,
                  child: const Center(
                    child: Icon(
                      Icons.article,
                      color: Colors.white54,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Saved Reels Tab
class _SavedReelsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('saved')
        .where('type', isEqualTo: 'reel')
        .orderBy('savedAt', descending: true)
        .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPurple),
          );
        }
        
        final savedDocs = snapshot.data!.docs;
        
        if (savedDocs.isEmpty) {
          return const Center(
            child: Text(
              'No saved reels',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 9 / 16,
          ),
          itemCount: savedDocs.length,
          itemBuilder: (context, index) {
            final saved = savedDocs[index].data() as Map<String, dynamic>;
            final reelId = saved['reelId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                .collection('reels')
                .doc(reelId)
                .get(),
              builder: (context, reelSnap) {
                if (!reelSnap.hasData || !reelSnap.data!.exists) {
                  return Container(color: Colors.black);
                }
                // Potentially extracted thumbnail or just placeholder icon
                return Container(
                  color: Colors.black,
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Saved Reposts Tab
class _SavedRepostsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Saved reposts',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}

// Saved Tagged Tab
class _SavedTaggedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Posts where you\'re tagged',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}
