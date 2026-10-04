import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questkids/features/dashboard/theme/admin_colors.dart';

void main() {
  test('AdminColors tokens match the approved Figma variable collection', () {
    expect(AdminColors.bgPage, const Color(0xFF0F0D18));
    expect(AdminColors.cardTop, const Color(0xFF211C33));
    expect(AdminColors.cardBottom, const Color(0xFF191625));
    expect(AdminColors.borderGlow, const Color(0xFF8C6EFF));
    expect(AdminColors.textPrimary, const Color(0xFFFFFFFF));
    expect(AdminColors.textAccent, const Color(0xFFB7A6FF));
    expect(AdminColors.textSecondary, const Color(0xFF9B93B5));
    expect(AdminColors.brandPrimary, const Color(0xFF5C35F5));
    expect(AdminColors.statusOnline, const Color(0xFF4ADE80));
  });
}
