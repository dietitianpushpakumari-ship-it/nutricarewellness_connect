import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({super.key, required this.pdfUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        // 🚀 THIS WILL CATCH THE ERROR
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          debugPrint("🔴 PDF ERROR: ${details.error}");
          debugPrint("🔴 PDF DESCRIPTION: ${details.description}");

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Failed to load PDF: ${details.error}"),
                  backgroundColor: Colors.redAccent,
                )
            );
          }
        },
      ),
    );
  }
}