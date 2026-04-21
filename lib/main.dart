import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'core/theme.dart';
import 'core/utils/notification_helper.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/chat/presentation/pages/chat_shell.dart';
import 'core/security.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Startup for Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
    );
    await launchAtStartup.enable();
  }
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  // Initialize notifications (non-blocking)
  NotificationHelper.initialize();

  final authService = AuthService();
  await authService.checkSession();
  runApp(const ProviderScope(child: DeepCodeApp()));
}

class DeepCodeApp extends StatelessWidget {
  const DeepCodeApp({super.key});

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
