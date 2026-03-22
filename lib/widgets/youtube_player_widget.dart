import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YoutubePlayerWidget extends StatefulWidget {
  final String videoUrl;

  const YoutubePlayerWidget({super.key, required this.videoUrl});

  @override
  State<YoutubePlayerWidget> createState() => _YoutubePlayerWidgetState();
}

class _YoutubePlayerWidgetState extends State<YoutubePlayerWidget> {
  late YoutubePlayerController _controller;

  /// Initializes the YouTube player controller with the converted video ID and playback flags.
  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: YoutubePlayer.convertUrlToId(widget.videoUrl)!,
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );
  }

  /// Disposes the YouTube player controller when the widget is removed from the tree.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Builds the YouTube player widget, enabling embedded video playback.
  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      showVideoProgressIndicator: true,
    );
  }
}
