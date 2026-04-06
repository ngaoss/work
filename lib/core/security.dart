import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<String?> authToken = ValueNotifier<String?>(null);
  final ValueNotifier<Map<String, dynamic>?> userProfile =
      ValueNotifier<Map<String, dynamic>?>(null);

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final profileStr = prefs.getString('user_profile');

    if (token != null) {
      authToken.value = token;
      isAuthenticated.value = true;
      if (profileStr != null) {
        userProfile.value = jsonDecode(profileStr);
      }
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://work.deepcode.vn/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        debugPrint("Login success body: ${response.body}");
        final Map<String, dynamic> rawData = jsonDecode(response.body);
        final Map<String, dynamic> data =
            (rawData.containsKey('data') && rawData['data'] is Map)
            ? rawData['data']
            : rawData;

        final token =
            data['token'] ??
            data['access_token'] ??
            rawData['token'] ??
            rawData['access_token'] ??
            'authenticated_session';
        final user =
            data['user'] ??
            rawData['user'] ??
            (rawData.containsKey('data') && rawData['data'] is Map
                ? rawData['data']
                : null);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token.toString());
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);

        if (user != null && user is Map) {
          await prefs.setString('user_profile', jsonEncode(user));
          userProfile.value = user as Map<String, dynamic>;
        }

        authToken.value = token.toString();
        isAuthenticated.value = true;
        return true;
      } else {
        debugPrint("Login failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Login error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_profile');

    authToken.value = null;
    userProfile.value = null;
    isAuthenticated.value = false;
    debugPrint("Security: Session cleared.");
  }

  Future<void> updateLocalProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(data));
    userProfile.value = data;
  }
}
