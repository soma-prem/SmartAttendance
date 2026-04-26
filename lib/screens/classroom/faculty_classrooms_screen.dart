import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/classroom_models.dart';
import '../../models/user_model.dart';
import '../../services/classroom_auth_service.dart';
import '../../services/classroom_service.dart';
import '../../utils/college_data.dart';
import '../../utils/role_home_navigation.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/faculty_sidebar_drawer.dart';
import 'faculty_room_detail_screen.dart';

class FacultyClassroomsScreen extends StatelessWidget {
  final AppUser user;
  const FacultyClassroomsScreen({super.key, required this.user});

  Color _roomColor(String roomId) {
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

    final idx = roomId.hashCode.abs() % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ClassroomService>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        goToFacultyScheduleHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const AppMenuButton(),
          title: const Text('Classrooms'),
          actions: [
            IconButton(
              tooltip: 'Google sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<ClassroomAuthService>().signOut();
                if (!context.mounted) return;
                goToFacultyScheduleHome(context);
              },
            ),
          ],
        ),
        drawer: FacultySidebarDrawer(
          user: user,
          fallbackPnr: user.pnr,
          fallbackName: user.name,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final authService = context.read<ClassroomAuthService>();
            final created = await showDialog<_CreateClassroomDraft>(
              context: context,
              builder: (_) => _CreateClassroomDialog(faculty: user),
            );
            if (created == null) return;
            final email = authService.currentUser?.email;
            final room = await service.createClassroom(
              title: created.title,
              department: created.department,
              year: created.year,
              division: created.division,
              faculty: user,
              facultyEmail: email,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Created. Code: ${room.code}'),
                  action: SnackBarAction(
                    label: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: room.code));
                    },
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Create'),
        ),
        body: SafeArea(
          child: StreamBuilder<List<ClassroomRoom>>(
            stream: service.watchClassroomsForFaculty(facultyPnr: user.pnr),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final rooms = snapshot.data ?? const <ClassroomRoom>[];
              final visibleRooms = rooms.where((r) => !r.isDeleted).toList();
              if (visibleRooms.isEmpty) {
                return const Center(child: Text('No classrooms yet.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: visibleRooms.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  final room = visibleRooms[index];
                  final cardColor = _roomColor(room.id);
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
                            builder: (_) => FacultyRoomDetailScreen(
                              faculty: user,
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
                            Row(
                              children: [
                                Container(
                                  height: 18,
                                  width: 76,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Copy class code',
                                  icon: Icon(Icons.copy_rounded, color: onBgMuted),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: room.code),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Code copied')),
                                      );
                                    }
                                  },
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Actions',
                                  icon: Icon(Icons.more_vert, color: onBgMuted),
                                  onSelected: (value) async {
                                    if (value != 'delete') return;
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Delete classroom?'),
                                        content: const Text(
                                          'If you delete this class, all announcements/messages and all submitted assignments by students will be deleted.\n\nYou can’t undo this from the app.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await service.softDeleteClassroom(room.id);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              room.title,
                              maxLines: 2,
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
                              value:
                                  '${room.department}-${room.year}${room.division}',
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
            maxLines: 1,
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

class _CreateClassroomDraft {
  final String title;
  final String department;
  final int year;
  final String division;
  const _CreateClassroomDraft({
    required this.title,
    required this.department,
    required this.year,
    required this.division,
  });
}

class _CreateClassroomDialog extends StatefulWidget {
  final AppUser faculty;
  const _CreateClassroomDialog({required this.faculty});

  @override
  State<_CreateClassroomDialog> createState() => _CreateClassroomDialogState();
}

class _CreateClassroomDialogState extends State<_CreateClassroomDialog> {
  final _titleController = TextEditingController();

  String _department = CollegeData.branches.first;
  int _year = CollegeData.years.first;
  String _division = CollegeData.divisionsForYear(CollegeData.years.first).first;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final divisions = CollegeData.divisionsForYear(_year);
    if (!divisions.contains(_division)) {
      _division = divisions.first;
    }

    return AlertDialog(
      title: const Text('Create classroom'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _department,
              decoration: const InputDecoration(
                labelText: 'Dept / Branch',
                border: OutlineInputBorder(),
              ),
              items: CollegeData.branches
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _department = v ?? _department),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
              ),
              items: CollegeData.years
                  .map((y) => DropdownMenuItem(value: y, child: Text('Year $y')))
                  .toList(),
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _division,
              decoration: const InputDecoration(
                labelText: 'Division',
                border: OutlineInputBorder(),
              ),
              items: divisions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _division = v ?? _division),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title is required')),
              );
              return;
            }
            Navigator.pop(
              context,
              _CreateClassroomDraft(
                title: title,
                department: _department,
                year: _year,
                division: _division,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
