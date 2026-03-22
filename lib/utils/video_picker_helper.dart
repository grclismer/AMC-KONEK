import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class VideoPickerHelper {
  /// Pick video from gallery - works on web and mobile
  static Future<VideoPickResult?> pickVideo() async {
    try {
      if (kIsWeb) {
        // Web: Use file_picker
        return await _pickVideoWeb();
      } else {
        // Mobile: Use image_picker
        return await _pickVideoMobile();
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }
  
  // Web implementation
  static Future<VideoPickResult?> _pickVideoWeb() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    
    if (result == null || result.files.isEmpty) return null;
    
    final file = result.files.first;
    
    if (file.bytes == null) {
      debugPrint('No bytes available for web file');
      return null;
    }
    
    return VideoPickResult(
      bytes: file.bytes!,
      name: file.name,
      size: file.size,
      path: null, // Web doesn't have file path
    );
  }
  
  // Mobile implementation
  static Future<VideoPickResult?> _pickVideoMobile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    
    if (video == null) return null;
    
    final bytes = await video.readAsBytes();
    
    return VideoPickResult(
      bytes: bytes,
      name: video.name,
      size: bytes.length,
      path: video.path, // Mobile has file path
    );
  }
}

/// Result from video picker
class VideoPickResult {
  final Uint8List bytes;
  final String name;
  final int size;
  final String? path; // Null on web
  
  VideoPickResult({
    required this.bytes,
    required this.name,
    required this.size,
    this.path,
  });
  
  double get sizeInMB => size / (1024 * 1024);
}
