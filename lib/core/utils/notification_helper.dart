import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings mySettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      settings: mySettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle when user taps on the notification
      },
    );
  }

  static Future<void> requestPermissions() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  static Future<bool> isMuted(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final mutedList = prefs.getStringList('muted_chats') ?? [];
    return mutedList.contains(chatId);
  }

  static Future<void> setMuted(String chatId, bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    final mutedList = prefs.getStringList('muted_chats') ?? [];
    if (muted) {
      if (!mutedList.contains(chatId)) {
        mutedList.add(chatId);
        await prefs.setStringList('muted_chats', mutedList);
      }
    } else {
      if (mutedList.contains(chatId)) {
        mutedList.remove(chatId);
        await prefs.setStringList('muted_chats', mutedList);
      }
    }
  }

  static Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
    String? imageUrl,
    bool checkMute = false,
  }) async {
    if (checkMute && payload != null) {
      if (await isMuted(payload)) return;
    }

    String? largeIconPath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveFile(imageUrl, 'notification_icon_$id');
    }

    final BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body ?? '',
      contentTitle: title,
      htmlFormatContent: false,
      htmlFormatContentTitle: false,
    );

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      styleInformation: bigTextStyleInformation,
      largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  static Future<String?> _downloadAndSaveFile(String url, String fileName) async {
    try {
      final Directory directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/$fileName';
      final http.Response response = await http.get(Uri.parse(url));
      final File file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (e) {
      return null;
    }
  }
}
