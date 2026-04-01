import 'package:flutter/material.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                "TÀI LIỆU",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                "KHO LƯU TRỮ TÀI LIỆU CÔNG TY",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 100),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_outlined,
                      color: Colors.grey.shade300,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Chưa có tài liệu nào trong kho lưu trữ",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
