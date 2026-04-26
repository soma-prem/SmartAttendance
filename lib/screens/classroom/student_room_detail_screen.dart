import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/classroom_models.dart';
import '../../models/user_model.dart';
import '../../services/classroom_auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/drive_upload_service.dart';
import '../../utils/role_home_navigation.dart';

class StudentRoomDetailScreen extends StatelessWidget {
  final AppUser student;
  final ClassroomRoom room;
  const StudentRoomDetailScreen({
    super.key,
    required this.student,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8FAFC);

    return DefaultTabController(
      length: 3,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          goToStudentDashboardHome(context);
        },
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => goToStudentDashboardHome(context),
            ),
            title: Text(room.title),
            actions: [
            IconButton(
              tooltip: 'Copy class code',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: room.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied code: ${room.code}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
            bottom: const TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.assignment_outlined, size: 18),
                  text: 'Assignments',
                ),
                Tab(
                  icon: Icon(Icons.campaign_outlined, size: 18),
                  text: 'Announcements',
                ),
                Tab(
                  icon: Icon(Icons.note_alt_outlined, size: 18),
                  text: 'Notes',
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _StudentAssignmentsTab(student: student, room: room),
              _StudentAnnouncementsTab(room: room),
              _StudentNotesTab(room: room),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid link')));
    }
    return;
  }

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open link')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open link: $e')));
    }
  }
}

Future<void> _submitWork({
  required BuildContext context,
  required ClassroomService service,
  required ClassroomRoom room,
  required AppUser student,
  required ClassroomAssignment assignment,
}) async {
  try {
    final email = context.read<ClassroomAuthService>().currentUser?.email ?? '';
    if (email.trim().isEmpty) {
      throw Exception('Google sign-in required.');
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.trim().isEmpty) return;

    final shareWith = <String>[];
    final facultyEmail = (room.createdByEmail ?? '').trim();
    if (facultyEmail.isNotEmpty) shareWith.add(facultyEmail);

    final driveService = context.read<DriveUploadService>();
    final upload = await driveService.uploadToMyDrive(
      file: File(path),
      registeredEmail: email,
      shareWithEmails: shareWith,
    );

    await service.upsertSubmission(
      classroomId: room.id,
      assignmentId: assignment.id,
      studentPnr: student.pnr,
      studentName: student.name,
      fileName: upload.fileName,
      fileUrl: upload.webViewLink,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Uploaded: ${upload.fileName}'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
    );
  }
}

class _StudentAssignmentsTab extends StatelessWidget {
  final AppUser student;
  final ClassroomRoom room;
  const _StudentAssignmentsTab({required this.student, required this.room});

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
          return const _EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No assignments yet',
            message: 'New assignments will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _TabSectionHeader(
              title: 'Assignments',
              subtitle:
                  'Submit your classroom work and view attached materials.',
            ),
            const SizedBox(height: 16),
            ...items.map((a) {
              final due = a.dueAt == null
                  ? null
                  : DateFormat('MMM d, hh:mm a').format(a.dueAt!);
              final isOverdue =
                  a.dueAt != null && a.dueAt!.isBefore(DateTime.now());

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LeadingIcon(
                              icon: Icons.assignment_outlined,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _Pill(
                                    icon: Icons.schedule_outlined,
                                    color: due == null
                                        ? Colors.blueGrey
                                        : isOverdue
                                        ? Colors.red
                                        : Colors.indigo,
                                    text: due == null
                                        ? 'No due date'
                                        : 'Due $due',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (a.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            a.description.trim(),
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ],
                        if ((a.materialUrl ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _ActionLink(
                            icon: Icons.description_outlined,
                            label: a.materialFileName ?? 'View material',
                            onTap: () => _openExternalUrl(
                              context,
                              a.materialUrl!.trim(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        StreamBuilder<ClassroomSubmission?>(
                          stream: service.watchMySubmission(
                            classroomId: room.id,
                            assignmentId: a.id,
                            studentPnr: student.pnr,
                          ),
                          builder: (context, sSnap) {
                            final submitted = sSnap.data;
                            final submittedFileUrl = submitted?.fileUrl;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: submitted == null
                                      ? const Color(0xFFE2E8F0)
                                      : Colors.green.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        submitted == null
                                            ? Icons.hourglass_empty_rounded
                                            : Icons.verified_rounded,
                                        size: 18,
                                        color: submitted == null
                                            ? Colors.blueGrey
                                            : Colors.green,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          submitted == null
                                              ? 'Not submitted'
                                              : 'Handed in • ${DateFormat('MMM d, hh:mm a').format(submitted.updatedAt)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (submittedFileUrl != null &&
                                      submittedFileUrl.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _ActionLink(
                                      icon: Icons.open_in_new,
                                      label: submitted?.fileName ?? 'Open file',
                                      onTap: () => _openExternalUrl(
                                        context,
                                        submittedFileUrl,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _submit(
                                            context: context,
                                            service: service,
                                            assignment: a,
                                          ),
                                          icon: const Icon(Icons.upload_file),
                                          label: Text(
                                            submitted == null
                                                ? 'Submit'
                                                : 'Replace',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (submitted != null) ...[
                                        const SizedBox(width: 10),
                                        OutlinedButton(
                                          onPressed: () async {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            try {
                                              await service.unsubmit(
                                                classroomId: room.id,
                                                assignmentId: a.id,
                                                studentPnr: student.pnr,
                                              );
                                              if (!context.mounted) return;
                                              messenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text('Unsubmitted'),
                                                ),
                                              );
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text('$e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text('Unsubmit'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _submit({
    required BuildContext context,
    required ClassroomService service,
    required ClassroomAssignment assignment,
  }) {
    return _submitWork(
      context: context,
      service: service,
      room: room,
      student: student,
      assignment: assignment,
    );
  }
}

class _StudentAnnouncementsTab extends StatelessWidget {
  final ClassroomRoom room;
  const _StudentAnnouncementsTab({required this.room});

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
          return const _EmptyState(
            icon: Icons.campaign_outlined,
            title: 'No notices yet',
            message: 'New notices will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _TabSectionHeader(
              title: 'Notices',
              subtitle:
                  'Stay informed with the latest classroom announcements.',
            ),
            const SizedBox(height: 16),
            ...items.map((a) {
              final when = DateFormat('MMM d, hh:mm a').format(a.createdAt);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _LeadingIcon(
                              icon: Icons.campaign_outlined,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$when • ${a.createdByName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          a.message.trim(),
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _StudentNotesTab extends StatelessWidget {
  final ClassroomRoom room;
  const _StudentNotesTab({required this.room});

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
          return const _EmptyState(
            icon: Icons.note_alt_outlined,
            title: 'No notes yet',
            message: 'Notes shared by faculty will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _TabSectionHeader(
              title: 'Notes',
              subtitle: 'Review the latest study notes and shared documents.',
            ),
            const SizedBox(height: 16),
            ...items.map((n) {
              final when = DateFormat('MMM d, hh:mm a').format(n.createdAt);
              final hasFile = (n.fileUrl ?? '').trim().isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _LeadingIcon(
                              icon: Icons.note_alt_outlined,
                              color: Color(0xFF22C55E),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$when • ${n.createdByName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          n.content.trim(),
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        if (hasFile) ...[
                          const SizedBox(height: 12),
                          _ActionLink(
                            icon: Icons.attach_file,
                            label: n.fileName ?? 'Attachment',
                            onTap: () =>
                                _openExternalUrl(context, n.fileUrl!.trim()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _LeadingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _TabSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TabSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF334155)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Pill({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
