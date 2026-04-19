import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'new/utils/image_compressor.dart';

class MediaPickerUtil {
  /// Shows a WhatsApp-style bottom sheet and returns a Compressed WebP File
  static Future<File?> pickImageWithCompression(BuildContext context,{ImageSource? source}) async {
    ImageSource? selectedSource = source;
    if (selectedSource == null) {
      selectedSource = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _MediaPickerSheet(),
      );
    }

    if (selectedSource == null) return null;

    final ImagePicker picker = ImagePicker();
    try {
      // 2. Initial Pick
      final XFile? pickedFile = await picker.pickImage(
        source: selectedSource,
        imageQuality: 70,
      );

      if (pickedFile == null) return null;

      // 3. High-Grade WebP Compression
      File originalFile = File(pickedFile.path);
      File? compressedFile = await ImageCompressor.compressAndGetFile(originalFile);

      return compressedFile ?? originalFile;
    } catch (e) {
      debugPrint("Error picking/compressing image: $e");
      return null;
    }
  }
}

class _MediaPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text("Select Source", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOption(context, "Camera", Icons.camera_alt_rounded, Colors.pink, ImageSource.camera),
              _buildOption(context, "Gallery", Icons.photo_library_rounded, Colors.purple, ImageSource.gallery),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String label, IconData icon, Color color, ImageSource source) {
    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context, source),
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}