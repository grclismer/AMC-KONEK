import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TikTokPlayerPlaceholder extends StatelessWidget {
  final String url;

  const TikTokPlayerPlaceholder({super.key, required this.url});

  /// Launches the provided TikTok URL in an external application.
  Future<void> _launchTikTok() async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  /// Builds a placeholder UI for TikTok content that launches the TikTok app on tap.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launchTikTok,
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          image: const DecorationImage(
            image: NetworkImage(
              "https://cdn.pixabay.com/photo/2021/06/15/12/28/tiktok-6338429_1280.png",
            ),
            fit: BoxFit.contain,
            opacity: 0.2,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill, color: Colors.white, size: 70),
            SizedBox(height: 10),
            Text(
              "Watch on TikTok",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
