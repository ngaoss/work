import 'package:flutter/material.dart';
import '../api_service.dart';

class GlobalErrorWrapper extends StatelessWidget {
  final Widget child;

  const GlobalErrorWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiService.isGlobalServerError,
      builder: (context, isError, _) {
        if (!isError) {
          return child;
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 80,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 24),
                Text(
                  "Đang lỗi kết nối máy chủ",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Vui lòng kiểm tra lại đường truyền\nhoặc thử lại sau ít phút.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
