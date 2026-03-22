import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports to prevent Platform._version error on Web (Edge)
import 'video_compressor_web_stub.dart'
    if (dart.library.io) 'video_compressor_native.dart';

class VideoCompressor {
  /// Compress video to target size (default 1MB)
  static Future<Uint8List?> compressVideoToSize({
    required Uint8List videoBytes,
    required String fileName,
    int targetSizeKB = 1024, // 1MB default
  }) async {
    try {
      print('🎬 Starting compression check...');
      print('Original size: ${formatFileSize(videoBytes.length)}');
      
      // Web handle (size check only)
      if (kIsWeb) {
        return _compressForWeb(videoBytes, targetSizeKB);
      }
      
      // Mobile handle (actual compression via isolated native helper)
      return await VideoCompressorNative.compressForMobile(
        videoBytes,
        fileName,
        targetSizeKB,
      );
      
    } catch (e) {
      print('❌ Compression error: $e');
      return null;
    }
  }
  
  /// Web: Just limit file size (no real compression)
  static Future<Uint8List?> _compressForWeb(
    Uint8List videoBytes,
    int targetSizeKB,
  ) async {
    final currentSizeKB = videoBytes.length / 1024;
    
    if (currentSizeKB <= targetSizeKB) {
      print('✅ Web: File is within free tier limit (${targetSizeKB}KB)');
      return videoBytes;
    }
    
    print('❌ Web: File too large (${formatFileSize(videoBytes.length)}). Limit is ${targetSizeKB}KB');
    return null; // Can't compress in-browser reliably
  }
  
  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
}
