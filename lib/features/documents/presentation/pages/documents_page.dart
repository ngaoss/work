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
              const SizedBox(height: 48),

              // Folder Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _DocFolder(
                    title: "Hướng dẫn nhân sự",
                    color: Colors.amber,
                    count: 12,
                  ),
                  _DocFolder(
                    title: "Dự án NexusWork",
                    color: Colors.blue,
                    count: 45,
                  ),
                  _DocFolder(
                    title: "Chính sách bảo mật",
                    color: Colors.green,
                    count: 5,
                  ),
                  _DocFolder(
                    title: "Tài liệu Kỹ thuật",
                    color: Colors.indigo,
                    count: 28,
                  ),
                ],
              ),
              const SizedBox(height: 48),

              const Text(
                "Tài liệu gần đây",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              _DocItem(title: "Nội quy công ty 2026.pdf", time: "2 giờ trước"),
              _DocItem(title: "Kế hoạch quý 1.docx", time: "Hôm qua"),
              _DocItem(title: "Brand Guidelines.zip", time: "3 ngày trước"),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocFolder extends StatelessWidget {
  final String title;
  final Color color;
  final int count;
  const _DocFolder({
    required this.title,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.folder_rounded, color: color, size: 48),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "${count} tệp",
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DocItem extends StatelessWidget {
  final String title;
  final String time;
  const _DocItem({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: Colors.blueGrey),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}
