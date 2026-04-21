import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> recognizeImage(String imagePath) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw Exception(
        "Tính năng OCR hiện chỉ hỗ trợ trên nền tảng Android và iOS.",
      );
    }

    final InputImage inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );
    return recognizedText.text;
  }

  Future<String> recognizePdf(String pdfPath) async {
    final document = await PdfDocument.openFile(pdfPath);
    String fullText = "";

    for (int i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);
      final pageImage = await page.render(
        width: page.width * 2, // Increase density for better OCR
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
        quality: 90,
      );

      if (pageImage != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/pdf_page_$i.jpg');
        await tempFile.writeAsBytes(pageImage.bytes);

        final String pageText = await recognizeImage(tempFile.path);
        fullText += "--- Trang $i ---\n$pageText\n\n";

        // Clean up
        await tempFile.delete();
      }
      await page.close();
    }
    await document.close();
    return fullText;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
