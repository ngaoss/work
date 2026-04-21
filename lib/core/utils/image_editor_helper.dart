import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class ImageEditorHelper {
  static Future<Uint8List?> editImage(
    BuildContext context,
    Uint8List imageBytes, {
    bool cropOnly = false,
  }) async {
    return await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.memory(
          imageBytes,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              Navigator.pop(context, bytes);
            },
          ),
          configs: ProImageEditorConfigs(
            i18n: const I18n(
              done: 'Xong',
              cancel: 'Hủy',
              undo: 'Hoàn tác',
              redo: 'Làm lại',
            ),
            // Note: You can customize tools here if the version of pro_image_editor supports it
          ),
        ),
      ),
    );
  }
}
