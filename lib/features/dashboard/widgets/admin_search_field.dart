import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const AdminSearchField({super.key, required this.hintText, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AdminColors.cardBottom,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.borderGlow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AdminColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: AdminColors.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: hintText,
                hintStyle: const TextStyle(color: AdminColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
