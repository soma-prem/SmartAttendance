import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/attendance_record.dart';
import '../../models/timetable_entry.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../utils/skeleton.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/student_sidebar_drawer.dart';

class StudentDisputesScreen extends StatelessWidget {
  const StudentDisputesScreen({super.key});

  String _todayLabel() => DateFormat('EEEE').format(DateTime.now());

  DateTime? _parseTimeToday(String value) {
    try {
      final parsed = DateFormat('hh:mm a').parse(value);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (_) {
      return null;
    }
  }

  ({DateTime from, DateTime to})? _disputeWindow(TimetableEntry entry) {
    final end = _parseTimeToday(entry.endTime);
    if (end == null) return null;
    return (from: end.subtract(const Duration(minutes: 5)), to: end.add(const Duration(minutes: 15)));
  }

  Future<AttendanceRecord?> _todayAttendanceForLecture(TimetableEntry entry) {
    return DatabaseService().getTodayAttendance(
      subject: entry.subject,
      className: entry.className,
      semesterNumber: entry.semesterNumber,
      branch: entry.branch,
      year: entry.year,
      facultyPnr: entry.facultyPnr,
      batchKey: (entry.batchName ?? '').trim(),
    );
  }

  Stream<List<TimetableEntry>>? _todayTimetableStream(AppUser user) {
    final className = user.effectiveClassName;
    if (className == null || className.trim().isEmpty) return null;

    final semester = user.semester;
    final branch = user.branch;
    final yearInt = int.tryParse(user.year ?? '');
    if (semester == null || branch == null || yearInt == null) return null;

    return DatabaseService().getTimetableForClass(
      className,
      semesterNumber: semester,
      year: yearInt,
      branch: branch,
    );
  }

  List<TimetableEntry> _filterToday(List<TimetableEntry> entries, AppUser user) {
    final today = _todayLabel().toLowerCase();
    final batch = user.batch?.trim();
    final filtered = entries.where((e) {
      final isToday = e.day.trim().toLowerCase() == today;
      if (!isToday) return false;
      if (e.batchName == null || e.batchName!.trim().isEmpty) {
        return true;
      }
      return batch != null && e.batchName!.trim() == batch;
    }).toList();
    filtered.sort((a, b) {
      final aTime = _parseTimeToday(a.startTime);
      final bTime = _parseTimeToday(b.startTime);
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });
    return filtered;
  }

  Future<void> _showRaiseDisputeDialog({
    required BuildContext context,
    required AppUser user,
    required TimetableEntry entry,
  }) async {
    final window = _disputeWindow(entry);
    if (window == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid lecture time.')),
      );
      return;
    }

    final now = DateTime.now();
    if (now.isBefore(window.from) || now.isAfter(window.to)) {
      final f = DateFormat('hh:mm a').format(window.from);
      final t = DateFormat('hh:mm a').format(window.to);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispute window: $f - $t')),
      );
      return;
    }

    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Raise Dispute'),
        content: TextField(
          controller: reasonController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Explain briefly (required)',
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
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reason is required.')),
        );
      }
      return;
    }

    try {
      final dateOnly = DateTime(now.year, now.month, now.day);
      await DatabaseService().raiseDisputeForLecture(
        studentPnr: user.pnr,
        subject: entry.subject,
        reason: reason,
        lectureDate: dateOnly,
        className: entry.className,
        semesterNumber: entry.semesterNumber,
        branch: entry.branch,
        year: entry.year,
        facultyPnr: entry.facultyPnr,
        batchKey: (entry.batchName ?? '').trim(),
        lectureStartTime: entry.startTime,
        lectureEndTime: entry.endTime,
        validFrom: window.from,
        validTo: window.to,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispute raised. Faculty can review it now.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final stream = _todayTimetableStream(user);
    final dateLabel = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leading: const AppMenuButton(),
        title: const Text('Disputes'),
      ),
      drawer: StudentSidebarDrawer(user: user, fallbackPnr: user.pnr),
      body: SafeArea(
        child: stream == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Your profile is missing Branch/Year/Semester/Class details.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : StreamBuilder<List<TimetableEntry>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const SkeletonListView(itemCount: 8);
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final todays = _filterToday(snapshot.data ?? const <TimetableEntry>[], user);
                  if (todays.isEmpty) {
                    return const Center(child: _EmptyDisputesState());
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: todays.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = todays[index];
                      final window = _disputeWindow(entry);

                      return FutureBuilder<AttendanceRecord?>(
                        future: _todayAttendanceForLecture(entry),
                        builder: (context, attendanceSnap) {
                          final record = attendanceSnap.data;
                          final status = record?.records[user.pnr]?.toString();
                          final hasRecord = record != null;
                          final displayStatus =
                              hasRecord ? (status ?? 'Absent') : 'Not marked yet';

                          final now = DateTime.now();
                          final isWindowOpen = window != null &&
                              !now.isBefore(window.from) &&
                              !now.isAfter(window.to);
                          final canRaise = isWindowOpen &&
                              (displayStatus == 'Absent' ||
                                  displayStatus == 'Not marked yet');

                          final statusLower = displayStatus.trim().toLowerCase();
                          final Color accent = statusLower == 'present'
                              ? Colors.green
                              : statusLower == 'absent'
                                  ? Colors.red
                                  : Colors.blueGrey;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 6,
                                      color: accent,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      14,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                entry.subject,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if (attendanceSnap
                                                        .connectionState ==
                                                    ConnectionState.waiting &&
                                                !attendanceSnap.hasData)
                                              const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            else
                                              _AttendanceDot(
                                                statusLower: statusLower,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _InfoChip(
                                              icon: Icons.school_outlined,
                                              text: entry.branch,
                                            ),
                                            _InfoChip(
                                              icon: Icons.schedule_outlined,
                                              text:
                                                  '${entry.startTime} - ${entry.endTime}',
                                            ),
                                            _InfoChip(
                                              icon:
                                                  Icons.calendar_today_outlined,
                                              text: dateLabel,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        FutureBuilder<bool>(
                                          future: () async {
                                            final dateKey =
                                                '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                                            final lectureKey =
                                                DatabaseService.buildLectureKey(
                                              dateKey: dateKey,
                                              subject: entry.subject,
                                              className: entry.className,
                                              facultyPnr: entry.facultyPnr,
                                              batchKey:
                                                  (entry.batchName ?? '').trim(),
                                              startTime: entry.startTime,
                                              endTime: entry.endTime,
                                            );
                                            final existing =
                                                await DatabaseService()
                                                    .getPendingDisputeForLecture(
                                              lectureKey: lectureKey,
                                              studentPnr: user.pnr,
                                            );
                                            return existing != null;
                                          }(),
                                          builder: (context, disputeSnap) {
                                            final alreadyRaised =
                                                (disputeSnap.data ?? false) ==
                                                    true;

                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                if (alreadyRaised)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    child: _StatusPill(
                                                      color: Colors.deepPurple,
                                                      icon: Icons
                                                          .verified_outlined,
                                                      text:
                                                          'Dispute already raised',
                                                    ),
                                                  )
                                                else
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    child: _StatusPill(
                                                      color: isWindowOpen
                                                          ? Colors.green
                                                          : Colors.blueGrey,
                                                      icon: isWindowOpen
                                                          ? Icons
                                                              .lock_open_outlined
                                                          : Icons
                                                              .lock_outline,
                                                      text: isWindowOpen
                                                          ? 'Window open'
                                                          : 'Window closed',
                                                    ),
                                                  ),
                                                SizedBox(
                                                  height: 46,
                                                  child: ElevatedButton.icon(
                                                    onPressed: (!canRaise ||
                                                            alreadyRaised)
                                                        ? null
                                                        : () =>
                                                            _showRaiseDisputeDialog(
                                                              context: context,
                                                              user: user,
                                                              entry: entry,
                                                            ),
                                                    icon: const Icon(
                                                      Icons.flag_outlined,
                                                      size: 18,
                                                    ),
                                                    label: Text(
                                                      alreadyRaised
                                                          ? 'Dispute raised'
                                                          : 'Raise dispute',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF334155)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _StatusPill({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDisputesState extends StatelessWidget {
  const _EmptyDisputesState();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: Icon(
              Icons.event_available_outlined,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No lectures for today',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Come back after your classes to raise a dispute (within the allowed time window).',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceDot extends StatelessWidget {
  final String statusLower;

  const _AttendanceDot({required this.statusLower});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String label;

    if (statusLower == 'present') {
      bg = Colors.green;
      label = 'P';
    } else if (statusLower == 'absent') {
      bg = Colors.red;
      label = 'A';
    } else {
      bg = Colors.blueGrey;
      label = 'N';
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
