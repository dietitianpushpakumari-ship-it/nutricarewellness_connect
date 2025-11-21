import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageCompressor {
  static Future<File?> compressAndGetFile(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      // Create unique name with .webp extension
      final targetPath = p.join(dir.path, "chat_${DateTime.now().millisecondsSinceEpoch}.webp");

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,      // Good balance
        minWidth: 1024,   // Limit max dimension (1024px is plenty for chat)
        minHeight: 1024,
        format: CompressFormat.webp, // High efficiency
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      return file; // Fallback to original if compression fails
    }
  }
}