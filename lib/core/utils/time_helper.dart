import 'package:intl/intl.dart';

String formatTime(dynamic timestamp) {
  if (timestamp == null || timestamp.toString().isEmpty) return 'Vừa xong';

  try {
    final DateTime dt = (timestamp is DateTime)
        ? timestamp
        : DateTime.parse(timestamp.toString()).toLocal();
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(dt);

    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} h trước';
    } else if (diff.inDays <= 30) {
      return '${diff.inDays} ngày trước';
    } else {
      // > 30 days: dd - mm - yyyy HH:mm
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    }
  } catch (e) {
    return timestamp.toString();
  }
}
