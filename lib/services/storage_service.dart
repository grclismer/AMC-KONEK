import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../utils/video_compressor.dart';

class StorageService {
  // ... (singleton logic)
  // Singleton instance
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // New Storage-based Image handling
  Future<String> uploadImage(String imagePath, {String folder = 'posts'}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      Uint8List? compressedBytes;

      if (kIsWeb) {
        // On web, we fetch the bytes from the blob URL
        print('Web detected: Fetching bytes from path...');
        final assetBundle = NetworkAssetBundle(Uri.parse(imagePath));
        final data = await assetBundle.load(imagePath);
        compressedBytes = data.buffer.asUint8List();
      } else {
        print('Compressing image for cloud storage...');
        compressedBytes = await FlutterImageCompress.compressWithFile(
          imagePath,
          quality: 70,
          minWidth: 1080,
          minHeight: 1080,
          format: CompressFormat.jpeg,
        );
      }

      if (compressedBytes == null) {
        throw Exception('Image compression failed');
      }

      // Generate filename
      final String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child(folder).child(fileName);

      print('Uploading image to Firebase Storage: $folder/$fileName');
      
      // Upload
      final UploadTask uploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Image upload complete: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload video with compression
  Future<String> uploadVideo(String videoPath, {String folder = 'reels'}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('Preparing video upload: $folder');

      Uint8List? rawBytes;
      if (kIsWeb) {
        // Fetch bytes from blob URL
        final assetBundle = NetworkAssetBundle(Uri.parse(videoPath));
        final data = await assetBundle.load(videoPath);
        rawBytes = data.buffer.asUint8List();
      } else {
        final XFile videoFile = XFile(videoPath);
        rawBytes = await videoFile.readAsBytes();
      }

      // 🎬 Compress video
      print('Optimizing video for free tier storage...');
      final compressedBytes = await VideoCompressor.compressVideoToSize(
        videoBytes: rawBytes,
        fileName: videoPath.split('/').last,
        targetSizeKB: 1024, // 1MB limit
      );

      if (compressedBytes == null) {
        throw Exception(kIsWeb 
          ? 'Video is too large (>1MB). Please select a smaller video for web.' 
          : 'Video compression failed.');
      }

      // Generate filename
      final String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final Reference ref = _storage.ref().child(folder).child(fileName);

      print('Starting upload: $folder/$fileName (${VideoCompressor.formatFileSize(compressedBytes.length)})');
      
      final UploadTask uploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Handle progress if needed, but for now just wait
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Video upload complete: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Video upload error: $e');
      throw Exception('Failed to upload video: $e');
    }
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(String imagePath) async {
    return uploadImage(imagePath, folder: 'profile_pics');
  }

  // Delete file from Storage
  Future<void> deleteFile(String url) async {
    try {
      if (url.isEmpty || !url.startsWith('http')) return;
      final ref = _storage.refFromURL(url);
      await ref.delete();
      print('File deleted: $url');
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  // Get file size (Stubbed for Base64 mode)
  Future<int> getFileSize(String url) async {
    if (url.startsWith('data:image')) {
      return url.length;
    }
    return 0;
  }
}
