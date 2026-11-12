import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // 🚀 Added to support raw memory bytes for Web
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class CloudinaryService {
  final String _cloudName = 'drxqo1g7z';
  final String _uploadPreset = 'nutricare_preset';

  /// 📱 NATIVE UPLOAD: Uploads a file using dart:io (For iOS/Android)
  Future<String?> uploadFile({
    required File file,
    required String folderName,
  }) async {
    try {
      // 'auto' allows Cloudinary to detect if it's an image, video, or raw file
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

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

  /// 🌐 WEB UPLOAD: Uploads raw memory bytes directly to bypass dart:io File crashes
  /// 🌐 WEB UPLOAD: Uploads raw memory bytes directly to bypass dart:io File crashes
  /// 🌐 WEB UPLOAD: Uploads raw memory bytes directly
  Future<String?> uploadWebFile({
    required Uint8List bytes,
    required String fileName,
    required String folderName,
  }) async {
    try {
      // 🚀 THE FIX: Rip out the proxy entirely!
      // Hit Cloudinary directly since it already supports Web CORS for your app.
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'nutricare/$folderName';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonResponse['secure_url'] as String;
      } else {
        debugPrint(
            "Cloudinary Web Upload Error: ${jsonResponse['error']['message']}");
        return null;
      }
    } catch (e) {
      debugPrint("Exception during Cloudinary web upload: $e");
      return null;
    }
  }
}
// 🎯 Riverpod Provider
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) => CloudinaryService());