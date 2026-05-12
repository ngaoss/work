import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications_windows/flutter_local_notifications_windows.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationHelper {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Function(String?)? _onNotificationTapped;
  static set onNotificationTapped(Function(String?) callback) =>
      _onNotificationTapped = callback;

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
      macOS: initializationSettingsIOS,
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      windows: WindowsInitializationSettings(
        appUserModelId: 'com.deepcode.work',
        guid: '3B82F6A1-9C1A-4A1B-8B9C-AD440487A968',
        appName: 'DeepCode Work',
      ),
    );

    try {
      final bool? initialized = await _notificationsPlugin.initialize(
        settings: mySettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification tapped with payload: ${response.payload}");
          _onNotificationTapped?.call(response.payload);
        },
      );
      _isInitialized = initialized ?? false;
      // debugPrint("Notifications initialized for Windows: $_isInitialized");
    } catch (e) {
      _isInitialized = false;
      debugPrint("Error initializing notifications: $e");
    }
  }

  static bool _isInitialized = false;

  static Future<void> requestPermissions() async {
    if (!_isInitialized) {
      debugPrint(
        "Notification plugin not initialized, attempting to initialize...",
      );
      await initialize();
    }

    if (!_isInitialized) return;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.notification.request();
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
      }
    } catch (e) {
      debugPrint("Error requesting permissions: $e");
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

  // Multi-sound management
  static Future<List<Map<String, String>>> getAvailableSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final String? soundsJson = prefs.getString('notification_sounds_list');
    if (soundsJson == null) {
      return [
        {'name': 'Mặc định', 'path': 'default'},
      ];
    }
    final List<dynamic> decoded = json.decode(soundsJson);
    return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  static Future<void> addSound(String name, String path) async {
    final List<Map<String, String>> sounds = await getAvailableSounds();
    sounds.add({'name': name, 'path': path});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sounds_list', json.encode(sounds));
  }

  static Future<void> setActiveSound(String name, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_notification_sound_name', name);
    await prefs.setString('active_notification_sound_path', path);
  }

  static Future<Map<String, String>> getActiveSound() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('active_notification_sound_name') ?? 'Mặc định',
      'path': prefs.getString('active_notification_sound_path') ?? 'default',
    };
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

    if (Platform.isWindows) {
      try {
        final activeSound = await getActiveSound();
        final String? customSoundPath = activeSound['path'];

        await _audioPlayer.setVolume(1.0); // Set max volume

        if (customSoundPath != null &&
            customSoundPath != 'default' &&
            File(customSoundPath).existsSync()) {
          // Play custom sound from local file
          await _audioPlayer.play(DeviceFileSource(customSoundPath));
        } else {
          // Fallback to default asset sound
          await _audioPlayer.play(AssetSource('notification_sound.mp3'));
        }
      } catch (e) {
        debugPrint("Error playing notification sound on Windows: $e");
      }
    }

    String? largeIconPath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveFile(
        imageUrl,
        'notification_icon_$id',
      );
    }

    final BigTextStyleInformation bigTextStyleInformation =
        BigTextStyleInformation(
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
          playSound: true,
          styleInformation: bigTextStyleInformation,
          largeIcon: largeIconPath != null
              ? FilePathAndroidBitmap(largeIconPath)
              : null,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      linux: const LinuxNotificationDetails(defaultActionName: 'Open'),
      windows: WindowsNotificationDetails(
        audio: WindowsNotificationAudio.silent(),
      ),
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Error showing notification: $e");
    }
  }

  static Future<String?> _downloadAndSaveFile(
    String url,
    String fileName,
  ) async {
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
