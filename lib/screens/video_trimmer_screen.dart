import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../theme/app_theme.dart';

class VideoTrimmerScreen extends StatefulWidget {
  final String videoPath;
  final Function(String) onTrimComplete;
  
  const VideoTrimmerScreen({
    super.key,
    required this.videoPath,
    required this.onTrimComplete,
  });
  
  @override
  State<VideoTrimmerScreen> createState() => _VideoTrimmerScreenState();
}

class _VideoTrimmerScreenState extends State<VideoTrimmerScreen> {
  late final VideoEditorController _controller;
  bool _isExporting = false;
  
  @override
  void initState() {
    super.initState();
    _controller = VideoEditorController.file(
      File(widget.videoPath),
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(minutes: 1),
    );
    _controller.initialize().then((_) {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _exportVideo() async {
    setState(() => _isExporting = true);
    
    try {
      final config = VideoFFmpegVideoEditorConfig(
        _controller,
        format: VideoExportFormat.mp4,
        scale: 0.5,
      );
      
      final executeConfig = await config.getExecuteConfig();
      await FFmpegKit.execute(executeConfig.command).then((session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          widget.onTrimComplete(executeConfig.outputPath);
        } else {
          final logs = await session.getLogs();
          debugPrint('FFmpeg Error: ${logs.join('\n')}');
          throw Exception('Video export failed. Check logs.');
        }
      });
    } catch (e) {
      debugPrint('Error exporting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Trim Video', style: TextStyle(color: Colors.white)),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _exportVideo,
              child: const Text(
                'Done',
                style: TextStyle(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _controller.initialized
        ? Column(
            children: [
              Expanded(
                child: CropGridViewer.preview(controller: _controller),
              ),
              Container(
                height: 200,
                color: Colors.black,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Drag to select portion to keep',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TrimSlider(
                        controller: _controller,
                        height: 60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
    );
  }
}
