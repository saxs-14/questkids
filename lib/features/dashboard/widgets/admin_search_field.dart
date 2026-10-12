import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminSearchField extends StatefulWidget {
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
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AdminSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

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
              controller: widget.controller,
              cursorColor: AdminColors.textAccent,
              onChanged: widget.onChanged,
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
                hintText: widget.hintText,
                hintStyle: const TextStyle(color: AdminColors.textSecondary),
                suffixIcon: widget.controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(
                          Icons.close,
                          color: AdminColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged('');
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
