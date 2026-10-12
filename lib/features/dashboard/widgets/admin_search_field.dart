import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController controller;

  const AdminSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AdminColors.cardBottom,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.borderGlow.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AdminColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: AdminColors.textAccent,
              onChanged: onChanged,
              style: const TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 16,
              ),
              textInputAction: TextInputAction.search,
              maxLines: 1,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: hintText,
                hintStyle: const TextStyle(color: AdminColors.textSecondary),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(
                            Icons.close,
                            color: AdminColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
