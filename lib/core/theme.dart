import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryBlue = Color(
    0xFF3B82F6,
  ); // The vibrant blue in screenshots
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color sidebarGray = Color(0xFFF8FAFC);
  static const Color textBlack = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color surfaceGray = Color(0xFFF1F5F9);

  static LinearGradient heroGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6366F1), // Indigo
      Color(0xFF3B82F6), // Blue
    ],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        surface: backgroundWhite,
        onSurface: textBlack,
      ),
      scaffoldBackgroundColor: backgroundWhite,
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: textBlack,
            fontSize: 28,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: textBlack,
            fontSize: 22,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: textBlack,
            fontSize: 18,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: textBlack),
          bodyMedium: TextStyle(fontSize: 14, color: textMuted),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textBlack),
        titleTextStyle: TextStyle(
          color: textBlack,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey,
        selectedIconTheme: IconThemeData(size: 26),
        unselectedIconTheme: IconThemeData(size: 24),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
