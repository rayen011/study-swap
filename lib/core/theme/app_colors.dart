import 'package:flutter/material.dart';

/// AppColors: Contains all the constant colors used throughout the app.
/// This ensures a consistent color palette and makes it easy to change colors globally.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFF8F8FA);
  static const Color white = Colors.white;
  static const Color cardBackground = Colors.white;

  // Primary Colors
  static const Color primaryBlue = Color(0xFF001FD1); // StudySwap logo blue
  static const Color lightBlueActive = Color(
    0xFFE2E8F0,
  ); // Active tab background
  static const Color limeGreen = Color(
    0xFFCAFF00,
  ); // The "NEXT" and "Get Started" buttons

  // Text Colors
  static const Color textDark = Color(0xFF111111);
  static const Color textGrey = Color(0xFF6B7280);

  // Accents & Borders
  static const Color borderGrey = Color(0xFFD1D5DB);
  static const Color solidBlack = Colors.black;
  static const Color errorRed = Colors.redAccent;
  static const Color primaryYellow = Color(0xFFFFD100); // For stars
}
