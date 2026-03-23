import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text('Privacy Policy',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.adaptiveText(context))),
        backgroundColor: AppTheme.surface(context),
        iconTheme: IconThemeData(color: AppTheme.adaptiveText(context)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(context, '1. Information Collection',
                'Konek collects information you provide when you create an account, such as your name, email, and username. We also collect content you post, like photos and comments.'),
            _buildSection(context, '2. How We Use Information',
                'We use your information to provide and improve Konek, personalize your experience, and ensure the security of our community.'),
            _buildSection(context, '3. Sharing Information',
                'Your posts and profile are visible to others based on your privacy settings. We do not sell your personal data to third parties.'),
            _buildSection(context, '4. Your Rights',
                'You can access, update, or delete your personal information at any time through your account settings.'),
            _buildSection(context, '5. Data Security',
                'We use industry-standard security measures to protect your data, but please remember that no method of transmission over the internet is 100% secure.'),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Last updated: March 2026',
                style: TextStyle(color: AppTheme.adaptiveTextSecondary(context), fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.adaptiveText(context))),
          const SizedBox(height: 8),
          Text(content,
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.adaptiveTextSecondary(context),
                  height: 1.6)),
        ],
      ),
    );
  }
}
