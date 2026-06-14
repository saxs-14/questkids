import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Headings
  static TextStyle h1 = GoogleFonts.nunito(
    fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
  );
  static TextStyle h2 = GoogleFonts.nunito(
    fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle h3 = GoogleFonts.nunito(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle h4 = GoogleFonts.nunito(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );

  // Body
  static TextStyle bodyLarge = GoogleFonts.nunito(
    fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static TextStyle bodyMedium = GoogleFonts.nunito(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
  static TextStyle bodySmall = GoogleFonts.nunito(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );

  // Special
  static TextStyle button = GoogleFonts.nunito(
    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textLight,
  );
  static TextStyle label = GoogleFonts.nunito(
    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );
  static TextStyle points = GoogleFonts.nunito(
    fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold,
  );
  static TextStyle score = GoogleFonts.nunito(
    fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.primary,
  );
}
