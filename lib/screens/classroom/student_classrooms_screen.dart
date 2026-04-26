import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/classroom_models.dart';
import '../../models/user_model.dart';
import '../../services/classroom_auth_service.dart';
import '../../services/classroom_service.dart';
import '../../utils/role_home_navigation.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/student_sidebar_drawer.dart';
import 'student_room_detail_screen.dart';

class StudentClassroomsScreen extends StatelessWidget {
  final AppUser user;
  const StudentClassroomsScreen({super.key, required this.user});

  Color _roomColor(String roomId, int index) {
    final colors = <Color>[
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF00897B), // Teal
      const Color(0xFF43A047), // Green
      const Color(0xFFF4511E), // Deep orange
      const Color(0xFF6D4C41), // Brown
      const Color(0xFF8E24AA), // Purple
      const Color(0xFF3949AB), // Indigo
      const Color(0xFF546E7A), // Blue grey
      const Color(0xFFC2185B), // Pink
      const Color(0xFF7CB342), // Light green
    ];

    final idx = (roomId.hashCode.abs() + index) % colors.length;
    return colors[idx];
  }

  Future<void> _join(BuildContext context) async {
    final service = context.read<ClassroomService>();
    final messenger = ScaffoldMessenger.of(context);

    final codeController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join classroom'),
        content: TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Class code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final code = codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Code is required')),
      );
      return;
    }

    try {
      await service.joinClassroomByCode(
            code: code,
            student: user,
          );
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Joined classroom'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        goToStudentDashboardHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const AppMenuButton(),
          title: const Text('Classrooms'),
          actions: [
            IconButton(
              tooltip: 'Join classroom',
              icon: const Icon(Icons.group_add_outlined),
              onPressed: () => _join(context),
            ),
            IconButton(
              tooltip: 'Google sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final auth = context.read<ClassroomAuthService>();
                await auth.signOut();
                if (!context.mounted) return;
                goToStudentDashboardHome(context);
              },
            ),
          ],
        ),
        drawer: StudentSidebarDrawer(user: user, fallbackPnr: user.pnr),
        body: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: context.read<ClassroomService>().watchMyMemberships(user.pnr),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final memberships = snapshot.data ?? const <Map<String, dynamic>>[];
            if (memberships.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No joined classrooms.\nTap "Join" and enter your class code.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: memberships.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (context, index) {
                final classroomId =
                    memberships[index]['classroomId']?.toString() ??
                        memberships[index]['id']?.toString() ??
                        '';
                if (classroomId.isEmpty) {
                  return const SizedBox.shrink();
                }

                return StreamBuilder<ClassroomRoom?>(
                  stream: context
                      .read<ClassroomService>()
                      .watchClassroom(classroomId),
                  builder: (context, roomSnap) {
                    final room = roomSnap.data;
                    if (room == null || room.isDeleted) {
                      return const SizedBox.shrink();
                    }

                    final cardColor = _roomColor(room.id, index);
                    final onBg = ThemeData.estimateBrightnessForColor(
                                cardColor) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black87;
                    final onBgMuted = onBg.withValues(alpha: 0.80);
                    final barColor = onBg.withValues(alpha: 0.18);

                    return Material(
                      color: cardColor,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.18),
                      clipBehavior: Clip.hardEdge,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentRoomDetailScreen(
                                student: user,
                                room: room,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: onBg,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ClassroomInfoRow(
                                label: 'Code',
                                value: room.code,
                                color: onBgMuted,
                              ),
                              const SizedBox(height: 8),
                              _ClassroomInfoRow(
                                label: 'Department',
                                value: room.department,
                                color: onBgMuted,
                              ),
                              const SizedBox(height: 8),
                              _ClassroomInfoRow(
                                label: 'Year',
                                value: room.year.toString(),
                                color: onBgMuted,
                              ),
                              const SizedBox(height: 8),
                              _ClassroomInfoRow(
                                label: 'Class',
                                value: '${room.department}-${room.year}${room.division}',
                                color: onBgMuted,
                              ),
                              const SizedBox(height: 8),
                              _ClassroomInfoRow(
                                label: 'Division',
                                value: room.division,
                                color: onBgMuted,
                              ),
                              const SizedBox(height: 8),
                              _ClassroomInfoRow(
                                label: 'Faculty',
                                value: room.createdByName,
                                color: onBgMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
          ),
        ),
      ),
    );
  }
}

class _ClassroomInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ClassroomInfoRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
