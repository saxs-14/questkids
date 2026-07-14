import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Type pairing for the premium-2D redesign: **Fredoka** (chunky, rounded,
/// game-like) carries display/heading/HUD text where personality matters;
/// **Nunito** (already the app's established rounded body face) stays for
/// running body text, where a display face this bold would hurt
/// legibility at small sizes. Both are Google Fonts, no new dependency.
class AppTextStyles {
  // Headings — no hardcoded color so dark/light theme propagates correctly.
  static TextStyle h1 = GoogleFonts.fredoka(
    fontSize: 32,
    fontWeight: FontWeight.w600,
  );
  static TextStyle h2 = GoogleFonts.fredoka(
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );
  static TextStyle h3 = GoogleFonts.fredoka(
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );
  static TextStyle h4 = GoogleFonts.fredoka(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  // Body — no hardcoded color on primary body text.
  static TextStyle bodyLarge = GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  static TextStyle bodyMedium = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  // Secondary/helper text: grey on both themes is intentional.
  static TextStyle bodySmall = GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Special — explicit colors are intentional here.
  static TextStyle button = GoogleFonts.fredoka(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
  );
  static TextStyle label = GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );
  static TextStyle points = GoogleFonts.fredoka(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
  );
  static TextStyle score = GoogleFonts.fredoka(
    fontSize: 48,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  /// HUD-style number display (Gold pill, streak counter, timers) —
  /// Fredoka reads as a chunky "game counter" digit face at small sizes.
  static TextStyle hudNumber = GoogleFonts.fredoka(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}
