import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../screens/classroom/classroom_gate_screen.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/student/student_disputes_screen.dart';
import '../screens/student/student_ise_screen.dart';
import '../services/auth_service.dart';
import 'sidebar_nav_item.dart';
import 'sidebar_profile_header.dart';

class StudentSidebarDrawer extends StatelessWidget {
  const StudentSidebarDrawer({
    super.key,
    this.user,
    this.fallbackPnr,
  });

  final AppUser? user;
  final String? fallbackPnr;

  void _goToDashboardTab(BuildContext context, int index) {
    Navigator.pop(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => StudentDashboard(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user ?? context.watch<AuthService>().currentUser;
    final pnr = currentUser?.pnr ?? fallbackPnr ?? '';
    final displayName = currentUser?.name ?? 'Student';

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SidebarProfileHeader(
                pnr: pnr,
                displayName: displayName,
                subtitle: 'Student',
                staticAvatarAssetPath: 'assets/icons/student.png',
                staticAvatarRect: true,
                disableBackgroundImage: true,
              ),
            ),
            const SizedBox(height: 10),
            SidebarNavItem(
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              selected: false,
              onTap: () => _goToDashboardTab(context, 0),
            ),
            SidebarNavItem(
              label: 'Attendance',
              icon: Icons.analytics_outlined,
              selected: false,
              onTap: () => _goToDashboardTab(context, 1),
            ),
            SidebarNavItem(
              label: 'Timetable',
              icon: Icons.table_chart_outlined,
              selected: false,
              onTap: () => _goToDashboardTab(context, 3),
            ),
            SidebarNavItem(
              label: 'ISE',
              icon: Icons.grading_outlined,
              selected: false,
              onTap: () {
                Navigator.pop(context);
                if (pnr.trim().isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentIseScreen(studentPnr: pnr),
                  ),
                );
              },
            ),
            SidebarNavItem(
              label: 'Disputes',
              icon: Icons.report_problem_outlined,
              selected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentDisputesScreen()),
                );
              },
            ),
            SidebarNavItem(
              label: 'Go To Classroom',
              icon: Icons.meeting_room_outlined,
              selected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClassroomGateScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            SidebarNavItem(
              label: 'Logout',
              icon: Icons.logout,
              selected: false,
              onTap: () {
                Navigator.pop(context);
                context.read<AuthService>().logout();
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

