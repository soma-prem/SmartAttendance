import 'package:flutter/material.dart';

import '../screens/admin/admin_dashboard.dart';
import '../screens/faculty/faculty_dashboard.dart';
import '../screens/student/student_dashboard.dart';

void goToStudentDashboardHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const StudentDashboard(initialIndex: 0)),
    (route) => false,
  );
}

void goToFacultyScheduleHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const FacultyDashboard(initialIndex: 0)),
    (route) => false,
  );
}

void goToAdminFeedbackHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AdminDashboard(initialIndex: 0)),
    (route) => false,
  );
}

void goToRoleHome(BuildContext context, String role) {
  switch (role) {
    case 'faculty':
      goToFacultyScheduleHome(context);
      return;
    case 'admin':
      goToAdminFeedbackHome(context);
      return;
    case 'student':
    default:
      goToStudentDashboardHome(context);
      return;
  }
}

