import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/post_model.dart';
import '../utils/app_localizations.dart';

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
        title: Text(
          AppLocalizations.instance.t('saved_title'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPurple,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: AppLocalizations.instance.t('saved_tab_posts')),
            Tab(text: AppLocalizations.instance.t('saved_tab_reels')),
            Tab(text: AppLocalizations.instance.t('saved_tab_reposts')),
            Tab(text: AppLocalizations.instance.t('saved_tab_tagged')),
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
          return Center(
            child: Text(
              AppLocalizations.instance.t('saved_no_posts'),
              style: const TextStyle(color: AppTheme.textSecondary),
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
          return Center(
            child: Text(
              AppLocalizations.instance.t('saved_no_reels'),
              style: const TextStyle(color: AppTheme.textSecondary),
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
    return Center(
      child: Text(
        AppLocalizations.instance.t('saved_no_reposts'),
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}

// Saved Tagged Tab
class _SavedTaggedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.instance.t('saved_tagged'),
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}
