import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// This file should only be loaded on Native platforms (Android/iOS/Windows).
class NativeMediaService {
  static Future<Uint8List?> compressImage(String path) async {
    try {
      return await FlutterImageCompress.compressWithFile(
        path,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      print('❌ Native Image Compress Error: $e');
      return null;
    }
  }

  static Future<Uint8List?> compressVideo(
    Uint8List videoBytes,
    String fileName,
    int targetSizeKB,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempInputFile = File('${tempDir.path}/v_in_$fileName');
      await tempInputFile.writeAsBytes(videoBytes);
      
      final currentSizeKB = videoBytes.length / 1024;
      final compressionRatio = targetSizeKB / currentSizeKB;
      
      VideoQuality quality = VideoQuality.DefaultQuality;
      if (compressionRatio >= 0.8) quality = VideoQuality.HighestQuality;
      else if (compressionRatio >= 0.6) quality = VideoQuality.DefaultQuality;
      else if (compressionRatio >= 0.4) quality = VideoQuality.MediumQuality;
      else if (compressionRatio >= 0.2) quality = VideoQuality.LowQuality;
      else quality = VideoQuality.Res640x480Quality;
      
      final compressedInfo = await VideoCompress.compressVideo(
        tempInputFile.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );
      
      if (compressedInfo?.file == null) return null;
      final compressedBytes = await compressedInfo!.file!.readAsBytes();
      
      // Cleanup
      if (await tempInputFile.exists()) await tempInputFile.delete();
      if (await compressedInfo.file!.exists()) await compressedInfo.file!.delete();
      
      return compressedBytes;
    } catch (e) {
      print('❌ Native Video Compress Error: $e');
      return null;
    }
  }
}
