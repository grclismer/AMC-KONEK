import 'dart:typed_data';

/// This file is used only on Web during compilation to satisfy symbols.
class VideoCompressorNative {
  static Future<Uint8List?> compressForMobile(
    Uint8List videoBytes,
    String fileName,
    int targetSizeKB,
  ) async {
    // This should never be reached on web because of kIsWeb check in main file.
    return null;
  }
}
