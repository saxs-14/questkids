import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  const AdminSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AdminColors.textAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(color: AdminColors.textSecondary, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

class AdminStatusPill extends StatelessWidget {
  final String label;

  const AdminStatusPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.statusOnline.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.statusOnline.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AdminColors.statusOnline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.statusOnline,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
