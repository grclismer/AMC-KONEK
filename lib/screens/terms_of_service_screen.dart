import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text('Terms of Service',
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
            _buildSection(context, '1. Acceptance of Terms',
                'By using Konek, you agree to these terms. If you do not agree, please do not use the app.'),
            _buildSection(context, '2. User Conduct',
                'You are responsible for your activity on Konek. Do not post content that is illegal, harmful, or violates others\' rights.'),
            _buildSection(context, '3. Intellectual Property',
                'You own the content you post, but you grant Konek a license to display and distribute it on the platform.'),
            _buildSection(context, '4. Termination',
                'We reserve the right to suspend or terminate accounts that violate our terms or community guidelines.'),
            _buildSection(context, '5. Limitation of Liability',
                'Konek is provided "as is" without warranties. We are not liable for any damages arising from your use of the app.'),
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
