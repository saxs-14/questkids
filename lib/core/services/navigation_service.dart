import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';
import '../../features/dashboard/screens/learner_dashboard.dart';
import '../../features/dashboard/screens/parent_dashboard.dart';

class NavigationService {
  static Widget getDashboard(UserModel user) {
    switch (user.role) {
      case 'parent':
        // Every post-auth path (register, login, admin login, splash
        // auto-login) funnels through here, so gating here -- rather than
        // in each of those screens separately -- is what catches a parent
        // who closed the app mid-verification and signs back in later.
        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }
        return const ParentDashboard();
      case 'admin':
        return const AdminDashboard();
      default:
        return const LearnerDashboard();
    }
  }
}
