import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../features/dashboard/screens/learner_dashboard.dart';
import '../../features/dashboard/screens/parent_dashboard.dart';
import '../../features/dashboard/screens/teacher_dashboard.dart';

class NavigationService {
  static Widget getDashboard(UserModel user) {
    switch (user.role) {
      case 'parent':
        return const ParentDashboard();
      case 'teacher':
        return const TeacherDashboard();
      default:
        return const LearnerDashboard();
    }
  }
}
