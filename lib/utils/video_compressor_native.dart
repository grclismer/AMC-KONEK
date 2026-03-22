import 'dart:io';
import 'dart:typed_data';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

/// This file should only be imported on non-web platforms.
class VideoCompressorNative {
  static Future<Uint8List?> compressForMobile(
    Uint8List videoBytes,
    String fileName,
    int targetSizeKB,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempInputFile = File('${tempDir.path}/input_$fileName');
      await tempInputFile.writeAsBytes(videoBytes);
      
      final currentSizeKB = videoBytes.length / 1024;
      final compressionRatio = targetSizeKB / currentSizeKB;
      
      // Calculate quality
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
      print('❌ Native compression error: $e');
      return null;
    }
  }
}
