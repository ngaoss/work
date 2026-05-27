import 'package:flutter/material.dart';

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
      fontFamily: 'Segoe UI',
      fontFamilyFallback: const ['Segoe UI Historic', 'Helvetica', 'Arial', 'sans-serif'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        surface: backgroundWhite,
        onSurface: textBlack,
      ),
      scaffoldBackgroundColor: backgroundWhite,
      textTheme: const TextTheme(
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
      ).apply(
        fontFamily: 'Segoe UI',
        fontFamilyFallback: const ['Segoe UI Historic', 'Helvetica', 'Arial', 'sans-serif'],
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

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      fontFamilyFallback: const ['Segoe UI Historic', 'Helvetica', 'Arial', 'sans-serif'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: primaryBlue,
        surface: const Color(0xFF252728),
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF18191A),
      textTheme: ThemeData.dark().textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 28,
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 22,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 18,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: Colors.white),
        bodyMedium: const TextStyle(fontSize: 14, color: Colors.grey),
      ).apply(
        fontFamily: 'Segoe UI',
        fontFamilyFallback: const ['Segoe UI Historic', 'Helvetica', 'Arial', 'sans-serif'],
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
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
