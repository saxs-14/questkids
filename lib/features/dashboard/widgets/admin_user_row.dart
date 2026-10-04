import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

enum AdminRole { admin, parent, learner }

AdminRole adminRoleFromString(String role) {
  switch (role) {
    case 'admin':
      return AdminRole.admin;
    case 'parent':
      return AdminRole.parent;
    default:
      return AdminRole.learner;
  }
}

class AdminUserRow extends StatelessWidget {
  final String name;
  final String email;
  final AdminRole role;
  final Widget trailing;

  const AdminUserRow({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.trailing,
  });

  Color get _roleColor {
    switch (role) {
      case AdminRole.admin:
        return AdminColors.roleAdmin;
      case AdminRole.parent:
        return AdminColors.roleParent;
      case AdminRole.learner:
        return AdminColors.roleLearner;
    }
  }

  String get _roleLabel {
    switch (role) {
      case AdminRole.admin:
        return 'admin';
      case AdminRole.parent:
        return 'parent';
      case AdminRole.learner:
        return 'learner';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.cardBottom,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.borderGlow.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminColors.brandPrimary,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _roleLabel,
              style: TextStyle(color: roleColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
