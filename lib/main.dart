import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/chat/presentation/pages/chat_shell.dart';

import 'core/security.dart';

void main() {
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
          home: isAuthenticated
              ? const ChatShell()
              : LoginScreen(
                  onLogin: () =>
                      AuthService().login("user@deepcode.vn", "123456"),
                ),
        );
      },
    );
  }
}
