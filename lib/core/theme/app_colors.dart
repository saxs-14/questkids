import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand — Deep Purple/Indigo
  static const Color primary = Color(0xFF5C35F5);
  static const Color primaryLight = Color(0xFF8B6EFF);
  static const Color primaryDark = Color(0xFF3D1FA8);

  // Gamification / XP
  static const Color gold = Color(0xFFFFD700);
  static const Color goldDark = Color(0xFFF5A623);
  static const Color xpBlue = Color(0xFF29B6F6);
  static const Color coinColor = Color(0xFFFFD700);

  // Subject Colors (rich, gaming-grade)
  static const Color math = Color(0xFFFF6B35); // vivid orange
  static const Color science = Color(0xFF00BFA5); // teal
  static const Color english = Color(0xFFE91E63); // hot pink
  static const Color socialSciences = Color(0xFF43A047); // green
  static const Color technology = Color(0xFF7C4DFF); // vivid purple
  static const Color lifeSkills = Color(0xFFFF9800); // amber

  // Accent
  static const Color accent = Color(0xFFFF4081);
  static const Color orange = Color(0xFFFF6F00);
  static const Color blue = Color(0xFF1565C0);
  static const Color green = Color(0xFF2E7D32);
  static const Color cyan = Color(0xFF00B8D9);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF0F0FF);
  static const Color backgroundDark = Color(0xFF0D0D1A);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1A1A35);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B8A);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFFE8E8FF);

  // Status
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFFAB00);
  static const Color info = Color(0xFF00B0FF);

  // Surface
  static const Color surface = Color(0xFFF5F5FF);

  // Game-specific gradients
  static const List<Color> heroGradient = [
    Color(0xFF5C35F5),
    Color(0xFF9C27B0)
  ];
  static const List<Color> mathGradient = [
    Color(0xFFFF6B35),
    Color(0xFFFF9800)
  ];
  static const List<Color> sciGradient = [Color(0xFF00BFA5), Color(0xFF1DE9B6)];
  static const List<Color> engGradient = [Color(0xFFE91E63), Color(0xFFFF4081)];
  static const List<Color> sscGradient = [Color(0xFF43A047), Color(0xFF66BB6A)];
}
