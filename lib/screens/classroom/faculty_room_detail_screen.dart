import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/classroom_models.dart';
import '../../models/user_model.dart';
import '../../services/classroom_auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/drive_upload_service.dart';
import '../../utils/role_home_navigation.dart';
import 'faculty_submissions_screen.dart';

class FacultyRoomDetailScreen extends StatelessWidget {
  final AppUser faculty;
  final ClassroomRoom room;
  const FacultyRoomDetailScreen({
    super.key,
    required this.faculty,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<ClassroomService>();

    Future<void> showClassMembers() async {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Class Students'),
            content: SizedBox(
              width: double.maxFinite,
              child: StreamBuilder<List<ClassroomMember>>(
                stream: service.watchMembers(room.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final members = snapshot.data ?? const [];
                  if (members.isEmpty) {
                    return const Text('No students found.');
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withAlpha(30),
                          child: Text(
                            member.studentName.isNotEmpty ? member.studentName[0] : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(member.studentName),
                        subtitle: Text(member.studentPnr),
                        trailing: member.rollNo != null ? Text('Roll ${member.rollNo}') : null,
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }

    return DefaultTabController(
      length: 4,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          goToFacultyScheduleHome(context);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => goToFacultyScheduleHome(context),
            ),
            title: Text(room.title),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Assignments'),
                Tab(text: 'Announcements'),
                Tab(text: 'Notes'),
                Tab(text: 'Students'),
              ],
            ),
            actions: [
            IconButton(
              tooltip: 'View students',
              icon: const Icon(Icons.group_outlined),
              onPressed: showClassMembers,
            ),
            IconButton(
              tooltip: 'Copy class code',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: room.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied code: ${room.code}')),
                  );
                }
              },
            ),
          ],
          ),
          floatingActionButton: Builder(
            builder: (context) {
              final tab = DefaultTabController.of(context);
              if (tab.index == 3) return const SizedBox.shrink();
              return FloatingActionButton(
                tooltip: 'Add',
                child: const Icon(Icons.add),
                onPressed: () async {
                  if (tab.index == 0) {
                    final created = await showDialog<_AssignmentDraft>(
                      context: context,
                      builder: (_) => const _CreateAssignmentDialog(),
                    );
                    if (created == null) return;
                    await service.createAssignment(
                      classroomId: room.id,
                      title: created.title,
                      description: created.description,
                      dueAt: created.dueAt,
                      materialFileName: created.materialFileName,
                      materialUrl: created.materialUrl,
                    );
                    return;
                  }

                  if (tab.index == 1) {
                    final draft = await showDialog<_AnnouncementDraft>(
                      context: context,
                      builder: (_) => const _CreateAnnouncementDialog(),
                    );
                    if (draft == null) return;
                    await service.createAnnouncement(
                      classroomId: room.id,
                      title: draft.title,
                      message: draft.message,
                      createdBy: faculty,
                    );
                    return;
                  }

                  if (tab.index == 2) {
                    final draft = await showDialog<_NoteDraft>(
                      context: context,
                      builder: (_) => const _CreateNoteDialog(),
                    );
                    if (draft == null) return;
                    await service.createNote(
                      classroomId: room.id,
                      title: draft.title,
                      content: draft.content,
                      createdBy: faculty,
                      fileName: draft.fileName,
                      fileUrl: draft.fileUrl,
                    );
                    return;
                  }
                },
              );
          },
        ),
        body: TabBarView(
          children: [
            _FacultyAssignmentsTab(room: room),
            _FacultyAnnouncementsTab(room: room),
            _FacultyNotesTab(room: room),
            _FacultyStudentsTab(room: room),
          ],
        ),
      ),
      ),
    );
  }
}

class _FacultyAssignmentsTab extends StatelessWidget {
  final ClassroomRoom room;
  const _FacultyAssignmentsTab({required this.room});

  Future<void> _delete(
    BuildContext context,
    ClassroomService service,
    ClassroomAssignment assignment,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete assignment?'),
        content: const Text(
          'This will delete the assignment and all student submissions for it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await service.deleteAssignment(
      classroomId: room.id,
      assignmentId: assignment.id,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ClassroomService>();
    return StreamBuilder<List<ClassroomAssignment>>(
      stream: service.watchAssignments(room.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? const <ClassroomAssignment>[];
        if (items.isEmpty) {
          return const Center(child: Text('No assignments yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final a = items[index];
            final due = a.dueAt == null
                ? null
                : DateFormat('MMM d, hh:mm a').format(a.dueAt!);
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                title: Text(a.title),
                subtitle: Text(
                  [
                    due == null ? 'No due date' : 'Due: $due',
                    if ((a.materialUrl ?? '').trim().isNotEmpty)
                      'Material: ${a.materialFileName ?? 'File'}',
                  ].join('\n'),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'open' &&
                        (a.materialUrl ?? '').trim().isNotEmpty) {
                      final uri = Uri.tryParse(a.materialUrl!.trim());
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                      return;
                    }
                    if (v == 'delete') {
                      await _delete(context, service, a);
                    }
                  },
                  itemBuilder: (_) => [
                    if ((a.materialUrl ?? '').trim().isNotEmpty)
                      const PopupMenuItem(
                        value: 'open',
                        child: Text('Open material'),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FacultySubmissionsScreen(
                        room: room,
                        assignment: a,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _FacultyAnnouncementsTab extends StatelessWidget {
  final ClassroomRoom room;
  const _FacultyAnnouncementsTab({required this.room});

  Future<void> _delete(
    BuildContext context,
    ClassroomService service,
    ClassroomAnnouncement announcement,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: const Text('This will remove the announcement from the class.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await service.deleteAnnouncement(
      classroomId: room.id,
      announcementId: announcement.id,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ClassroomService>();
    return StreamBuilder<List<ClassroomAnnouncement>>(
      stream: service.watchAnnouncements(room.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? const <ClassroomAnnouncement>[];
        if (items.isEmpty) {
          return const Center(child: Text('No announcements yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final a = items[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                title: Text(a.title),
                subtitle: Text(a.message),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await _delete(context, service, a);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FacultyStudentsTab extends StatelessWidget {
  final ClassroomRoom room;
  const _FacultyStudentsTab({required this.room});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ClassroomService>();
    return StreamBuilder<List<ClassroomMember>>(
      stream: service.watchMembers(room.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final members = snapshot.data ?? const <ClassroomMember>[];
        if (members.isEmpty) {
          return const Center(child: Text('No students joined yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Joined: ${members.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }

            final m = members[index - 1];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    (m.rollNo ?? '').trim().isEmpty ? '#' : (m.rollNo ?? '#'),
                  ),
                ),
                title: Text(m.studentName),
                subtitle: Text('PNR: ${m.studentPnr}'),
                trailing: Text(
                  (m.rollNo ?? '').trim().isEmpty ? '' : 'Roll: ${m.rollNo}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FacultyNotesTab extends StatelessWidget {
  final ClassroomRoom room;
  const _FacultyNotesTab({required this.room});

  Future<void> _delete(
    BuildContext context,
    ClassroomService service,
    ClassroomNote note,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This will remove the note from the class.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await service.deleteNote(classroomId: room.id, noteId: note.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ClassroomService>();
    return StreamBuilder<List<ClassroomNote>>(
      stream: service.watchNotes(room.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? const <ClassroomNote>[];
        if (items.isEmpty) {
          return const Center(child: Text('No notes yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final n = items[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                title: Text(n.title),
                subtitle: Text(
                  [
                    n.content,
                    if ((n.fileUrl ?? '').trim().isNotEmpty)
                      'Attachment: ${n.fileName ?? 'File'}',
                  ].join('\n'),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'open' && (n.fileUrl ?? '').trim().isNotEmpty) {
                      final uri = Uri.tryParse(n.fileUrl!.trim());
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                      return;
                    }
                    if (v == 'delete') {
                      await _delete(context, service, n);
                    }
                  },
                  itemBuilder: (_) => [
                    if ((n.fileUrl ?? '').trim().isNotEmpty)
                      const PopupMenuItem(value: 'open', child: Text('Open')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AssignmentDraft {
  final String title;
  final String description;
  final DateTime? dueAt;
  final String? materialFileName;
  final String? materialUrl;
  const _AssignmentDraft({
    required this.title,
    required this.description,
    required this.dueAt,
    this.materialFileName,
    this.materialUrl,
  });
}

class _CreateAssignmentDialog extends StatefulWidget {
  const _CreateAssignmentDialog();

  @override
  State<_CreateAssignmentDialog> createState() => _CreateAssignmentDialogState();
}

class _AnnouncementDraft {
  final String title;
  final String message;
  const _AnnouncementDraft({required this.title, required this.message});
}

class _CreateAnnouncementDialog extends StatefulWidget {
  const _CreateAnnouncementDialog();

  @override
  State<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState extends State<_CreateAnnouncementDialog> {
  final _title = TextEditingController();
  final _msg = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msg,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
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
            final title = _title.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title is required')),
              );
              return;
            }
            Navigator.pop(
              context,
              _AnnouncementDraft(title: title, message: _msg.text.trim()),
            );
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}

class _NoteDraft {
  final String title;
  final String content;
  final String? fileName;
  final String? fileUrl;
  const _NoteDraft({
    required this.title,
    required this.content,
    this.fileName,
    this.fileUrl,
  });
}

class _CreateNoteDialog extends StatefulWidget {
  const _CreateNoteDialog();

  @override
  State<_CreateNoteDialog> createState() => _CreateNoteDialogState();
}

class _CreateNoteDialogState extends State<_CreateNoteDialog> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _uploading = false;
  String? _fileName;
  String? _fileUrl;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fileName == null ? 'No file attached' : 'File: $_fileName',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: _uploading
                      ? null
                      : () async {
                          final email = context
                                  .read<ClassroomAuthService>()
                                  .currentUser
                                  ?.email ??
                              '';
                          if (email.trim().isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Google sign-in required.'),
                                ),
                              );
                            }
                            return;
                          }
                          final picked = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: false,
                          );
                          final path = picked?.files.single.path;
                          if (path == null || path.trim().isEmpty) return;

                          setState(() => _uploading = true);
                          final driveService = context.read<DriveUploadService>();
                          try {
                            final upload = await driveService.uploadPublicMaterial(
                              file: File(path),
                              registeredEmail: email,
                            );
                            if (!mounted) return;
                            setState(() {
                              _fileName = upload.fileName;
                              _fileUrl = upload.webViewLink;
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _uploading = false);
                          }
                        },
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file, size: 18),
                  label: const Text('Attach'),
                ),
              ],
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
            final title = _title.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title is required')),
              );
              return;
            }
            Navigator.pop(
              context,
              _NoteDraft(
                title: title,
                content: _content.text.trim(),
                fileName: _fileName,
                fileUrl: _fileUrl,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _CreateAssignmentDialogState extends State<_CreateAssignmentDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _dueAt;
  bool _uploadingMaterial = false;
  String? _materialFileName;
  String? _materialUrl;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(
      () => _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dueLabel =
        _dueAt == null ? 'No due date' : DateFormat('MMM d, hh:mm a').format(_dueAt!);
    return AlertDialog(
      title: const Text('New assignment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Due: $dueLabel')),
                TextButton.icon(
                  onPressed: _pickDue,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: const Text('Set'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _materialFileName == null
                        ? 'No material attached'
                        : 'Material: $_materialFileName',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: _uploadingMaterial
                      ? null
                      : () async {
                          final email = context
                                  .read<ClassroomAuthService>()
                                  .currentUser
                                  ?.email ??
                              '';
                          if (email.trim().isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Google sign-in required.'),
                                ),
                              );
                            }
                            return;
                          }

                          final picked = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: false,
                          );
                          final path = picked?.files.single.path;
                          if (path == null || path.trim().isEmpty) return;

                          setState(() => _uploadingMaterial = true);
                          final driveService = context.read<DriveUploadService>();
                          try {
                            final upload = await driveService.uploadPublicMaterial(
                              file: File(path),
                              registeredEmail: email,
                            );
                            if (!mounted) return;
                            setState(() {
                              _materialFileName = upload.fileName;
                              _materialUrl = upload.webViewLink;
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _uploadingMaterial = false);
                            }
                          }
                        },
                  icon: _uploadingMaterial
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file, size: 18),
                  label: const Text('Attach'),
                ),
              ],
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
            final title = _title.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title is required')),
              );
              return;
            }
            Navigator.pop(
              context,
              _AssignmentDraft(
                title: title,
                description: _desc.text.trim(),
                dueAt: _dueAt,
                materialFileName: _materialFileName,
                materialUrl: _materialUrl,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
