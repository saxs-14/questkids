import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminColors.cardTop, AdminColors.cardBottom],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.borderGlow.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AdminColors.textAccent),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AdminColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.textAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
