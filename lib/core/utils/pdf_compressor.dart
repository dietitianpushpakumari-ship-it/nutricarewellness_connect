import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PdfCompressor {
  static Future<File?> compress(File file) async {
    try {
      // 1. Load the existing PDF document
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // 2. Apply Compression Settings
      document.compressionLevel = PdfCompressionLevel.best;

      // 3. Save to a new temp file
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(dir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}.pdf");
      final File compressedFile = File(targetPath);

      // Write the compressed bytes
      final List<int> compressedBytes = await document.save();
      await compressedFile.writeAsBytes(compressedBytes);

      // 4. Cleanup
      document.dispose();

      print("PDF Compressed: ${file.lengthSync()} -> ${compressedFile.lengthSync()} bytes");
      return compressedFile;

    } catch (e) {
      print("PDF Compression Failed: $e");
      return file; // Return original if failure
    }
  }
}