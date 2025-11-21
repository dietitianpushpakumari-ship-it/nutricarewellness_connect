import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🎯 Add Import

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? localPath;

  const FullScreenImageViewer({super.key, this.imageUrl, this.localPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: imageUrl != null
          // 🎯 Use Cached Image here too
              ? CachedNetworkImage(
            imageUrl: imageUrl!,
            placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
          )
              : Image.file(File(localPath!)),
        ),
      ),
    );
  }
}