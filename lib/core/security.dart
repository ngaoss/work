import 'package:flutter/material.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<String?> authToken = ValueNotifier<String?>(null);

  Future<void> login(String email, String password) async {
    // Mock secure login with artificial delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Simulate encryption/token generation
    final mockToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.${email.hashCode}";

    authToken.value = mockToken;
    isAuthenticated.value = true;

    debugPrint("Security: Session established for $email (Token: $mockToken)");
  }

  void logout() {
    authToken.value = null;
    isAuthenticated.value = false;
    debugPrint("Security: Session cleared.");
  }
}
