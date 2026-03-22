import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('1. Acceptance of Terms', 
              'By using Konek, you agree to these terms. If you do not agree, please do not use the app.'),
            _buildSection('2. User Conduct', 
              'You are responsible for your activity on Konek. Do not post content that is illegal, harmful, or violates others\' rights.'),
            _buildSection('3. Intellectual Property', 
              'You own the content you post, but you grant Konek a license to display and distribute it on the platform.'),
            _buildSection('4. Termination', 
              'We reserve the right to suspend or terminate accounts that violate our terms or community guidelines.'),
            _buildSection('5. Limitation of Liability', 
              'Konek is provided "as is" without warranties. We are not liable for any damages arising from your use of the app.'),
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
