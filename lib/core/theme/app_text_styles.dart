import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// AppTextStyles: Contains all the text styles used in the application.
/// It uses GoogleFonts to ensure the unique typography is applied consistently.
class AppTextStyles {
  AppTextStyles._();

  // Headings (Using Space Grotesk for that unique modern look)
  static TextStyle heading1 = GoogleFonts.spaceGrotesk(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    height: 1.1,
  );

  static TextStyle heading2 = GoogleFonts.spaceGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    height: 1.2,
  );

  // Body Texts (Using Inter for clean readability)
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textGrey,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textGrey,
    height: 1.5,
  );
  
  static TextStyle bodyMediumDark = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.5,
  );

  // Button Texts
  static TextStyle buttonText = GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );
  
  static TextStyle buttonTextWhite = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
}
