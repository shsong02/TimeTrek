import 'package:flutter/material.dart';

class TimeTrekTheme {
  static ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.blue,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.white,
      background: Colors.grey[100]!,
      error: Colors.red,
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(
        color: Colors.black87,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: TextStyle(
        color: Colors.black87,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      labelMedium: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
      ),
      labelLarge: TextStyle(
        color: Colors.grey[700],
        fontSize: 16,
      ),
      bodyLarge: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Colors.black87,
        fontSize: 14,
      ),
      titleSmall: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        color: Colors.black87,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    primarySwatch: Colors.blue,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850],
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    colorScheme: ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.grey[850]!,
      background: Colors.grey[800]!,
      error: Colors.red,
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      labelMedium: TextStyle(
        color: Colors.grey[400],
        fontSize: 14,
      ),
      labelLarge: TextStyle(
        color: Colors.grey[300],
        fontSize: 16,
      ),
      bodyLarge: TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      titleSmall: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
} 