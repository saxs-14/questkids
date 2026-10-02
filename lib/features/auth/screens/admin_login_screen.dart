import 'package:flutter/material.dart';

import '../../dashboard/screens/demo_admin_dashboard.dart';

/// Temporary presentation admin entry.
///
/// The current QuestKids deployment uses the read-only demo administrator
/// console so the Admin Portal can be opened without an email/password.
/// Firebase administrator authentication remains separate and is not bypassed.
class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoAdminDashboard();
  }
}
