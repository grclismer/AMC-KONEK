import 'dart:typed_data';
import 'dart:convert';
import 'package:image_picker/image_picker.dart' show XFile;
import '../utils/video_compressor.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  // Upload image — encodes as Base64 data URI (no Firebase Storage needed)
  Future<String> uploadImage(String imagePath, {String folder = 'posts'}) async {
    try {
      final XFile file = XFile(imagePath);
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('Image data is empty');

      final int sizeKB = (bytes.length / 1024).round();
      print('Image size: ${sizeKB}KB');

      if (sizeKB > 700) {
        throw Exception('IMAGE_TOO_LARGE:${sizeKB}KB');
      }

      final String base64String = base64Encode(bytes);
      print('Image encoded. Base64 size: ${VideoCompressor.formatFileSize(base64String.length)}');
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      print('Error uploading image: $e');
      if (e.toString().contains('IMAGE_TOO_LARGE')) rethrow;
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload video — stores in Firestore as Base64 (max 700KB)
  Future<String> uploadVideo(String videoPath, {String folder = 'reels'}) async {
    try {
      print('Preparing video for database storage: $folder');

      // XFile.readAsBytes() works on BOTH web (blob URLs) and mobile (file paths)
      final XFile videoFile = XFile(videoPath);
      final Uint8List rawBytes = await videoFile.readAsBytes();

      final int sizeKB = (rawBytes.length / 1024).round();
      print('Current video size: ${sizeKB}KB');

      // Firestore limit is 1MB per document. Base64 is ~33% larger than binary.
      // 700KB binary = ~930KB Base64.
      if (sizeKB > 700) {
        throw Exception('FILE_TOO_LARGE:${sizeKB}KB');
      }

      print('Encoding video to Base64...');
      final String base64String = base64Encode(rawBytes);
      final String dataUri = 'data:video/mp4;base64,$base64String';

      print('Video conversion complete. Size: ${VideoCompressor.formatFileSize(dataUri.length)} (Base64)');
      return dataUri;
    } catch (e) {
      print('Video processing error: $e');
      if (e.toString().contains('FILE_TOO_LARGE')) rethrow;
      throw Exception('Failed to prepare video: $e');
    }
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(String imagePath) async {
    return uploadImage(imagePath, folder: 'profile_pics');
  }

  // No-op: Base64 URIs are stored in Firestore and cleaned up with the document.
  Future<void> deleteFile(String url) async {
    // Firebase Storage not used — nothing to delete
  }

  Future<int> getFileSize(String url) async {
    if (url.startsWith('data:image')) return url.length;
    return 0;
  }
}
