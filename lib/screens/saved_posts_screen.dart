import 'package:flutter/material.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  /// Builds the UI for the saved posts screen with categorized tabs.
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved Posts', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.amber,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: false,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.orange,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.grid_on_outlined), text: 'Posts'),
              Tab(icon: Icon(Icons.person_pin_outlined), text: 'Tagged'),
              Tab(icon: Icon(Icons.repeat), text: 'Reposts'),
              Tab(icon: Icon(Icons.video_collection_outlined), text: 'Reels'),
              Tab(icon: Icon(Icons.lock_outline), text: 'Private'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPlaceholder('No saved Posts yet', Icons.grid_on_outlined),
            _buildPlaceholder('No saved Tagged posts yet', Icons.person_pin_outlined),
            _buildPlaceholder('No saved Reposts yet', Icons.repeat),
            _buildPlaceholder('No saved Reels yet', Icons.video_collection_outlined),
            _buildPlaceholder('No saved Private content yet', Icons.lock_outline),
          ],
        ),
      ),
    );
  }

  /// Builds a placeholder widget for empty categories.
  Widget _buildPlaceholder(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
