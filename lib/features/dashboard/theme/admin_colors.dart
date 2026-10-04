import 'package:flutter/material.dart';

/// Dark "Premium Dark" command-center palette, scoped to the admin
/// dashboard only (does not affect Learner/Parent/Teacher theming).
/// Matches the Figma file "QuestKids Admin Console"
/// (z1g8doKhAyTdO2M5XjRW3V), variable collection "Admin Console Colors".
class AdminColors {
  static const Color bgPage = Color(0xFF0F0D18);
  static const Color cardTop = Color(0xFF211C33);
  static const Color cardBottom = Color(0xFF191625);
  static const Color borderGlow = Color(0xFF8C6EFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textAccent = Color(0xFFB7A6FF);
  static const Color textSecondary = Color(0xFF9B93B5);
  static const Color brandPrimary = Color(0xFF5C35F5);
  static const Color statusOnline = Color(0xFF4ADE80);

  // Safety-report severity accents (not in the Figma variable collection —
  // added for the Safety tab's severity-colored cards).
  static const Color severityAmber = Color(0xFFFABF24);
  static const Color severityRed = Color(0xFFF04545);

  // Role badge accents (Users tab) — admin reuses the existing accent
  // purple; parent/learner are new, chosen to stay legible at low opacity
  // on the dark background.
  static const Color roleAdmin = Color(0xFFB7A6FF);
  static const Color roleParent = Color(0xFF60A5FA);
  static const Color roleLearner = Color(0xFF4ADE80);
}
