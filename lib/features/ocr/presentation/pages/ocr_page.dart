import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:work/features/ocr/services/ocr_service.dart';
import 'package:work/core/utils/image_editor_helper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class OCRPage extends StatefulWidget {
  const OCRPage({super.key});

  @override
  State<OCRPage> createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  final OCRService _ocrService = OCRService();
  final ImagePicker _picker = ImagePicker();
  String _extractedText = "";
  bool _isProcessing = false;
  String? _selectedFileName;
  Uint8List? _previewImageBytes;

  @override
  void initState() {
    super.initState();
    // Initialize OCR Service is already done in field
  }

  @override
  void dispose() {
    _ocrService.dispose();
    if (mounted) {
      // We'll initialize controller inside the class but check if it's initialized before dispose
    }
    super.dispose();
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    // --- Khoanh vùng trích xuất (Crop) ---
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    final croppedBytes = await ImageEditorHelper.editImage(
      context,
      bytes,
      cropOnly: true,
    );

    if (croppedBytes == null) return; // User cancelled editing

    setState(() {
      _isProcessing = true;
      _extractedText = "";
      _selectedFileName = image.name;
      _previewImageBytes = croppedBytes;
    });

    try {
      // Save cropped bytes to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(croppedBytes);

      final text = await _ocrService.recognizeImage(tempFile.path);
      setState(() {
        _extractedText = text;
      });

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      _showError("Lỗi nhận diện hình ảnh: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _isProcessing = true;
      _extractedText = "";
      _selectedFileName = result.files.single.name;
    });

    try {
      final text = await _ocrService.recognizePdf(result.files.single.path!);
      setState(() {
        _extractedText = text;
      });
    } catch (e) {
      _showError("Lỗi nhận diện PDF: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _copyToClipboard() {
    if (_extractedText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _extractedText));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Đã sao chép vào bộ nhớ tạm")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "OCR - NHẬN DIỆN VĂN BẢN",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        children: [
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: "Máy ảnh",
                  onTap: () => _processImage(ImageSource.camera),
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  icon: Icons.photo_library_outlined,
                  label: "Thư viện",
                  onTap: () => _processImage(ImageSource.gallery),
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: "Tài liệu PDF",
                  onTap: _processPdf,
                  color: const Color(0xFFEF4444),
                ),
              ],
            ),
          ),

          if (_selectedFileName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Đang xử lý: $_selectedFileName",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_previewImageBytes != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Image.memory(
                              _previewImageBytes!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                            if (_isProcessing) const _ScanningAnimationWidget(),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: _isProcessing
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  "Đang trích xuất văn bản...",
                                  style: TextStyle(
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "KẾT QUẢ TRÍCH XUẤT",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.blueGrey,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  if (_extractedText.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy_all,
                                        size: 20,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      onPressed: _copyToClipboard,
                                      tooltip: "Sao chép",
                                    ),
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: _extractedText.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.text_fields_outlined,
                                              size: 48,
                                              color: Colors.grey.shade200,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              "Chọn hình ảnh hoặc PDF để bắt đầu",
                                              style: TextStyle(
                                                color: Colors.grey.shade400,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        child: SelectableText(
                                          _extractedText,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.6,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanningAnimationWidget extends StatefulWidget {
  const _ScanningAnimationWidget({super.key});

  @override
  State<_ScanningAnimationWidget> createState() =>
      _ScanningAnimationWidgetState();
}

class _ScanningAnimationWidgetState extends State<_ScanningAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: _animation.value * 200,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFF3B82F6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
