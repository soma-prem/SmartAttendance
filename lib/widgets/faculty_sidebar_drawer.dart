import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../screens/classroom/classroom_gate_screen.dart';
import '../screens/faculty/faculty_dashboard.dart';
import '../screens/faculty/faculty_ise_screen.dart';
import '../screens/faculty/faculty_send_notification_screen.dart';
import '../services/auth_service.dart';
import 'sidebar_nav_item.dart';
import 'sidebar_profile_header.dart';

class FacultySidebarDrawer extends StatelessWidget {
  const FacultySidebarDrawer({
    super.key,
    this.user,
    this.fallbackPnr,
    this.fallbackName,
  });

  final AppUser? user;
  final String? fallbackPnr;
  final String? fallbackName;

  void _goToDashboardTab(BuildContext context, int index) {
    Navigator.pop(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => FacultyDashboard(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user ?? context.watch<AuthService>().currentUser;
    final pnr = currentUser?.pnr ?? fallbackPnr ?? '';
    final displayName = currentUser?.name ?? fallbackName ?? 'Faculty';
    final subject = currentUser?.subject?.trim();
    final subtitle = (subject != null && subject.isNotEmpty) ? subject : 'Faculty';

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
                subtitle: subtitle,
                staticAvatarAssetPath: 'assets/icons/faculty.png',
                staticAvatarRect: true,
                disableBackgroundImage: true,
              ),
            ),
            const SizedBox(height: 10),
            SidebarNavItem(
              label: 'Schedule',
              icon: Icons.schedule_outlined,
              selected: false,
              onTap: () => _goToDashboardTab(context, 0),
            ),
            SidebarNavItem(
              label: 'Attendance',
              icon: Icons.fact_check_outlined,
              selected: false,
              onTap: () => _goToDashboardTab(context, 1),
            ),
            SidebarNavItem(
              label: 'Attendance History',
              icon: Icons.history,
              selected: false,
              onTap: () => _goToDashboardTab(context, 2),
            ),
            SidebarNavItem(
              label: 'Disputes',
              icon: Icons.report_problem_outlined,
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
                    builder: (_) => FacultyIseScreen(
                      facultyPnr: pnr,
                      facultyName: displayName,
                    ),
                  ),
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
            SidebarNavItem(
              label: 'Send Notification',
              icon: Icons.notifications_outlined,
              selected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FacultySendNotificationScreen(
                      facultyPnr: pnr,
                    ),
                  ),
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

