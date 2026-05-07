import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme.dart';
import 'core/utils/notification_helper.dart';
import 'core/utils/tray_helper.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/chat/presentation/pages/chat_shell.dart';
import 'core/security.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager for Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    // Prevent default close behavior
    await windowManager.setPreventClose(true);
  }

  // Configure Startup for Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName.isNotEmpty
          ? packageInfo.appName
          : "DeepCode Work",
      appPath: Platform.resolvedExecutable,
    );
    await launchAtStartup.enable();
  }

  // Initialize notifications (non-blocking)
  NotificationHelper.initialize();

  // Handle notification tap to show window on Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    NotificationHelper.onNotificationTapped = () async {
      await windowManager.show();
      await windowManager.restore();
      await windowManager.focus();
    };
  }

  final authService = AuthService();
  await authService.checkSession();
  runApp(const ProviderScope(child: DeepCodeApp()));
}

class DeepCodeApp extends StatefulWidget {
  const DeepCodeApp({super.key});

  @override
  State<DeepCodeApp> createState() => _DeepCodeAppState();
}

class _DeepCodeAppState extends State<DeepCodeApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    // debugPrint('Tray: _initTray called');
    await TrayHelper.initialize(() async {
      debugPrint('Tray: Show callback triggered');
      await windowManager.show();
      await windowManager.restore();
      await windowManager.focus();
    });
    // debugPrint('Tray: _initTray done');
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService().isAuthenticated,
      builder: (context, isAuthenticated, child) {
        return MaterialApp(
          title: 'DeepCode Work',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: isAuthenticated ? const ChatShell() : const LoginScreen(),
        );
      },
    );
  }
}
