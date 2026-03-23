import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friends_service.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';
import '../screens/kakonek_center_screen.dart';
import 'user_photo_widget.dart';

class FriendRecommendations extends StatelessWidget {
  const FriendRecommendations({super.key});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: SearchService.instance.getRecommendations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        }
        
        final recommendations = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Suggested Kakonek',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.adaptiveText(context),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const KakonekCenterScreen(initialIndex: 2),
                        ),
                      );
                    },
                    child: Text('See All', style: TextStyle(color: AppTheme.primaryPurple)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 180, // Increased height to prevent overflow
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  return _buildUserCard(
                    context,
                    recommendations[index],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildUserCard(BuildContext context, UserModel user) {
    return Container(
      width: 130, // Slightly narrower for better fit
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: EdgeInsets.all(10), // Reduced padding
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          UserPhotoWidget(
            userId: user.uid,
            radius: 28, // Slightly smaller avatar
            showBorder: true,
            borderGradient: AppTheme.primaryGradient,
            borderWidth: 2,
          ),
          SizedBox(height: 8),
          // Username
          Text(
            user.username,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.adaptiveText(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          // Add button
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await FriendsService.instance.sendFriendRequest(user.uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Request sent to ${user.username}!'),
                        backgroundColor: AppTheme.primaryPurple,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

