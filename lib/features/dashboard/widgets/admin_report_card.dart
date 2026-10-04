import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

enum AdminReportSeverity { amber, red }

const _redFlagReasons = {
  'Made me uncomfortable',
  'Not appropriate for school',
};

AdminReportSeverity severityForReportReason(String reason) {
  return _redFlagReasons.contains(reason) ? AdminReportSeverity.red : AdminReportSeverity.amber;
}

class AdminReportCard extends StatelessWidget {
  final String title;
  final String detail;
  final AdminReportSeverity severity;
  final VoidCallback onResolve;

  const AdminReportCard({
    super.key,
    required this.title,
    required this.detail,
    required this.severity,
    required this.onResolve,
  });

  Color get _severityColor =>
      severity == AdminReportSeverity.red ? AdminColors.severityRed : AdminColors.severityAmber;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.cardBottom,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.flag, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onResolve,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.brandPrimary,
              foregroundColor: AdminColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
