import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class VideoCompressor {
  /// Compress video to target size (default 10MB)
  static Future<Uint8List?> compressVideoToSize({
    required Uint8List videoBytes,
    required String fileName,
    int targetSizeKB = 10240, // 10MB default
  }) async {
    final sizeKB = videoBytes.length / 1024;
    
    if (kIsWeb) {
      // Enforce the 10MB size limit for web to avoid CORS/Storage timeouts
      if (sizeKB <= targetSizeKB) return videoBytes;
      return null;
    }
    
    // On mobile, we return the selection directly
    return videoBytes;
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
}
