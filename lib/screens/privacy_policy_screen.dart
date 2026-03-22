import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('1. Information Collection', 
              'Konek collects information you provide when you create an account, such as your name, email, and username. We also collect content you post, like photos and comments.'),
            _buildSection('2. How We Use Information', 
              'We use your information to provide and improve Konek, personalize your experience, and ensure the security of our community.'),
            _buildSection('3. Sharing Information', 
              'Your posts and profile are visible to others based on your privacy settings. We do not sell your personal data to third parties.'),
            _buildSection('4. Your Rights', 
              'You can access, update, or delete your personal information at any time through your account settings.'),
            _buildSection('5. Data Security', 
              'We use industry-standard security measures to protect your data, but please remember that no method of transmission over the internet is 100% secure.'),
            const SizedBox(height: 40),
            Center(
              child: Text('Last updated: March 2026', 
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
        ],
      ),
    );
  }
}
