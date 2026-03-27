import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String? imagePath;
  final String? imageUrl;

  const FullScreenImageViewer({super.key, this.imagePath, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imagePath ?? imageUrl ?? 'image',
            child: imagePath != null
                ? Image.file(File(imagePath!), fit: BoxFit.contain)
                : imageUrl != null
                ? Image.network(imageUrl!, fit: BoxFit.contain)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
