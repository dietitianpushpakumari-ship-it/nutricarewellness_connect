import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageHelperService {
  static final ImagePicker _picker = ImagePicker();

  /// 📸 Picks an image and converts it to a highly optimized WebP file
  static Future<XFile?> pickAndCompressToWebP({required ImageSource source}) async {
    try {
      // 1. Pick the raw image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 100, // We handle compression in the next step
      );

      if (pickedFile == null) return null;

      // 2. Get a temporary directory to store the converted WebP file
      final dir = await getTemporaryDirectory();
      final String targetPath = '${dir.absolute.path}/meal_log_${DateTime.now().millisecondsSinceEpoch}.webp';

      // 3. Compress and Convert to WebP format
      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        targetPath,
        format: CompressFormat.webp, // 🚀 FORCED WEBP CONVERSION
        quality: 75,                 // 75 is the industry sweet spot for WebP
        minWidth: 1080,              // Prevents massive 4K uploads
        minHeight: 1080,
      );

      return compressedFile;
    } catch (e) {
      print("Image Compression Error: $e");
      return null;
    }
  }
}