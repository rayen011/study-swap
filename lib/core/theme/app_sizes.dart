import 'package:flutter/material.dart';

/// AppSizes: Contains all the constant spacing and sizing used in the app.
/// This prevents hardcoding pixel values and makes the layout consistent.
class AppSizes {
  AppSizes._();

  // Padding & Margin Constants
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Reusable Sized Boxes for Spacing
  static const SizedBox gapHSm = SizedBox(height: sm);
  static const SizedBox gapHMD = SizedBox(height: md);
  static const SizedBox gapHLG = SizedBox(height: lg);
  static const SizedBox gapHXL = SizedBox(height: xl);
  static const SizedBox gapHXXL = SizedBox(height: xxl);

  static const SizedBox gapWSm = SizedBox(width: sm);
  static const SizedBox gapWMD = SizedBox(width: md);
  static const SizedBox gapWLG = SizedBox(width: lg);
}
