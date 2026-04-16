import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/chat/presentation/pages/chat_shell.dart';
import 'core/security.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  
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
