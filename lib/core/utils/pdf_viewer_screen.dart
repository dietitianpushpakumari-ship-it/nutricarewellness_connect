import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({super.key, required this.pdfUrl, required this.title});

  Future<void> _openInBrowser(BuildContext context) async {
    final Uri uri = Uri.parse(pdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open PDF in browser."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: "Open in new tab",
              onPressed: () => _openInBrowser(context),
            ),
        ],
      ),
      body: kIsWeb
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                "PDF Document Ready",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Click below to view or download this PDF in a new browser tab.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openInBrowser(context),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text("Open PDF in Browser"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      )
          : SfPdfViewer.network(
        pdfUrl,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          debugPrint("🔴 PDF ERROR: ${details.error}");
          debugPrint("🔴 PDF DESCRIPTION: ${details.description}");

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to load PDF: ${details.error}"),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
      ),
    );
  }
}