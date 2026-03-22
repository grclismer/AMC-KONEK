import 'dart:typed_data';

/// The stub for the Web platform.
class NativeMediaService {
  static Future<Uint8List?> compressImage(String path) async {
    // This will not be called on web; the web path for uploadImage 
    // already fetches bytes and skips native compression.
    return null;
  }

  static Future<Uint8List?> compressVideo(
    Uint8List videoBytes,
    String fileName,
    int targetSizeKB,
  ) async {
    // This is never reached on web due to kIsWeb checks in the main handler.
    return null;
  }
}
