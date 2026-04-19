import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class CloudinaryService {
  // 🛑 Replace these with your actual Cloudinary details
  final String _cloudName = 'drxqo1g7z';
  final String _uploadPreset = 'nutricare_preset';

  /// Uploads a file and returns the secure HTTPS URL
  Future<String?> uploadFile({
    required File file,
    required String folderName,
  }) async {
    try {
      // 'auto' allows Cloudinary to detect if it's an image, video, or raw file (PDF)
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'nutricare/$folderName'; // Organizes your bucket!

      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: path.basename(file.path),
      );

      request.files.add(multipartFile);

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonMap = jsonDecode(responseData);

      if (response.statusCode == 200) {
        // ✅ Success! Return the URL
        return jsonMap['secure_url'];
      } else {
        debugPrint("Cloudinary Error: ${jsonMap['error']['message']}");
        throw Exception(jsonMap['error']['message'] ?? 'Failed to upload file');
      }
    } catch (e) {
      debugPrint("Upload Exception: $e");
      return null;
    }
  }
}

// 🎯 Riverpod Provider
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) => CloudinaryService());